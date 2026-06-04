---
name: p13n-crud
description: "Create, update, delete, and preview AI personalizations (p13ns) for sequence steps. Use this skill whenever the user wants to write personalized content for outreach — a custom email opening, a personalized LinkedIn intro, a reference to the prospect's recent activity, or any AI-generated text that should be unique per person. Trigger phrases: 'personalize my outreach', 'write a custom intro', 'add a personalized section', 'AI opening line', 'personalized email', 'personalized LinkedIn message', 'create a p13n', 'add an AI section'. Also trigger when the user says something like 'I want the email to reference their recent funding' or 'write something specific to each person's background' even if they don't use the word 'personalization'."
---

# P13N CRUD Skill

Create and manage AI personalizations for sequence step email and LinkedIn message templates.

**Read before starting:**
- `tiga-gtm/docs/merge-fields.md` — Available `{{.FieldName}}` variables for p13n prompts
- `GET /api/v1/mergefields` — Discover all merge fields including custom columns

---

## What Is a P13N?

A **p13n** (AI personalization) is an AI-generated text snippet written fresh for each person the moment their outreach task is created in a sequence. It is:

- **Step-linked**: attached to a specific sequence step via `step_id`
- **Ephemeral**: recomputed for every person at task creation time, not stored as a standing fact
- **Template-embedded**: referenced in the step's email body or LinkedIn message as `{{.key}}`

**P13Ns vs. Signals:**
| | P13N | Signal |
|---|---|---|
| Output | Outreach text (sentence, paragraph) | Fact or insight stored on person/account |
| Timing | Computed when task is created | Computed on demand or in batch |
| Stored where | Person's custom_columns (ephemeral per task) | Person's custom_columns (persistent) |
| Use case | Email opening, personalized hook, LinkedIn intro | Funding status, hiring signals, tech stack |

Use a **p13n** when the output will appear directly in email or LinkedIn content.
Use a **signal** when you want to store a fact and potentially use it for filtering, scoring, or routing.

---

## Workflow A: Create a P13N

**When to use:** You have a step ready and want to add a personalized AI-generated section to its template.

### Step 1: Write a good p13n prompt

A p13n prompt should:
- Give clear instructions for what to write
- Reference merge fields to personalize the output (see `tiga-gtm/docs/merge-fields.md`)
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

### Step 2: Create the P13N

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

**Critical:** The `key` field in the response is the merge field identifier. You will use `{{.personalized_opening_a1b2c3}}` in the step's email body or LinkedIn message. Save both `id` (for update/delete/run) and `key` (for the step template).

After a successful create, show the user the newly created p13n:

**See step here: https://app.tigalabs.com/app#/step/:step_id/edit**

(Use `step_id` from the response. Only show this link if `step_id` is present.)

### Step 3: Insert the merge field into the step template

After creating the p13n, update the step's email body to include `{{.key}}`:

```bash
curl -X PATCH "https://app.tigalabs.com/api/v1/step/<step-id>" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "Action": "SequenceEmail",
    "EmailSubject": "Quick question about {{.AccountName}}",
    "EmailBody": "Hi {{.FirstName}},\n\n{{.personalized_opening_a1b2c3}}\n\nWould love to show you how we help companies like yours improve pipeline velocity.\n\nBest,\n{{.UserName}}"
  }'
```

> **Note:** The sequence must be **inactive** to update step content. Use `POST /api/v1/sequence/:id/deactivate` first if needed. See `tiga-gtm/skills/sequence-step/SKILL.md` for the full step workflow.

---

## Workflow B: Preview a P13N on a Real Person

Run the p13n on a specific person to verify the output before activating the sequence.

### Step 1: Submit the run (async)

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

### Step 2: Poll until complete

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

---

## Workflow C: List, Update, or Delete P13Ns

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
