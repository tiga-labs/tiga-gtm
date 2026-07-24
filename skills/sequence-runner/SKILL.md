---
name: sequence-runner
description: "Operate outbound sequences with the Tiga API — enroll and remove people, check sequence performance, and build lists of people by engagement. Use this skill whenever the user wants to add people to a sequence, enroll a list, remove people from a sequence (bounces, replies, wrong persona), check open/reply/click/bounce rates, or get the people behind the numbers: 'everyone who opened an email from any sequence I own', 'who replied last week', 'build a list of clickers', 'who hasn't responded'. Trigger phrases: 'add these people to my sequence', 'enroll this list', 'how is my sequence performing', 'open rate', 'reply rate', 'who opened my emails', 'pull everyone who clicked', 'remove the bounces from my sequence'. NOT for writing or editing step content and personalizations (use sequence-builder), NOT for building new prospect lists from ICP/Apollo/LinkedIn (use list-building), and NOT for play_type: flow agent automations (use flow-builder)."
---

# Sequence Runner Skill

Sequences have two halves: they get **authored** (**sequence-builder** — steps, email/LinkedIn content, p13ns), then **run** — that's this skill: enroll people, watch performance, and turn engagement back into lists you can act on. If the task touches step content in any way, hand it to **sequence-builder**; everything about operating an already-authored sequence belongs here.

**Before starting:** Read `references/api-reference.md` for endpoint details.

**Related skills:** **sequence-builder** to author or edit step content and p13ns; **list-building** to build new prospect lists worth enrolling; **signals** to score/prioritize before enrolling; **flow-builder** for persistent `play_type: flow` automations.

---

## Operating principles

1. **Resolve identity first.** "Me", "my sequences", "sequences I own" → `GET /api/v1/me`. It works with any key (no admin needed) and returns your user `id` plus `is_admin` / `is_play_admin` flags, so you know up front which gated endpoints will work. Resolve sequence names to IDs via `GET /api/v1/sequences` (match on `Name`; note `Owner` / `OwnerId`).

2. **Engagement queries default to the key user's sequences.** `GET /api/v1/engagement/people` scopes to sequences owned by the API key's user unless you pass `owner_id=all` (workspace-wide) or a specific user's UUID. Say which scope and date window you used when reporting results.

3. **Trust the counts.** Opens and clicks are bot-filtered server-side (scanner/proxy hits never reach the data) and deduped per email. Don't re-filter or second-guess them.

4. **Work in CSV first, materialize on request.** Page through results, write a CSV, and report totals. Only create a Tiga list when the user wants to act on it:
   - `POST /api/v1/lists` with `object_type: person`
   - `POST /api/v1/lists/:id/add-members` with `object_ids` (**not** `member_ids`)
   - Verify: `GET /api/v1/people` with `Tiga-Filter: {"list_id":"<id>"}` — `total_count` must be > 0.

5. **Report both halves.** Enrollment returns `new_people` AND `duplicates` — report both. Engagement queries return matches for a scope and window — state all three ("14 people opened, across the 3 sequences you own, since July 1").

---

## Workflow 1: Check sequence performance

**Use when:** "How is my sequence doing?", "what's the open rate?", "compare step performance".

1. Resolve the sequence ID (`GET /api/v1/sequences`, match on `Name`).
2. Pull per-step metrics:

```bash
curl -X GET "$TIGA_BASE/api/v1/sequence/<sequence-id>/metrics?startDate=2026-07-01" \
  -H "X-Tiga-Auth: $TIGA_API_KEY"
```

3. The `activity` array has one row per step: `added_to_sequence`, `email_send`, `email_open`, `email_reply`, `email_click`, `email_bounce`, `li_message_send`, `li_connection_send`, `li_connection_accepted`, `call_logged`. Compute rates yourself — open rate = `email_open / email_send`, reply rate = `email_reply / email_send` — per step and overall. `pending` shows tasks not yet run; `duration` is the sequence length in days.
4. Report rates alongside raw counts (a 50% open rate on 4 sends is noise, not signal).

## Workflow 2: Engagement → people list

**Use when:** "Who opened an email from any of my sequences?", "everyone who replied last week", "build a list of clickers".

1. Scope: whose sequences? Default is the key user's own (`GET /api/v1/me` to know who that is). All sequences in the workspace → `owner_id=all`. Someone else's → resolve their UUID (`GET /api/v1/users` if admin, else `OwnerId` from `GET /api/v1/sequences`).
2. Query — `metric` takes one or more names with OR semantics (`open`, `click`, `reply`, `bounce`, `send`, `li-reply`, `call`; `metric=open,click,reply` ≈ "any engagement"):

```bash
curl -X GET "$TIGA_BASE/api/v1/engagement/people?metric=open&startDate=2026-07-01" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Tiga-Pagination: {\"page\":1,\"page_size\":100}"
```

3. Page until `rows` is exhausted (`total_count` tells you how many to expect). Every row carries all metric counts plus `last_matched_at`, so one query answers follow-ups like "how many times did each of them open?".
4. The canonical script does steps 2–3 (and optional list materialization) in one shot: `scripts/engaged_people.sh open engaged.csv`.
5. Deliver as CSV; materialize into a Tiga list only on request (principle 4). Common chains: enroll the engaged people in a follow-up sequence (Workflow 3), or hand the list to **signals** for scoring.

Date semantics: the range is half-open (`>= startDate`, `< endDate`) and a date-only `endDate` includes that whole day. Only sequence-attached activity counts — manually logged calls outside a sequence won't appear.

## Workflow 3: Enroll people

**Use when:** "Add these people to my sequence", "enroll this list".

1. The sequence must be **active** — `POST /api/v1/sequence/:id/add-people` returns `404` when it's disabled. Check `IsEnabled` on `GET /api/v1/sequences`; activate via `POST /api/v1/sequence/:id/activate` (it 400s if steps are missing or incomplete — fix content with **sequence-builder** first).
2. Enroll by explicit IDs or by list. **Always** include `can_enrich_missing_data=true` — it makes the server *attempt* to enrich a missing email/LinkedIn URL (not guaranteed) before enrolling; without it, people missing the field a step needs get silently left with errored tasks:

```bash
curl -X POST "$TIGA_BASE/api/v1/sequence/<sequence-id>/add-people?can_enrich_missing_data=true" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"list_id": "<list-id>", "select_all": true}'
```

   Or `{"people_ids": ["<uuid>", ...]}` for explicit people.
3. The response has both halves: `new_people` (enrolled) and `duplicates` (already in the sequence, skipped). Report both counts.

## Workflow 4: Remove people

**Use when:** "Remove the bounces", "pull the repliers out of the sequence", "remove these people".

1. For engagement-based removal, chain Workflow 2 first: `metric=bounce` (or `reply`) scoped with `sequence_id=<id>` gives you the `person_id`s.
2. Remove:

```bash
curl -X POST "$TIGA_BASE/api/v1/sequence/<sequence-id>/remove-people" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"people_ids": ["<uuid>", "<uuid>"]}'
```

   Alternatively select by task status: `{"select_all": true, "task_status": "<status>"}`.
3. Returns bare `200`. Confirm by re-checking the sequence's `ActivePeople` on `GET /api/v1/sequences`, and report how many were removed and why.

Note: most sequences are configured to auto-remove people when they reply or bounce, so an engagement query may return fewer people still in the sequence than expected — that's the auto-removal already having done the work, not a bug.
