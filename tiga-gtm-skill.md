---
name: tiga-gtm
description: "Execute GTM (Go-To-Market) workflows using the Tiga sales intelligence API (app.tigalabs.com). Use this skill whenever the user mentions Tiga, target account lists, TALs, ICPs, contact enrichment, waterfall enrichment, buying signals, AI signals, sequence enrollment, CRM hygiene, lead routing, outreach personalization, Apollo search, or any sales/revenue operations task involving account or contact data. Even if the user just says 'find me some leads' or 'clean up my CRM' or 'who should I reach out to' — this skill applies."
---

# Tiga GTM Skill

Route GTM tasks to the right sub-skill. Read this file first to decide which skill to use, then invoke that skill for detailed workflow instructions.

**Base URL:** `https://app.tigalabs.com`
**Auth:** `X-Tiga-Auth: $TIGA_API_KEY` (store key in env var `TIGA_API_KEY`)

**Shared reference docs** (read these as needed, not upfront):
- `tiga-gtm/docs/api-reference.md` — Full API endpoint reference (accounts, people, lists, signals, sequences, enrichment, OAuth tokens)
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

### crm-ops
**When to use:** User wants to maintain CRM data quality — detect job changes, fill role gaps, verify stale contacts, or standardize field formatting. Anything about CRM hygiene that uses Tiga signals + CRM sync.

Key workflows: People-on-the-move detection, role/title gap filling, stale contact verification, field cleanup.

### lead-routing
**When to use:** User wants to filter, qualify, or route leads. Anything about ICP filtering, blacklist checks, territory-based routing, website visitor triggers (RB2B), or CEO connection workflows.

Key workflows: ICP + blacklist filtering, signal-based CRM routing, signal-based list routing, website visitor qualification, CEO-to-CEO intro.

### outreach
**When to use:** User wants to personalize messaging, enroll contacts in sequences, or check sequence performance. Anything about email sequences, outreach cadences, or campaign metrics.

Key workflows: AI-personalized outreach, sequence enrollment, sequence performance monitoring.

### crm-bulk-ops
**When to use:** User wants to **build a standalone tool** (Go web app) for batch CRM operations — cleaning names, enriching contacts, adding signal columns, or syncing CRM data. This is for building reusable tools with a web UI, not for one-off API calls (use the other skills for those).

Key workflows: Scaffold a Go web app with worker pool, CSV logging, stop/resume, dark-themed UI, Salesforce/HubSpot batch APIs.

---

## Choosing Between Skills

| User says... | Use this skill |
|---|---|
| "Build me a TAL" / "Find companies matching..." | prospecting |
| "Find the VP of Eng at these accounts" / "Enrich these contacts" | contact-discovery |
| "Which accounts recently raised funding?" / "Score my accounts" | signals |
| "Who changed jobs?" / "Clean up titles in CRM" | crm-ops |
| "Route these leads to the right rep" / "Filter inbound leads" | lead-routing |
| "Personalize emails for this list" / "Add them to a sequence" | outreach |
| "Build a tool to clean Salesforce names" / "I need a web app for bulk CRM updates" | crm-bulk-ops |

**Composing skills:** Many GTM workflows chain multiple skills together. For example: prospecting (build TAL) → contact-discovery (find people) → signals (score) → outreach (personalize + enroll). Follow the natural pipeline order and invoke each skill as you reach that stage.
