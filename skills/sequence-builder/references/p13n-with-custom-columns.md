# Write Personalization With Custom Column

Personalize a sequence step using a value imported per-person from a CSV — the simplest way to add personalization in Tiga (no AI generation).

**Flow:** create step(s) with the merge field already in place → build a CSV with a matching column → import the CSV (creates the custom column) → hand off to the **sequence-runner** skill to enroll people (out of scope here).

## Example Walkthrough

CSV `people_list.csv` — column names must exactly match the field names used below (Tiga does not rename headers on import):
```
first_name,last_name,email,domain,agent_merge_intro_sentence_a1b2c3
```

### 1. Create step(s) with the merge field

Prefix personalized merge fields with `agent_merge_` and add a short unique suffix so the name can't collide with another step's, e.g. `agent_merge_intro_sentence_a1b2c3` (same pattern p13n keys use). Prefer Tiga's built-in fields (`{{.FirstName}}`, etc.) where they already cover the need.

Write it as plain `{{.field}}` text directly in the HTML — it resolves and substitutes correctly on its own. You do **not** need to wrap it in a `<span class="tiga-merge">` chip; that span is only cosmetic (it makes the field render as an interactive chip in the step editor UI elsewhere in Tiga) and has no effect on whether the merge actually works.

```html
<p>Hi {{.FirstName}}</p>
<p>{{.agent_merge_intro_sentence_a1b2c3}}</p>
<p>Let me know if you're interested!</p>
```

Deactivate the sequence (`POST /api/v1/sequence/<sequence-id>/deactivate`), then save the step:

```bash
curl -X POST "https://app.tigalabs.com/api/v1/sequence/<sequence-id>/add-step?stepToAppendToId=<last-step-id>" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "SequenceEmail",
    "step_name": "Initial Outreach",
    "email_subject": "Quick question about {{.AccountName}}",
    "email_body": "<p>Hi {{.FirstName}}</p><p>{{.agent_merge_intro_sentence_a1b2c3}}</p><p>Let me know if you'\''re interested!</p>"
  }'
```
`400` means the merge field name conflicts with an existing one — pick a different suffix and retry.

Reactivate when done (`POST /api/v1/sequence/<sequence-id>/activate`).

### 2. Add the personalization value per person

Add a column to the CSV named exactly `agent_merge_intro_sentence_a1b2c3` (must match step 1's merge field). Each row holds that person's personalization — a sentence, phrase, or single word.

### 3. Import people (this creates the custom column)

```bash
curl -X POST "https://app.tigalabs.com/api/v1/import/upload" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "records": [
      {
        "email": "jane@acme.com",
        "first_name": "Jane",
        "website": "acme.com",
        "custom_columns": { "agent_merge_intro_sentence_a1b2c3": "<personalization>" }
      }
    ]
  }'
```
Call `POST /api/v1/import/preflight` first with the same body to validate rows (no writes) if you want to catch bad rows before a large import. Max 5000 rows per `/upload` call. Full field reference below.

### 4. Add people to the sequence

Out of scope for this skill — use the **sequence-runner** skill to enroll the imported people.

---

## Import API reference

| Method | Path | Description |
|---|---|---|
| POST | `/api/v1/import/preflight` | Validate rows; report importable/existing state (no writes) |
| POST | `/api/v1/import/upload` | Bulk-create/update accounts + people from flat rows, optionally add to a list |

Rows are upserted — accounts deduped by domain/company-linkedin, people by email/linkedin. Each row needs a person identifier (`email` or `linkedin_url`) and/or account identifier (`website`/`domain` or `company_linkedin`). Max 5000 rows/call.

Full field list — send only the fields you have:
```json
{
  // Person
  "email": "jane.doe@acmecorp.com",
  "linkedin_url": "https://linkedin.com/in/janedoe",
  "first_name": "Jane",
  "last_name": "Doe",
  "title": "VP of Sales",
  "phone": "+1-415-555-0134",
  "mobile_phone": "+1-415-555-0198",
  "person_city": "San Francisco",
  "person_state": "CA",
  "person_country": "United States",
  "work_city": "San Francisco",
  "work_state": "CA",
  "work_country": "United States",

  // Account
  "account_name": "Acme Corporation",
  "website": "https://acmecorp.com",
  "company_linkedin": "https://linkedin.com/company/acmecorp",
  "domain": "acmecorp.com",
  "account_industry": "Software",
  "estimated_num_employees": 850,
  "account_street": "123 Market Street",
  "account_city": "San Francisco",
  "account_region": "CA",
  "account_postal": "94105",
  "account_country": "United States",

  // Flat map: key -> scalar value (string/number/bool only, no nesting).
  // Each column's type routes it onto person or account.
  "custom_columns": {
    "agent_merge_intro_sentence_a1b2c3": "<personalization>"
  }
}
```
