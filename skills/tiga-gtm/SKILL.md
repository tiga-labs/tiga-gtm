---
name: tiga-gtm
description: "Execute GTM (Go-To-Market) workflows using the Tiga sales intelligence API (app.tigalabs.com). Use this skill whenever the user mentions Tiga, target account lists, TALs, ICPs, contact enrichment, waterfall enrichment, buying signals, AI signals, sequence enrollment, lead routing, outreach personalization, Apollo search, agent flows, or any sales/revenue operations task involving account or contact data. Even if the user just says 'find me some leads' or  'who should I reach out to' — this skill applies. Also trigger on simple CRM lookups: 'is Mike Ball in Tiga?', 'do we already have this person?', 'is Acme in our accounts?', 'look up John Doe in the CRM'. This is the router: it picks the right tiga-gtm sub-skill for the task."
---

# Tiga GTM Router

Route GTM tasks to the right sub-skill. Read this file to decide which skill to use, then **invoke that skill via the Skill tool** (`tiga-gtm:<skill-name>`) for detailed workflow instructions.

## API basics

- **Base URL:** `https://app.tigalabs.com` is production — but the base URL is environment-specific. Users may run against their own host (e.g. `http://localhost:3000` in dev, or a custom domain); honor whatever the user gives you. Scripts read it from `TIGA_BASE`.
- **Auth:** `X-Tiga-Auth: $TIGA_API_KEY` header on every request. The key lives in the user's environment / `.env` — never hardcode it.

**Shared reference docs** (read as needed, not upfront):
- `tiga-gtm/docs/api-reference.md` — Full API endpoint reference (accounts, people, lists, signals, p13ns, sequence steps, sequences, enrichment, OAuth tokens)
- `tiga-gtm/docs/async-patterns.md` — Polling patterns for async APIs (enrich, find-people, signal computation, no-status-endpoint imports)
- `tiga-gtm/docs/merge-fields.md` — Template variables for prompts and step content (`{{.AccountName}}`, `{{.Title}}`, etc.)

## Quick lookups (handle here — no sub-skill)

"Is Mike Ball in Tiga?", "Do we have anyone at Acme?" — existence checks against data already in Tiga. Don't invoke a sub-skill. Read `tiga-gtm/docs/api-reference.md` (Authentication & Headers → Filter header, and the People API / Accounts API sections) for filter usage, then query with the `Tiga-Filter` header's `search_term`:

```bash
curl -s "$TIGA_BASE/api/v1/people" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H 'Tiga-Filter: {"search_term": "Mike Ball"}'
```

Same header on `GET /api/v1/accounts` for companies. Response is `{"rows": [...], "total_count": N}`; `total_count: 0` → not in Tiga. If the lookup turns into a follow-on task (enrich, sequence, job-change check), route to the matching category below.

## The five categories

| Category | Skill | Use for | User says... |
|---|---|---|---|
| **List Building** | `list-building` | Build account + people lists: TALs, ICP, lookalikes, people by role/title, waterfall enrichment, enrich a local file, import linkedin post reactors, find contact information for partial lists | "Build me a TAL", "Find the VP of Eng at these accounts", "Enrich these leads", "Who liked this post?" |
| **Signals** | `signals` | Define AND run AI signals at any scale: create/update/delete signal definitions, score or research accounts/people, funding/hiring/tech-stack detection | "Create a signal", "Score my accounts", "Which raised funding?", "Run this signal on Jane" |
| **Sequences** | `sequence-builder` | Author sequence *content*: add/update steps, email and LinkedIn bodies, AI personalizations (p13ns), call/task steps | "Add a step to my sequence", "Personalize emails for this list", "Write a custom opening" |
| **Sequence Runner** | `sequence-runner` | Operate sequences: enroll/remove people, check performance, and get people behind opens/replies/clicks/bounces | "Enroll this list", "How is my sequence doing?", "Who opened my emails?", "Remove the bounces" |
| **Flows** | `flow-builder` | Build `play_type: flow` agent automations: HubSpot import → enrich → research → ICP gate → sequence handoff; lead qualification and routing | "Build me an agent flow", "Create a webinar inbound flow", "Route these leads to the right rep" |

## Disambiguation

- **Existence checks:** "is X in Tiga / our CRM?" → handle inline via Quick lookups above; no sub-skill.
- **Companies and people:** both account-list and people-list builds → `list-building` (it works accounts-first-then-people internally).
- **Signal vs. p13n:** a persistent fact for filtering/scoring/routing → `signals`; AI text that appears inside an email or LinkedIn message → `sequence-builder` (p13n).
- **Author vs. operate sequences:** writing/editing step content → `sequence-builder`; enrolling people or checking metrics → `sequence-runner`.
- **Routing and qualification:** filtering inbound leads against ICP, excluding customers, or routing to reps → `flow-builder`; a one-off run-a-signal-and-read-results pass → `signals`.

## Composing skills

Many GTM workflows chain multiple skills. For example: `list-building` (build the account list, then find the people) → `signals` (score) → `sequence-builder` (author personalized steps) → `sequence-runner` (enroll + monitor). Follow the natural pipeline order and invoke each skill as you reach that stage.
