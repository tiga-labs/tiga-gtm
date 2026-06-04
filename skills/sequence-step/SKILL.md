---
name: sequence-step
description: "Create or modify sequence steps and build personalized outreach templates. Use this skill whenever the user wants to: add a new step to a sequence, write the email body or LinkedIn message for a step, build a step with AI personalization (p13n), update existing step content, add a phone call reminder, or add a custom task. Trigger phrases: 'add a step to my sequence', 'create a personalized email step', 'build a sequence with AI personalization', 'set up an outreach step', 'update the email body for step', 'create a play with personalized messaging', 'write the email for step 1', 'add a phone call step', 'add a task reminder', 'create a user task', 'add a call step', 'remind the rep to call'. This skill handles the full workflow: create step → create p13n → wire up the merge field."
---

# Sequence Step Skill

Create and manage sequence steps, including building AI-personalized (p13n) templates.

**Read before starting:**
- `tiga-gtm/docs/api-reference.md` (Sequences API section)
- `tiga-gtm/docs/merge-fields.md` — **important**: `email_body` and `linkedin_message` are HTML fields; merge fields in them must use the `<span class="tiga-merge">` format, not plain `{{.FieldName}}` syntax
- `tiga-gtm/skills/p13n-crud/SKILL.md` for p13n creation details

---

## Key Concepts

**Sequence must be inactive to modify steps.** You cannot add, edit, or delete steps while a sequence is enabled. Always deactivate first, make changes, then reactivate.

**Step action types:**

| Action | Description | Content field |
|--------|-------------|---------------|
| `SequenceEmail` | Automated email sent by the system | `EmailSubject` + `EmailBody` |
| `LinkedInMessage` | LinkedIn message sent via Chrome extension | `LinkedInMessage` |
| `LinkedInConnect` | LinkedIn connection request | _(no content body)_ |
| `UserTask` | Manual task reminder shown to the rep (call, review, custom) | `Instructions` |
| `PhoneCall` | Phone call reminder for the rep | `Instructions` |

P13n support: `SequenceEmail` and `LinkedInMessage` support AI personalization via merge fields. `UserTask` and `PhoneCall` do not — they show instructions to the rep, not outreach content.

**How p13ns connect to steps:**
1. Create a step (returns the step's `ID`)
2. Create a p13n with `step_id = <step ID>` (returns a `key` like `personalized_opening_a1b2c3`)
3. Update the step's `EmailBody` or `LinkedInMessage` to include `{{.personalized_opening_a1b2c3}}`
4. When a person is added to the sequence, the system auto-computes the p13n and substitutes the merge field

---

## Workflow A: Create a New Personalized Step

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
    "email_body": "<p>Hi <span class=\"tiga-merge\" data-custom-column-id=\"null\" data-computed-config-type=\"null\" data-value=\"{{.FirstName}}\" data-entity=\"Person\" data-alt-text=\"\">First Name</span>,</p><p>[PERSONALIZATION_PLACEHOLDER]</p><p>Would love to connect and share how we help teams like yours.</p><p>Best,<br><span class=\"tiga-merge\" data-custom-column-id=\"null\" data-computed-config-type=\"null\" data-value=\"{{.UserName}}\" data-entity=\"User\" data-alt-text=\"\">User'\''s Name</span></p>",
    "can_run_on_weekends": false
  }'
```

> **email_body is HTML.** Merge fields must use the `<span class="tiga-merge">` format — see `tiga-gtm/docs/merge-fields.md`. Plain `{{.FieldName}}` text in an email body will appear as raw literal text in the editor and won't render as interactive merge field chips.

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
| `requires_human_approval` | If true, the rep must manually mark the task done before the sequence advances (`UserTask`, `PhoneCall`) |
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

**Save the `key` from the response** — e.g., `personalized_opening_a1b2c3`.

See `tiga-gtm/skills/p13n-crud/SKILL.md` for full p13n options and prompt-writing guidance.

### Step 6: Update the step with the p13n merge field

Replace the placeholder in the email body with the p13n's `<span class="tiga-merge">` element. Use the `key`, `id`, and `computed_config.type` from the p13n response.

```bash
curl -X PATCH "https://app.tigalabs.com/api/v1/step/<new-step-uuid>" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "Action": "SequenceEmail",
    "EmailSubject": "Quick question about {{.AccountName}}",
    "EmailBody": "<p>Hi <span class=\"tiga-merge\" data-custom-column-id=\"null\" data-computed-config-type=\"null\" data-value=\"{{.FirstName}}\" data-entity=\"Person\" data-alt-text=\"\">First Name</span>,</p><p><span class=\"tiga-merge\" data-custom-column-id=\"<p13n-id>\" data-computed-config-type=\"<computed_config.type>\" data-value=\"{{.personalized_opening_a1b2c3}}\" data-entity=\"AiSection\" data-alt-text=\"\">Personalized Opening</span></p><p>Would love to connect and share how we help teams like yours.</p><p>Best,<br><span class=\"tiga-merge\" data-custom-column-id=\"null\" data-computed-config-type=\"null\" data-value=\"{{.UserName}}\" data-entity=\"User\" data-alt-text=\"\">User'\''s Name</span></p>"
  }'
```

> **Important:** When updating a `SequenceEmail` step, always send both `EmailSubject` and `EmailBody` together. The handler parses both fields together when `Action == "SequenceEmail"`.

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

### Step 8: Activate the sequence

```bash
curl -X POST "https://app.tigalabs.com/api/v1/sequence/<sequence-id>/activate" \
  -H "X-Tiga-Auth: $TIGA_API_KEY"
```

---

## Workflow B: Update Existing Step Content

**Use when:** The step already exists and you want to change its email body, subject, or LinkedIn message.

### Steps

1. **Get sequence description** to find the step ID:
   ```bash
   curl -X GET "https://app.tigalabs.com/api/v1/sequence/<sequence-id>/description" \
     -H "X-Tiga-Auth: $TIGA_API_KEY"
   ```

2. **Deactivate the sequence:**
   ```bash
   curl -X POST "https://app.tigalabs.com/api/v1/sequence/<sequence-id>/deactivate" \
     -H "X-Tiga-Auth: $TIGA_API_KEY"
   ```

3. **Read the current step content** before patching — required for `SequenceEmail` steps where you need to preserve one of the two fields (subject or body):
   ```bash
   curl -X GET "https://app.tigalabs.com/api/v1/step/<step-id>" \
     -H "X-Tiga-Auth: $TIGA_API_KEY"
   ```

4. **Update the step:**

   For email steps (`email_body` is HTML — use `<span class="tiga-merge">` for merge fields):
   ```bash
   curl -X PATCH "https://app.tigalabs.com/api/v1/step/<step-id>" \
     -H "X-Tiga-Auth: $TIGA_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "Action": "SequenceEmail",
       "EmailSubject": "New subject line",
       "EmailBody": "<p>Hi <span class=\"tiga-merge\" data-custom-column-id=\"null\" data-computed-config-type=\"null\" data-value=\"{{.FirstName}}\" data-entity=\"Person\" data-alt-text=\"\">First Name</span>, <span class=\"tiga-merge\" data-custom-column-id=\"<p13n-id>\" data-computed-config-type=\"<p13n-type>\" data-value=\"{{.my_p13n_key}}\" data-entity=\"AiSection\" data-alt-text=\"\">My P13n Label</span></p>"
     }'
   ```

   For LinkedIn steps (`linkedin_message` is also HTML — same span format):
   ```bash
   curl -X PATCH "https://app.tigalabs.com/api/v1/step/<step-id>" \
     -H "X-Tiga-Auth: $TIGA_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "Action": "LinkedInMessage",
       "LinkedInMessage": "<p>Hi <span class=\"tiga-merge\" data-custom-column-id=\"null\" data-computed-config-type=\"null\" data-value=\"{{.FirstName}}\" data-entity=\"Person\" data-alt-text=\"\">First Name</span>, <span class=\"tiga-merge\" data-custom-column-id=\"<p13n-id>\" data-computed-config-type=\"<p13n-type>\" data-value=\"{{.my_p13n_key}}\" data-entity=\"AiSection\" data-alt-text=\"\">My P13n Label</span></p>"
     }'
   ```

   For task or call steps (`Instructions` is plain text — use `{{.FieldName}}` directly):
   ```bash
   curl -X PATCH "https://app.tigalabs.com/api/v1/step/<step-id>" \
     -H "X-Tiga-Auth: $TIGA_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "Action": "UserTask",
       "Instructions": "Call {{.FirstName}} at {{.Phone}} to follow up on the email. Reference their role as {{.Title}} at {{.AccountName}}."
     }'
   ```
   ```bash
   curl -X PATCH "https://app.tigalabs.com/api/v1/step/<step-id>" \
     -H "X-Tiga-Auth: $TIGA_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "Action": "PhoneCall",
       "Instructions": "Call {{.FirstName}} — mention the email you sent and ask about their current outreach process."
     }'
   ```

5. **Reactivate:**
   ```bash
   curl -X POST "https://app.tigalabs.com/api/v1/sequence/<sequence-id>/activate" \
     -H "X-Tiga-Auth: $TIGA_API_KEY"
   ```

> **Note:** When you update a step's content, any p13n `{{.key}}` merge fields that no longer appear in the email body or LinkedIn message are automatically deleted (orphaned p13ns are cleaned up by the system).

---

## Workflow C: Add a Phone Call or Task Step

**Use when:** Adding a manual reminder step — a phone call prompt or a custom task for the rep. These are simpler than email/LinkedIn steps: no email body, no p13n.

### Steps

1. **Deactivate the sequence** (Steps 1–3 from Workflow A)

2. **Add the step:**

   Phone call step:
   ```bash
   curl -X POST "https://app.tigalabs.com/api/v1/sequence/<sequence-id>/add-step?stepToAppendToId=<last-step-id>" \
     -H "X-Tiga-Auth: $TIGA_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "action": "PhoneCall",
       "step_name": "Follow-up Call",
       "step_instructions": "Call {{.FirstName}} at {{.Phone}}. Reference the email you sent 3 days ago. Ask about their current outreach process.",
       "requires_human_approval": true,
       "can_run_on_weekends": false
     }'
   ```

   Custom task step:
   ```bash
   curl -X POST "https://app.tigalabs.com/api/v1/sequence/<sequence-id>/add-step?stepToAppendToId=<last-step-id>" \
     -H "X-Tiga-Auth: $TIGA_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "action": "UserTask",
       "step_name": "Research Before Call",
       "step_instructions": "Review {{.AccountName}}'s LinkedIn page and note any recent company news. Look for a relevant hook for the call.",
       "requires_human_approval": true,
       "can_run_on_weekends": false
     }'
   ```

   > `requires_human_approval: true` means the rep must mark the task done before the sequence advances to the next step. Set to `false` if the step should auto-complete after the delay.

3. **Activate the sequence:**
   ```bash
   curl -X POST "https://app.tigalabs.com/api/v1/sequence/<sequence-id>/activate" \
     -H "X-Tiga-Auth: $TIGA_API_KEY"
   ```

---

## Available Merge Fields

See `tiga-gtm/docs/merge-fields.md` for the full reference including entity types and display labels.

**Key rule:** `email_body` and `linkedin_message` are HTML — merge fields in them require the `<span class="tiga-merge">` HTML format. `Instructions` (UserTask/PhoneCall) and AI prompt fields use plain `{{.FieldName}}` syntax.

Common fields (for plain-text contexts — convert to span format for HTML fields):

**Person:** `{{.FirstName}}` (First Name), `{{.LastName}}` (Last Name), `{{.Title}}` (Title), `{{.EmailAddress}}` (Email Address), `{{.LinkedInUrl}}` (LinkedIn URL), `{{.City}}` (City), `{{.State}}` (State) — entity: `Person`

**Account:** `{{.AccountName}}` (Account Name), `{{.AccountIndustry}}` (Industry), `{{.AccountWebsite}}` (Website), `{{.AccountLinkedInUrl}}` (LinkedIn Url) — entity: `Account`

**LinkedIn (requires enrichment):** `{{.PersonLi_Headline}}` (Headline), `{{.PersonLi_Summary}}` (Profile Summary), `{{.PersonLi_Experience}}` (Experience) — entity: `LiPersonFact`; `{{.CompanyLi_LatestFunding}}` (Latest Funding), `{{.CompanyLi_Tagline}}` (Tagline) — entity: `LiCompanyFact`

**User:** `{{.UserName}}` (User's Name), `{{.UserRole}}` (User's Role) — entity: `User`

**Dates:** `{{.CurrentDate}}` — entity: `CurrentDate`; `{{.Last7Days}}`, `{{.Last30Days}}`, `{{.Last90Days}}` — entity: `SearchDays`

Get the full list: `GET /api/v1/mergefields`
