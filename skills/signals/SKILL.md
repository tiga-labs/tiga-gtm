---
name: signals
description: "Create, run, and score AI signals with the Tiga API — at any scale. Use this skill whenever the user wants to define or manage a signal (create, list, update, delete) OR run signals to research, filter, or score accounts and people: buying signals, recent funding, hiring patterns, tech stack, job changes, account scoring. Triggers on phrases like 'create a signal', 'run this signal on Jane', 'score all of my accounts', 'which of these companies raised funding?', 'prioritize my pipeline', or 'what signals do I have?'. NOT for building persistent automations that route leads based on signal results (use flow-builder) and NOT for AI text that goes inside an outreach email (use sequence-builder personalizations)."
---

# Signals Skill

Define AI signals and run them on people or accounts — one record or thousands.

**Auth:** `X-Tiga-Auth: $TIGA_API_KEY` on every request (base URL and shared docs: see the **tiga-gtm** router skill).

## Decision matrix

| Task | Section |
|---|---|
| Create / list / update / delete a signal definition | **Manage signal definitions** below + `references/signal-api.md` |
| Run a signal on ≤250 records (or one record) | **Run synchronously** below — one call per record, no polling |
| Run signals on >250 records | **Run in bulk** below — list + `run-all-signal` + polling |
| Scoring models (stacked signals, multi-dimensional tiers) | `references/running-signals.md` |

---

## Manage signal definitions

**Before building or updating a `computed_config`:** read `tiga-gtm/skills/signals/references/signal-types.md` for the type index, then the specific type file:

| `computed_config.type` | Reference |
|------------------------|-----------|
| `gpt` | `tiga-gtm/skills/signals/references/type-gpt.md` |
| `hiring_for_role` | `tiga-gtm/skills/signals/references/type-hiring-for-role.md` |
| `linkedin_posts` | `tiga-gtm/skills/signals/references/type-linkedin-posts.md` |
| `hired_executive` | `tiga-gtm/skills/signals/references/type-hired-executive.md` |
| `sec_document` | `tiga-gtm/skills/signals/references/type-sec-document.md` |
| `role_departure` | `tiga-gtm/skills/signals/references/type-role-departure.md` |
| `started_new_role` | `tiga-gtm/skills/signals/references/type-started-new-role.md` |
| `search` | `tiga-gtm/skills/signals/references/type-search.md` |
| `technographics` | `tiga-gtm/skills/signals/references/type-technographics.md` |

**Create** (minimal example — full request/response shapes, list/get/update/delete details and quirks in `references/signal-api.md`):

```bash
curl -X POST "https://app.tigalabs.com/api/v1/signal" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "Recent Funding News",
    "is_computed_column": true,
    "type": "text",
    "computed_config": {
      "type": "gpt",
      "prompt": "Has {{.AccountName}} raised funding in the last 90 days? Answer yes or no with a brief reason.",
      "is_account_insight": true,
      "can_use_web_search": true,
      "expiration_in_days": 90,
      "temperature": 0.4,
      "word_limit": 50
    }
  }'
```

Save the returned `id` — required for running, updating, and deleting. After a successful create, show the user:

**See signal here: https://app.tigalabs.com/app#/signal/:id/configure**

Key rules (detail in `references/signal-api.md`):
- **Update:** always `GET /api/v1/signal/:id` first and send the **full** updated `computed_config` — partial patches are not supported. Writable fields: `label`, `computed_config`, `can_trigger_play`, `is_user_signal` (Signal Admin role required for `is_user_signal`).
- **Delete:** `DELETE /api/v1/signal/:id` → `204 No Content`. Deleting removes the signal from all lists it was attached to — confirm with the user first.

---

## Run synchronously (≤250 records)

Call once per record — blocks until the signal finishes, no list infrastructure or polling. Full request/response JSON in `references/running-signals.md`.

```bash
# Person: at least one of email / linkedin
curl -X POST "https://app.tigalabs.com/api/v1/signal/<signal-id>/run-signal" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" -H "Content-Type: application/json" \
  -d '{"person": {"email": "jane@acme.com", "linkedin": "https://www.linkedin.com/in/jane-doe"}}'

# Account: at least one of domain / linkedin (domains auto-normalized: scheme, path, port stripped)
curl -X POST "https://app.tigalabs.com/api/v1/signal/<signal-id>/run-signal" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" -H "Content-Type: application/json" \
  -d '{"account": {"domain": "acme.com"}}'
```

The result lives at `person.custom_columns[<signal-id>]` (or `account.custom_columns[<signal-id>]`). Read `status` before using `value`:

| Status | Constant | Meaning |
|--------|----------|---------|
| `1` | `SUCCESS` | Signal ran and returned a result — read `value` |
| `2` | `NOT_FOUND` | Signal ran but no matching data was found |
| `3` | `MISSING_DEPENDENCIES` | Required inputs (email, LinkedIn, etc.) were absent |
| `4` | `FAILED` | Signal execution errored |
| `5` | `PRECONDITION_FAILED` | A precondition check blocked execution |

Behavior notes:
- **Find-or-create:** if no matching person/account exists in your org, one is created automatically before the signal runs.
- **Always reruns:** results are never served from cache — every call executes fresh.
- **Signal type determines the input:** the signal's `is_account_insight` flag (fixed at creation time) controls whether you supply `person` or `account` — you cannot override this per call.
- **Always save the returned Tiga person/account ID** — useful for future tools and actions.

---

## Run in bulk (>250 records)

1. **Get or create a list:** `GET /api/v1/lists?object_type=account` / `POST /api/v1/lists` with `{"list": {"name": "<name>", "object_type": "account"}}`. To attach signals at creation time, include `"list_signals": {"<signal-id>": true, ...}` in `list` and a top-level `"run_signals_config": {"signal_ids": [...]}`.
2. **Run on the list:**
```bash
curl -X POST "https://app.tigalabs.com/api/v1/lists/<list-id>/run-all-signal" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" -H "Content-Type: application/json" \
  -d '{"signal_ids": ["<signal-id>"]}'
```
3. **Poll for completion** with `POST /api/v1/lists-signal/bulk-status` — body takes `signal_ids`, `list_id`, and `account_ids` (or `people_ids` for person lists — not both). Wait until all statuses are non-zero (1=done, 2=failed, 3=N/A). Poll every 5-10 seconds. See `tiga-gtm/docs/async-patterns.md`.
4. **Read results:** `GET /api/v1/account/:id` or `GET /api/v1/person/:id/signals`. Keep records matching your criteria (e.g., value starts with "yes").
5. **Create a filtered sub-list** of qualifiers via `POST /api/v1/lists` + `POST /api/v1/lists/:id/add-members`.

---

## Scoring patterns

- **Stacked signals:** create 2-5 signals indicating buying intent, attach all to one list, run, assign 1 point per "yes", prioritize accounts scoring ≥ N.
- **Multi-dimensional scoring:** signals across ICP fit / buying intent / timing / engagement / competitive dimensions, then tier accounts (Tier 1 = immediate outreach, Tier 2 = nurture, Tier 3 = monitor).

Full step-by-step workflows and example prompts: `references/running-signals.md`.

## Discover merge fields

Available `{{.FieldName}}` variables for `gpt` signal prompts (see `tiga-gtm/docs/merge-fields.md`):

```bash
GET /api/v1/account/columns?mode=merge_fields
GET /api/v1/person/columns?mode=merge_fields
```

---

**Related skills:** **list-building** to build the account list and find people at top accounts; **outreach** to enroll them in sequences; **flow-builder** to build persistent automations that route leads based on signal results.
