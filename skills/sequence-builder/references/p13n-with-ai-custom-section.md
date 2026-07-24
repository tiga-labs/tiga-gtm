# Creating Personalization Step

**Use when:** Adding a new step to an existing sequence with AI-generated personalization.

### Step 1: Find the target sequence

```bash
curl -X GET "https://app.tigalabs.com/api/v1/sequences" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Tiga-Pagination: {\"page\":1,\"page_size\":25,\"sort_by\":\"updated_at\",\"sort_order\":\"desc\"}"
```

Note the sequence `ID` and `IsEnabled` status.

### Step 2: Deactivate the sequence (if active)

```bash
curl -X POST "https://app.tigalabs.com/api/v1/sequence/<sequence-id>/deactivate" \
  -H "X-Tiga-Auth: $TIGA_API_KEY"
```

### Step 3: Get the sequence description (find existing step IDs)

```bash
curl -X GET "https://app.tigalabs.com/api/v1/sequence/<sequence-id>/description" \
  -H "X-Tiga-Auth: $TIGA_API_KEY"
```

Response is Markdown showing all steps with their UUIDs. Example:
```
## Steps (2)

1. **Send Email - Initial Outreach** (SequenceEmail) — immediately (weekdays only)
   ID: `step-uuid-1`

2. **LinkedIn Follow-up** (LinkedInMessage) — after 3 days (weekdays only)
   ID: `step-uuid-2`
```

### Step 4: Add the step

To append after the last step, use the last step's UUID as `stepToAppendToId`. To insert as the **first** step, use the nil UUID `00000000-0000-0000-0000-000000000000`.

```bash
curl -X POST "https://app.tigalabs.com/api/v1/sequence/<sequence-id>/add-step?stepToAppendToId=<last-step-id>" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "SequenceEmail",
    "step_name": "Initial Outreach",
    "email_subject": "Quick question about {{.AccountName}}",
    "email_body": "<p>Hi <span class=\"tiga-merge\" data-custom-column-id=\"null\" data-computed-config-type=\"null\" data-value=\"{{.FirstName}}\" data-entity=\"Person\" data-alt-text=\"\">First Name</span>,</p><p>[PERSONALIZATION_PLACEHOLDER]</p><p>Would love to connect and share how we help teams like yours.</p><p>Best,</p>",
    "requires_human_approval": true,
    "can_run_on_weekends": false
  }'
```

> **email_body is HTML.** Merge fields must use the `<span class="tiga-merge">` format — see `tiga-gtm/docs/merge-fields.md`. Plain `{{.FieldName}}` text in an email body will appear as raw literal text in the editor and won't render as interactive merge field chips.

> **No signature.** The sending user's email signature is appended automatically at send time — end the body with `<p>Best,</p>` and nothing after it; never add `{{.UserName}}` or a written-out signature.

> **Human review:** `requires_human_approval: true` each generated email waits in the sequence approval queue and nothing sends until a rep approves it. Set it to `true` if the user wants to review emails before they go out; omit or set `false` for fully automated sending.

**Response:**
```json
{
  "ID": "new-step-uuid",
  "Action": "SequenceEmail",
  "EmailSubject": "Quick question about {{.AccountName}}",
  "EmailBody": "..."
}
```

Save the `ID` — you need it to create the p13n.

After a successful create, show the user the newly created step:

**See step here: https://app.tigalabs.com/app#/step/:ID/edit**

(Use `ID` from the response.)

**Step fields:**

| Field | Description |
|-------|-------------|
| `action` | Required. See action types table above. |
| `step_name` | Display name for the step |
| `email_subject` | Email subject line (`SequenceEmail` only) |
| `email_body` | Email body HTML (`SequenceEmail` only) — merge fields must use `<span class="tiga-merge">` format, **not** plain `{{.FieldName}}` |
| `linkedin_message` | LinkedIn message HTML (`LinkedInMessage` only) — same span format as email_body |
| `step_instructions` | Task or call instructions shown to the rep (`UserTask`, `PhoneCall`) — plain text, use `{{.FieldName}}` directly |
| `requires_human_approval` | If true, a rep must approve the task before it executes — works on **every** step type. On `SequenceEmail`/`LinkedInMessage`/`LinkedInConnect`, the generated message waits in the approval queue and nothing sends until approved. On `UserTask`/`PhoneCall`, the rep must mark the task done before the sequence advances |
| `can_run_on_weekends` | Whether the step can run on weekends (default: false) |

### Step 5: Create the P13N

```bash
curl -X POST "https://app.tigalabs.com/api/v1/p13n" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "Personalized Opening",
    "step_id": "<new-step-uuid>",
    "prompt": "Write a 2-sentence personalized opening for an email to {{.FirstName}}, {{.Title}} at {{.AccountName}}. Reference something specific from their LinkedIn headline: {{.PersonLi_Headline}}. Be conversational.",
    "word_limit": 60,
    "default_value": "I came across your profile and was impressed by your background.",
    "temperature": 0.6
  }'
```

**Save the `key` from the response** — e.g., `personalized_opening_a1b2c3` — and the `id`. P13n prompts use plain `{{.FieldName}}` merge syntax. Full request-field table, response shape, and prompt-writing guidance: `references/p13n-api.md`.

### Step 6: Update the step with the p13n merge field

Replace the placeholder in the email body with the p13n's `<span class="tiga-merge">` element. Use the `key`, `id`, and `computed_config.type` from the p13n response.

```bash
curl -X PATCH "https://app.tigalabs.com/api/v1/step/<new-step-uuid>" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "SequenceEmail",
    "email_subject": "Quick question about {{.AccountName}}",
    "email_body": "<p>Hi <span class=\"tiga-merge\" data-custom-column-id=\"null\" data-computed-config-type=\"null\" data-value=\"{{.FirstName}}\" data-entity=\"Person\" data-alt-text=\"\">First Name</span>,</p><p><span class=\"tiga-merge\" data-custom-column-id=\"<p13n-id>\" data-computed-config-type=\"<computed_config.type>\" data-value=\"{{.personalized_opening_a1b2c3}}\" data-entity=\"AiSection\" data-alt-text=\"\">Personalized Opening</span></p><p>Would love to connect and share how we help teams like yours.</p><p>Best,</p>"
  }'
```

> **Important:** When updating a `SequenceEmail` step, always send both `email_subject` and `email_body` together.
> **Use snake_case keys** for all PATCH requests. Equivalent snake_case and PascalCase aliases are deduplicated, but conflicting values are rejected with a `400` response.

### Step 7: (Optional) Preview the p13n on a sample person

```bash
# Start async run
curl -X POST "https://app.tigalabs.com/api/v1/p13n/<p13n-id>/run" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"person_id": "<a-real-person-uuid>"}'

# Poll until complete
curl -X GET "https://app.tigalabs.com/api/v1/p13n/<p13n-id>/run-status?person_id=<person-uuid>" \
  -H "X-Tiga-Auth: $TIGA_API_KEY"
```

Terminal statuses, polling cadence, and the by-email variant: `references/p13n-api.md`.

### Step 8: Activate the sequence

```bash
curl -X POST "https://app.tigalabs.com/api/v1/sequence/<sequence-id>/activate" \
  -H "X-Tiga-Auth: $TIGA_API_KEY"
```