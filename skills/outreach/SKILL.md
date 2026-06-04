---
name: outreach
description: "Manage outreach sequences and personalize messaging using the Tiga API. Use this skill whenever the user wants to add people to email sequences, personalize cold outreach with AI, check sequence performance metrics (open rates, reply rates), or manage sales cadences. Also trigger when the user says 'add them to a sequence', 'personalize these emails', 'how is my sequence performing?', 'write outreach for this list', or any task about sending, personalizing, or measuring sales outreach."
---

# Outreach Skill

Manage sequences, personalize messaging, and monitor outreach performance.

**Before starting:** Read `tiga-gtm/docs/api-reference.md` for Sequences API endpoint details. Read `tiga-gtm/docs/merge-fields.md` when creating personalization signals.

**Related skills:** Use **contact-discovery** first to find and enrich contacts. Use **signals** to generate personalization data. Use **lead-routing** if leads need qualification before enrollment.

---

## Workflow A: Personalized Outreach

**Use when:** You want to build a sequence step with AI-generated personalized content for each contact.

**Recommended approach:** Use `tiga-gtm/skills/sequence-step/SKILL.md` (Workflow A) for the full step + p13n setup. That skill covers: deactivate sequence → add step → create p13n → insert `{{.key}}` into template → activate.

**Alternative approach (pre-compute on a list):** If you want to run a personalization signal on a list *before* adding people to a sequence (e.g., to review the output first), use a `type: "p13n"` signal:

```bash
curl -X POST "https://app.tigalabs.com/api/v1/p13n" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "Outreach Opening",
    "prompt": "Write a personalized 2-sentence opening for a cold email to {{.FirstName}} {{.LastName}}, {{.Title}} at {{.AccountName}}. Reference something specific about their background ({{.PersonLi_Headline}}, {{.PersonLi_Experience}}) or their company. The email is about: <describe your value prop>.",
    "word_limit": 80,
    "default_value": "I came across your profile and was impressed by your work.",
    "temperature": 0.7
  }'
```

Then run on a list:
```bash
curl -X POST "https://app.tigalabs.com/api/v1/lists/<list-id>/run-all-signal" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"signal_ids": ["<p13n-id>"]}'
```

Poll: `POST /api/v1/lists-signal/bulk-status` (use `people_ids` for person lists).

Read output: `GET /api/v1/person/<person-id>/signals`

---

## Workflow B: Add Enriched Contacts to a Sequence

**Use when:** You have enriched contacts (with `person_id` values) and want to add them to an active sequence.

### Steps

1. **List available sequences** to find the target:
```bash
curl -X GET "https://app.tigalabs.com/api/v1/sequences" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Tiga-Pagination: {\"page\":1,\"page_size\":25,\"sort_by\":\"updated_at\",\"sort_order\":\"desc\"}"
```
   Look for a sequence where `IsEnabled` is `true` and `steps_exist` is `true`.

2. **Add people to the sequence:**
```bash
curl -X POST "https://app.tigalabs.com/api/v1/sequence/<sequence-id>/add-people" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "people_ids": ["<person-id-1>", "<person-id-2>", "<person-id-3>"]
  }'
```

   **Response:**
   ```json
   {
     "new_people": ["<person-id-1>", "<person-id-3>"],
     "duplicates": ["<person-id-2>"]
   }
   ```
   - `new_people`: Successfully added
   - `duplicates`: Already in the sequence, skipped

   **Optional parameters:**
   - `step_id`: Add people at a specific step (default: first step)
   - `list_id`: Scope selection to a list's members
   - `select_all` + `filter`: Dynamically select people
   - `excluded_people_ids`: Exclude specific people from selection

3. **Verify enrollment** by checking sequence metrics (Workflow C).

---

## Workflow C: Monitor Sequence Performance

**Use when:** You want to check how a sequence is performing — open rates, reply rates, LinkedIn activity, etc.

### Steps

1. **Get sequence metrics:**
```bash
curl -X GET "https://app.tigalabs.com/api/v1/sequence/<sequence-id>/metrics" \
  -H "X-Tiga-Auth: $TIGA_API_KEY"
```

   **Optional query parameters:**
   - `sortBy=step_name` — Sort by field
   - `sortOrder=asc` — Sort direction
   - `startDate=2026-03-01T00:00:00Z` — Filter activity from date
   - `endDate=2026-03-20T00:00:00Z` — Filter activity until date

2. **Analyze the response:**

   The response has three top-level keys:
   - **`activity`** — Per-step metrics array. Key fields per step:
     - `step_name`, `step_type` (SequenceEmail, LinkedInMessage, etc.)
     - `added_to_sequence` — People who entered this step
     - `email_send`, `email_open`, `email_reply`, `email_click`, `email_bounce`
     - `li_message_send`, `li_connection_send`, `li_connection_accepted`
     - `call_logged`
   - **`pending`** — Per-step pending task counts (people in step, scheduled, running, ready for approval)
   - **`duration`** — Estimated sequence duration in days

3. **Calculate key metrics:**
   - **Open rate**: `email_open / email_send`
   - **Reply rate**: `email_reply / email_send`
   - **Click rate**: `email_click / email_send`
   - **Bounce rate**: `email_bounce / email_send`
   - **LinkedIn acceptance rate**: `li_connection_accepted / li_connection_send`

4. **Compare across steps** to identify which steps perform best and where drop-off occurs.
