---
name: tiga-gtm
description: "Execute GTM (Go-To-Market) workflows using the Tiga sales intelligence API (app.tigalabs.com). Use this skill whenever the user mentions Tiga, target account lists, TALs, ICPs, contact enrichment, waterfall enrichment, buying signals, AI signals, sequence enrollment, CRM hygiene, lead routing, outreach personalization, Apollo search, or any sales/revenue operations task involving account or contact data. Even if the user just says 'find me some leads' or 'clean up my CRM' or 'who should I reach out to' — this skill applies."
---

# Tiga GTM Skill

Route GTM tasks to the right sub-skill. Read this file first to decide which skill to use, then invoke that skill for detailed workflow instructions.

**Base URL:** `https://app.tigalabs.com`
**Auth:** `X-Tiga-Auth: $TIGA_API_KEY` (store key in env var `TIGA_API_KEY`)

**Shared reference docs** (read these as needed, not upfront):
- `tiga-gtm/docs/api-reference.md` — Full API endpoint reference (accounts, people, lists, signals, p13ns, sequence steps, sequences, enrichment, OAuth tokens)
- `tiga-gtm/docs/async-patterns.md` — Polling pattern for async APIs (enrich, find-people, signal computation)
- `tiga-gtm/docs/merge-fields.md` — Template variables for signal prompts (`{{.AccountName}}`, `{{.Title}}`, etc.)

---

## Sub-Skill Index

### prospecting
**When to use:** User wants to build a target account list (TAL) from an ICP, natural language description, seed accounts, conference attendee list, or scraped web data. Anything about finding *companies* to target.

Key workflows: ICP-to-TAL via Apollo search, prompt-to-TAL, seed-to-lookalikes, conference list import, scraped page import.

### contact-discovery
**When to use:** User wants to find *people* at target accounts or enrich contacts with email/phone. Anything about finding contacts by role/title, waterfall enrichment, or Sales Navigator-style searches.

Key workflows: TAL-to-contacts via Find People Agent, Sales Nav query-to-enriched contacts, automated recurring contact pulls.

### signals
**When to use:** User wants to research, filter, or score accounts/people using AI-powered signals. Anything about buying signals, account scoring, funding detection, hiring signals, tech stack analysis, or multi-signal scoring models.

Key workflows: Single signal on a list, stacked signals for scoring, multi-dimensional account scoring.

### signal-crud
**When to use:** User wants to manage signal definitions — create a new signal, list or view existing signals, update a signal's configuration (prompt, type, settings), or delete a signal. Use this before `signals` when the signal doesn't exist yet.

Key workflows: Create signal by type, update computed_config, list/inspect signals, delete signal.

### crm-ops
**When to use:** User wants to maintain CRM data quality — detect job changes, fill role gaps, verify stale contacts, or standardize field formatting. Anything about CRM hygiene that uses Tiga signals + CRM sync.

Key workflows: People-on-the-move detection, role/title gap filling, stale contact verification, field cleanup.

### lead-routing
**When to use:** User wants to filter, qualify, or route leads. Anything about ICP filtering, blacklist checks, territory-based routing, website visitor triggers (RB2B), or CEO connection workflows.

Key workflows: ICP + blacklist filtering, signal-based CRM routing, signal-based list routing, website visitor qualification, CEO-to-CEO intro.

### p13n-crud
**When to use:** User wants to create, update, or preview AI personalizations (p13ns) for sequence steps. Use when the user wants personalized content in their outreach — a custom opening line, a reference to LinkedIn activity, funding news, or any AI-generated text that's unique per person. Also use when the user says "personalize my email" or "write a custom intro for each person" without explicitly mentioning p13ns.

Key workflows: Create p13n (with prompt + step_id), get the `key` for use as a merge field, preview on a real person, update or delete p13ns.

### sequence-step
**When to use:** User wants to add a new step to a sequence or update a step's email/LinkedIn message content. Use when building personalized outreach from scratch (create step → create p13n → wire up merge field) or when modifying existing step templates.

Key workflows: Add step to sequence, create p13n for step, insert `{{.key}}` into email body, update step content, full activate/deactivate workflow.

### outreach
**When to use:** User wants to enroll contacts in an existing active sequence or check sequence performance metrics. For building new personalized sequence steps from scratch, use `sequence-step` + `p13n-crud` instead.

Key workflows: Add people to sequence, monitor open/reply/click rates.

### hubspot
**When to use:** User wants to sync a Tiga person to HubSpot — creating or updating a HubSpot contact, pushing field values, or associating a contact with a HubSpot company — all via the Tiga API without calling HubSpot directly.

Key workflows: Sync single person to HubSpot, sync with account/company association, custom field mappings.

### crm-bulk-ops
**When to use:** User wants to **build a standalone tool** (Go web app) for batch CRM operations — cleaning names, enriching contacts, adding signal columns, or syncing CRM data. This is for building reusable tools with a web UI, not for one-off API calls (use the other skills for those).

Key workflows: Scaffold a Go web app with worker pool, CSV logging, stop/resume, dark-themed UI, Salesforce/HubSpot batch APIs.

### flow-builder
**When to use:** User wants to programmatically construct a Tiga `play_type: flow` sequence (an agent-style automation, not a plain outreach cadence). Anything about building or configuring multi-step flows that import from HubSpot, run Waterfall Enrich, do LinkedIn research, gate on ICP/signals, or hand off to another sequence.

Key workflows: Webinar inbound flow, agent flow construction via curl, per-step config (SyncFromHubspotFeeder, WaterfallEnrich, LinkedInResearch, AccountIcpFilter, RunSignal, AddToSequence).


---

## Choosing Between Skills

| User says... | Use this skill |
|---|---|
| "Build me a TAL" / "Find companies matching..." | prospecting |
| "Find the VP of Eng at these accounts" / "Enrich these contacts" | contact-discovery |
| "Which accounts recently raised funding?" / "Score my accounts" | signals |
| "Create a signal" / "Update this signal" / "What signals do I have?" | signal-crud |
| "Who changed jobs?" / "Clean up titles in CRM" | crm-ops |
| "Route these leads to the right rep" / "Filter inbound leads" | lead-routing |
| "Personalize emails for this list" / "Write a custom opening for each person" | p13n-crud |
| "Add a step to my sequence" / "Build a personalized email step" | sequence-step |
| "Add them to a sequence" / "How is my sequence performing?" | outreach |
| "Sync this person to HubSpot" / "Create a HubSpot contact for..." | hubspot |
| "Build me an agent flow" / "Create a webinar inbound flow with HubSpot import + enrich" | flow-builder |
| "Build a tool to clean Salesforce names" / "I need a web app for bulk CRM updates" | crm-bulk-ops |

**Composing skills:** Many GTM workflows chain multiple skills together. For example: prospecting (build TAL) → contact-discovery (find people) → signals (score) → outreach (personalize + enroll). Follow the natural pipeline order and invoke each skill as you reach that stage.
