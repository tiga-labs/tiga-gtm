---
name: crm-ops
description: CRM hygiene and sync operations using the Tiga API. Use this skill when the user wants to detect people who changed jobs, fill missing roles or title gaps in CRM accounts, update stale or outdated contacts, clean field formatting, or sync data between Tiga and HubSpot/Salesforce. Covers people-on-the-move, role gap filling, stale contact updates, and field cleanup.
---

# CRM Ops Skill

Maintain CRM data quality using Tiga signals, enrichment, and CRM integrations.

**Before starting:** Read `tiga-gtm/docs/api-reference.md` for endpoint details. Read `tiga-gtm/docs/merge-fields.md` for signal prompt variables. Read `tiga-gtm/docs/async-patterns.md` for polling patterns.

**Base URL:** `https://app.tigalabs.com`
**Auth:** `X-Tiga-Auth: $TIGA_API_KEY`

---

## Workflow A: People on the Move

**Use when:** You want to detect contacts who have changed jobs — either departed their role or started a new one — and update CRM accordingly.

### Steps

1. **Create movement detection signals:**

   **Role Departure signal:**
   ```json
   POST /api/v1/signal
   {
     "label": "Role Departure Detection",
     "is_computed_column": true,
     "type": "text",
     "computed_config": {
       "type": "role_departure",
       "is_account_insight": false
     }
   }
   ```

   **Started New Role signal:**
   ```json
   POST /api/v1/signal
   {
     "label": "Started New Role",
     "is_computed_column": true,
     "type": "text",
     "computed_config": {
       "type": "started_new_role",
       "is_account_insight": false
     }
   }
   ```

2. **Run signals on your CRM contact list:**
```bash
curl -X POST "https://app.tigalabs.com/api/v1/lists/<list-id>/run-all-signal" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"signal_ids": ["<departure-signal-id>", "<new-role-signal-id>"]}'
```

3. **Poll for completion** via `POST /api/v1/lists-signal/bulk-status`.

4. **Read results** — For each person, check signal values via `GET /api/v1/person/:id/signals`.

5. **Update CRM** — For contacts who moved:
   - Get CRM OAuth token: `GET /api/v1/current-org/hubspot-oauth-token` or `GET /api/v1/current-org/salesforce-oauth-token`
   - Use the returned `access_token` to update/create records in the CRM via its API
   - If the person moved to a new company: create new account if needed, create new contact record, reassign ownership

---

## Workflow B: Fill Role/Title Gaps

**Use when:** You have CRM accounts that are missing contacts in key roles (e.g., no VP of Engineering on file).

### Steps

1. **Identify accounts with gaps** — Query people by account, check for missing target roles.

2. **Find missing contacts** using Find People Agent:
```bash
curl -X POST "https://app.tigalabs.com/api/v1/agent/find-people" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "contact_description": "<missing role> at <company name>",
    "model": "gpt-5.4-2026-03-05"
  }'
```

3. **Poll for results** — `GET /api/agent/find-people/:id/status` until complete.

4. **Enrich found contacts:**
```bash
curl -X POST "https://app.tigalabs.com/api/v1/people/enrich-person" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "first_name": "<first>",
    "last_name": "<last>",
    "company_name": "<company>",
    "person_linkedin_url": "<linkedin>",
    "title": "<title>"
  }'
```

5. **Push to CRM** — Get OAuth token and create contact records via CRM API.

---

## Workflow C: Update Stale Contacts

**Use when:** You want to verify that contacts in your CRM still hold their listed roles and re-enrich outdated records.

### Steps

1. **Create a verification signal:**
```json
POST /api/v1/signal
{
  "label": "Current Employment Check",
  "is_computed_column": true,
  "type": "text",
  "computed_config": {
    "type": "gpt",
    "prompt": "Is {{.FirstName}} {{.LastName}} still {{.Title}} at {{.AccountName}}? Check their LinkedIn ({{.LinkedInUrl}}) and recent web mentions. Answer: Current, Changed Role, Left Company, or Unknown.",
    "is_account_insight": false,
    "can_use_web_search": true,
    "word_limit": 40
  }
}
```

2. **Run signal on your contact list** and poll to completion.

3. **Filter results:**
   - "Current" → No action needed
   - "Changed Role" → Update title in Tiga and CRM
   - "Left Company" → Re-enrich to find current company, update CRM
   - "Unknown" → Flag for manual review

4. **Re-enrich** contacts who left — Submit waterfall enrichment with updated company info.

5. **Update CRM** via OAuth tokens.

---

## Workflow D: Clean Field Formatting

**Use when:** You want to standardize fields across your CRM data (e.g., normalize titles, fix company name formatting, standardize phone formats).

### Steps

1. **Create a formatting signal:**
```json
POST /api/v1/signal
{
  "label": "Title Standardization",
  "is_computed_column": true,
  "type": "text",
  "computed_config": {
    "type": "gpt",
    "prompt": "Standardize this job title to a canonical form: '{{.Title}}'. Rules: expand abbreviations (VP→Vice President), remove special characters, capitalize properly. Return only the standardized title.",
    "is_account_insight": false,
    "can_use_web_search": false,
    "word_limit": 20,
    "temperature": 0.1
  }
}
```

2. **Run signal on the list** and poll to completion.

3. **Read standardized values** from signal outputs.

4. **Update records in Tiga:**
```bash
curl -X PUT "https://app.tigalabs.com/api/v1/person/<person-id>" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"title": "<standardized-title>"}'
```

5. **Sync to CRM** via OAuth tokens if needed.
