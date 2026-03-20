---
name: contact-discovery
description: Find and enrich contacts using the Tiga API. Use this skill when the user wants to find people at target accounts by role or title, enrich contacts with email and phone via waterfall enrichment, pull contacts from LinkedIn Sales Navigator queries, or set up automated contact discovery. Covers TAL-to-contacts, Sales Nav queries, and recurring pull workflows.
---

# Contact Discovery Skill

Find specific roles at target accounts and enrich contacts with verified email and phone data.

**Before starting:** Read `tiga-gtm/docs/api-reference.md` for endpoint details. Read `tiga-gtm/docs/async-patterns.md` for the polling pattern used by Find People Agent and Waterfall Enrich APIs.

**Base URL:** `https://app.tigalabs.com`
**Auth:** `X-Tiga-Auth: $TIGA_API_KEY`

---

## Workflow A: TAL → Role Targeting → Enrichment

**Use when:** You have a target account list and need to find specific roles/titles and get verified contact info.

### Steps

1. **Find people at target accounts** using Find People Agent:
```bash
curl -X POST "https://app.tigalabs.com/api/v1/agent/find-people" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "contact_description": "VP of Engineering or Director of Engineering at Series B SaaS companies with 50-200 employees",
    "model": "gpt-5.4-2026-03-05"
  }'
```
   This is async — capture `status_id` from the response.

2. **Poll for results:**
```bash
curl -X GET "https://app.tigalabs.com/api/agent/find-people/<status-id>/status" \
  -H "X-Tiga-Auth: $TIGA_API_KEY"
```
   Wait until `status` = `"Complete"` or starts with `"Error"`. Poll every 5-10 seconds, timeout at 420 seconds.

3. **Batch waterfall enrichment** — For each person returned, submit enrichment:
```bash
curl -X POST "https://app.tigalabs.com/api/v1/people/enrich-person" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "first_name": "<first_name>",
    "last_name": "<last_name>",
    "company_name": "<account_name>",
    "domain": "<domain>",
    "person_linkedin_url": "<person_linkedin>",
    "title": "<title>"
  }'
```
   Submit all enrichment jobs first, collecting all `enrich_id` values.

4. **Poll all enrichments in parallel:**
```bash
curl -X GET "https://app.tigalabs.com/api/v1/enrich/<enrich-id>" \
  -H "X-Tiga-Auth: $TIGA_API_KEY"
```
   Wait until `data_import_status` is not `"Running"`. Poll every 5-10 seconds.

5. **Result** — Enriched people with verified email + phone, created in Tiga and linked to their accounts. Use `person_id` from enrichment response for downstream workflows (adding to lists, sequences).

---

## Workflow B: Sales Nav Query → Enriched Contacts

**Use when:** You have a LinkedIn Sales Navigator-style query (descriptive search criteria) and want enriched contacts.

### Steps

1. **Submit Find People Agent with a descriptive query:**
```bash
curl -X POST "https://app.tigalabs.com/api/v1/agent/find-people" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "contact_description": "Head of Data Engineering at enterprise healthcare companies in the Northeast US, 500+ employees",
    "model": "gpt-5.4-2026-03-05"
  }'
```

2. **Poll for results** (same as Workflow A, step 2).

3. **Enrich all found contacts** (same as Workflow A, steps 3-4).

4. **Create a people list** and add enriched contacts:
```bash
curl -X POST "https://app.tigalabs.com/api/v1/lists" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"list": {"name": "Sales Nav Pull - <description> - 2026-03-20", "object_type": "person"}}'
```
   Then `POST /api/v1/lists/:id/add-members` with the `person_id` values from enrichment.

---

## Workflow C: Automated Sales Nav Pull

**Use when:** You want recurring contact discovery — e.g., continuously finding new contacts matching a saved search criteria, enriching them, and adding to a list or sequence.

### Steps

1. **Submit Find People Agent** with the recurring search criteria (Workflow B, step 1).

2. **Poll for results** and **enrich** all found contacts (Workflow A, steps 2-4).

3. **Add enriched contacts to an existing list:**
```bash
curl -X POST "https://app.tigalabs.com/api/v1/lists/<list-id>/add-members" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"object_ids": ["<person-id-1>", "<person-id-2>"]}'
```

4. **Optionally add to a sequence** (if outreach is automated):
```bash
curl -X POST "https://app.tigalabs.com/api/v1/sequence/<sequence-id>/add-people" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"people_ids": ["<person-id-1>", "<person-id-2>"]}'
```

5. **Repeat** at the desired cadence — run this workflow periodically (e.g., weekly) to continuously discover new contacts.

### Notes
- Each Find People Agent run may return different results as LinkedIn data updates
- Track previously enriched contacts to avoid duplicate enrichment (check existing people via `GET /api/v1/people` with search)
- Valid models for Find People: `gpt-5.4-2026-03-05`, `gpt-5.2-2025-12-11`, `gpt-5.1-2025-11-13`
