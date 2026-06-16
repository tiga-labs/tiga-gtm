# P13N API Reference

Full request/response detail for AI personalizations (p13ns). Auth: `X-Tiga-Auth: $TIGA_API_KEY` on every request.

**Read first:** `tiga-gtm/docs/merge-fields.md` — available `{{.FieldName}}` variables for p13n prompts. Discover all merge fields including custom columns via `GET /api/v1/mergefields`.

## Writing a Good P13N Prompt

A p13n prompt should:
- Give clear instructions for what to write
- Reference merge fields to personalize the output
- Be specific about length and tone

**Good prompt examples:**

```
Write a single sentence referencing a specific achievement or milestone from
{{.PersonLi_Experience}} that is relevant to a conversation about improving
their sales process. Keep it under 20 words.
```

```
Write a 2-sentence personalized opening for an email to {{.FirstName}},
{{.Title}} at {{.AccountName}}. Reference something specific from their
LinkedIn headline ({{.PersonLi_Headline}}) or recent role change. Be
conversational and avoid generic phrases.
```

```
{{.AccountName}} recently {{.CompanyLi_LatestFunding}}. Write one sentence
acknowledging this milestone in a way that naturally leads into a conversation
about scaling their revenue operations.
```

**Check available merge fields:**
```bash
curl -X GET "https://app.tigalabs.com/api/v1/mergefields" \
  -H "X-Tiga-Auth: $TIGA_API_KEY"
```

## Create a P13N

```bash
curl -X POST "https://app.tigalabs.com/api/v1/p13n" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "Personalized Opening",
    "step_id": "<step-uuid>",
    "prompt": "Write a 2-sentence personalized opening for an email to {{.FirstName}}, {{.Title}} at {{.AccountName}}. Reference something specific from their LinkedIn headline: {{.PersonLi_Headline}}.",
    "word_limit": 60,
    "default_value": "I came across your profile and was impressed by your work.",
    "temperature": 0.6
  }'
```

**Request fields:**

| Field | Required | Description |
|-------|----------|-------------|
| `label` | Yes | Display name for the p13n (also used to generate `key`) |
| `step_id` | Recommended | UUID of the sequence step this p13n belongs to. When set, the p13n is auto-computed when a task is created for that step. |
| `prompt` | Yes | The AI instruction. Use `{{.FieldName}}` for merge fields. |
| `word_limit` | No | Max words in the output (default: 80) |
| `default_value` | No | Fallback text if the person is missing required data |
| `temperature` | No | AI creativity 0.0–1.0 (default: 0.5). Use 0.5–0.7 for outreach text. |

**Response:**

```json
{
  "id": "p13n-uuid",
  "key": "personalized_opening_a1b2c3",
  "label": "Personalized Opening",
  "step_id": "step-uuid",
  "computed_config": {
    "type": "p13n",
    "prompt": "...",
    "word_limit": 60,
    "temperature": 0.6,
    "default_value": "..."
  }
}
```

**Critical:** The `key` field in the response is the merge field identifier — `{{.personalized_opening_a1b2c3}}` in the step's email body or LinkedIn message. Save both `id` (for update/delete/run) and `key` (for the step template).

After a successful create, show the user the newly created p13n:

**See step here: https://app.tigalabs.com/app#/step/:step_id/edit**

(Use `step_id` from the response. Only show this link if `step_id` is present.)

**Inserting the key into a step:** follow the canonical step-PATCH in the sequence-builder SKILL.md (Workflow A Step 6) — the sequence must be **inactive**, the PATCH uses snake_case fields, and in HTML fields (`email_body`, `linkedin_message`) the key must be wrapped in the `<span class="tiga-merge">` format, not inserted as plain text. PascalCase aliases are accepted on PATCH, but conflicting duplicate values are rejected with `400`.

## Preview a P13N on a Real Person

Run the p13n on a specific person to verify the output before activating the sequence.

### Submit the run (async)

```bash
curl -X POST "https://app.tigalabs.com/api/v1/p13n/<p13n-id>/run" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "person_id": "<person-uuid>"
  }'
```

Or by email (finds or creates the person):
```bash
-d '{"person": {"email": "jane@acme.com"}}'
```

**Response:**
```json
{"p13n_id": "...", "person_id": "...", "status": "Running"}
```

### Poll until complete

```bash
curl -X GET "https://app.tigalabs.com/api/v1/p13n/<p13n-id>/run-status?person_id=<person-uuid>" \
  -H "X-Tiga-Auth: $TIGA_API_KEY"
```

**Terminal status values:**
- `"Complete"` — `value` contains the generated text
- `"Not Found"` — person lacked enough data to generate content
- `"Missing Dependencies"` — required merge fields not populated on this person
- `"Error"` — computation failed
- `"Precondition Not Met"` — p13n has a precondition that wasn't met

Poll every 5–10 seconds. Timeout after 120 seconds.

**Complete response:**
```json
{
  "p13n_id": "...",
  "person_id": "...",
  "status": "Complete",
  "value": "I noticed your team at Acme Corp recently expanded into enterprise accounts — a milestone that often brings new challenges around pipeline visibility."
}
```

## List, Update, or Delete P13Ns

**List all p13ns:**
```bash
curl -X GET "https://app.tigalabs.com/api/v1/p13ns" \
  -H "X-Tiga-Auth: $TIGA_API_KEY"
```

**List p13ns for a specific step:**
```bash
curl -X GET "https://app.tigalabs.com/api/v1/p13ns?step_id=<step-uuid>" \
  -H "X-Tiga-Auth: $TIGA_API_KEY"
```

**Get single p13n:**
```bash
curl -X GET "https://app.tigalabs.com/api/v1/p13n/<p13n-id>" \
  -H "X-Tiga-Auth: $TIGA_API_KEY"
```

**Update p13n (writable fields: label, prompt, word_limit, default_value, temperature):**
```bash
curl -X PUT "https://app.tigalabs.com/api/v1/p13n/<p13n-id>" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Updated prompt text here...",
    "word_limit": 50
  }'
```

**Delete p13n:**
```bash
curl -X DELETE "https://app.tigalabs.com/api/v1/p13n/<p13n-id>" \
  -H "X-Tiga-Auth: $TIGA_API_KEY"
```

> **Note:** If the p13n is linked to a step (has `step_id`), also remove its `{{.key}}` merge field from the step's email body or LinkedIn message, otherwise the merge field will render as blank text.
