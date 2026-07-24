---
name: sequence-builder
description: "Author and modify outbound sequence content with the Tiga API — steps and their AI personalizations. Use this skill whenever the user wants to: add a step to a sequence, write or update the email body or LinkedIn message for a step, build a step with AI personalization (p13n), add a phone call or task step, create a custom AI intro/opening line, or reference something unique per person in their outreach. Trigger phrases: 'add a step to my sequence', 'create a personalized email step', 'write the email for step 1', 'personalize my outreach', 'AI opening line', 'I want the email to reference their recent funding', 'add a call step', 'create a p13n'. Handles the full workflow: create step → create p13n → wire up the merge field. NOT for enrolling people in sequences or checking open/reply rates (use sequence-runner) and NOT for play_type: flow agent automations (use flow-builder)."
---

# Sequence Builder Skill

Author sequence steps and their AI personalizations (p13ns) — the content side of outbound sequences. This is the **authoring** half of the sequence lifecycle; the **running** half — enrolling and removing people, activating, and monitoring performance — is the **sequence-runner** skill. If the task is about who's in the sequence or how it's performing rather than what the steps say, hand it to **sequence-runner**.

**Read before starting:**
- `references/api-reference.md` (Sequences API and Sequence Steps API)
- `tiga-gtm/docs/merge-fields.md` — **important**: `email_body` and `linkedin_message` are HTML fields; merge fields in them must use the `<span class="tiga-merge">` format, not plain `{{.FieldName}}` syntax
- `tiga-gtm/skills/sequence-builder/references/p13n-api.md` for full p13n API detail and prompt-writing guidance

---

## Key Concepts

**Sequence must be inactive to modify steps.** You cannot add, edit, or delete steps while a sequence is enabled. Always deactivate first, make changes, then reactivate.

**Email signature is appended automatically.** Tiga appends the sending user's stored email signature to every outgoing email at send time. Never write a signature or the sender's name at the end of an `email_body` — end the email with a short closing like `Best,` and nothing after it. Do not use `{{.UserName}}` as a sign-off. (Emails only — LinkedIn messages do not get a signature appended.)

**Field casing differs by endpoint:**
- Add-step requests use semantic snake_case fields such as `step_name` and `step_instructions`.
- PATCH requests accept snake_case or PascalCase aliases. Use snake_case consistently, always include `action`, and send only fields relevant to that action. `SequenceEmail` updates must include both `email_subject` and `email_body`.
- GET and create responses use the persisted step model and are mostly PascalCase. Do not copy an entire GET response into a PATCH request or mix its PascalCase fields with snake_case fields.

**Step action types:**

| Action | Description | Content field |
|--------|-------------|---------------|
| `SequenceEmail` | Automated email sent by the system | `EmailSubject` + `EmailBody` |
| `LinkedInMessage` | LinkedIn message sent via Chrome extension | `LinkedInMessage` |
| `LinkedInConnect` | LinkedIn connection request | _(no content body)_ |
| `UserTask` | Manual task reminder shown to the rep (call, review, custom) | `Instructions` |
| `PhoneCall` | Phone call reminder for the rep | `Instructions` |

P13n support: `SequenceEmail` and `LinkedInMessage` support AI personalization via merge fields. `UserTask` and `PhoneCall` do not — they show instructions to the rep, not outreach content.

**Human approval:** the add-step field `requires_human_approval` works on **every** step type.  On `SequenceEmail`, `LinkedInMessage`, and `LinkedInConnect` steps, `true` holds each generated message in the approval queue — nothing is sent until a rep approves it. On `UserTask`/`PhoneCall` steps, `true` means the rep must mark the task done before the sequence advances. If the user wants to review emails before they send, set this flag on the email step itself. ALWAYS set the first step of a sequence requires_human_approval = true. This ensures that the user will be able to review any sequence before sending.

**What is a p13n?** An AI-generated text snippet written fresh for each person the moment their outreach task is created. It is **step-linked** (attached via `step_id`), **ephemeral** (recomputed per person at task creation, not stored as a standing fact), and **template-embedded** (referenced in the step's content as `{{.key}}`).

**P13Ns vs. Signals:**
| | P13N | Signal |
|---|---|---|
| Output | Outreach text (sentence, paragraph) | Fact or insight stored on person/account |
| Timing | Computed when task is created | Computed on demand or in batch |
| Stored where | Person's custom_columns (ephemeral per task) | Person's custom_columns (persistent) |
| Use case | Email opening, personalized hook, LinkedIn intro | Funding status, hiring signals, tech stack |

Use a **p13n** when the output appears directly in email or LinkedIn content. Use a **signal** (signals skill) to store a fact for filtering, scoring, or routing.

**How p13ns connect to steps:**
1. Create a step (returns the step's `ID`)
2. Create a p13n with `step_id = <step ID>` (returns a `key` like `personalized_opening_a1b2c3`)
3. Update the step's `email_body` or `linkedin_message` to include `{{.personalized_opening_a1b2c3}}`
4. When a person is added to the sequence, the system auto-computes the p13n and substitutes the merge field

---

## Workflow A: Create a New Personalized Step

Two ways to personalize a step — pick based on whether the personalization already exists as data you can put in a CSV, or needs to be AI-generated per person:

- **You already have (or can build) a CSV of people with the personalization as a column** — e.g. a pre-written intro sentence, a scraped fact, anything you can compute or already know per person outside of Tiga. Use `references/p13n-with-custom-columns.md`. No p13n/AI generation involved — the value is just imported as a custom column and referenced as a plain `{{.field}}` merge field.
- **You don't already know the list of people, or the personalization needs to be generated by AI per person at task-creation time** (e.g. "write a sentence referencing their recent LinkedIn activity"). Use `references/p13n-with-ai-custom-section.md` — this is the p13n workflow described above.

---

## Workflow B: Update Existing Step Content

**Use when:** The step already exists and you want to change its email body, subject, or LinkedIn message.

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
       "action": "SequenceEmail",
       "email_subject": "New subject line",
       "email_body": "<p>Hi <span class=\"tiga-merge\" data-custom-column-id=\"null\" data-computed-config-type=\"null\" data-value=\"{{.FirstName}}\" data-entity=\"Person\" data-alt-text=\"\">First Name</span>, <span class=\"tiga-merge\" data-custom-column-id=\"<p13n-id>\" data-computed-config-type=\"<p13n-type>\" data-value=\"{{.my_p13n_key}}\" data-entity=\"AiSection\" data-alt-text=\"\">My P13n Label</span></p>"
     }'
   ```

   For LinkedIn steps (`linkedin_message` is also HTML — same span format):
   ```bash
   curl -X PATCH "https://app.tigalabs.com/api/v1/step/<step-id>" \
     -H "X-Tiga-Auth: $TIGA_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "action": "LinkedInMessage",
       "linkedin_message": "<p>Hi <span class=\"tiga-merge\" data-custom-column-id=\"null\" data-computed-config-type=\"null\" data-value=\"{{.FirstName}}\" data-entity=\"Person\" data-alt-text=\"\">First Name</span>, <span class=\"tiga-merge\" data-custom-column-id=\"<p13n-id>\" data-computed-config-type=\"<p13n-type>\" data-value=\"{{.my_p13n_key}}\" data-entity=\"AiSection\" data-alt-text=\"\">My P13n Label</span></p>"
     }'
   ```

   For task or call steps (`instructions` is plain text — use `{{.FieldName}}` directly):
   ```bash
   curl -X PATCH "https://app.tigalabs.com/api/v1/step/<step-id>" \
     -H "X-Tiga-Auth: $TIGA_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "action": "UserTask",
       "instructions": "Call {{.FirstName}} at {{.Phone}} to follow up on the email. Reference their role as {{.Title}} at {{.AccountName}}."
     }'
   ```
   ```bash
   curl -X PATCH "https://app.tigalabs.com/api/v1/step/<step-id>" \
     -H "X-Tiga-Auth: $TIGA_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "action": "PhoneCall",
       "instructions": "Call {{.FirstName}} — mention the email you sent and ask about their current outreach process."
     }'
   ```

5. **Reactivate:**
   ```bash
   curl -X POST "https://app.tigalabs.com/api/v1/sequence/<sequence-id>/activate" \
     -H "X-Tiga-Auth: $TIGA_API_KEY"
   ```

> **Note:** When you update a step's content, any p13n `{{.key}}` merge fields that no longer appear in the email body, email subject, LinkedIn message, or instructions are automatically deleted.

---

## Workflow C: Add a Phone Call or Task Step

**Use when:** Adding a manual reminder step — a phone call prompt or a custom task for the rep. These are simpler than email/LinkedIn steps: no email body, no p13n.

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

   > `requires_human_approval: true` means the rep must mark the task done before the sequence advances to the next step. Set to `false` if the step should auto-complete after the delay (see Key Concepts).

3. **Activate the sequence:**
   ```bash
   curl -X POST "https://app.tigalabs.com/api/v1/sequence/<sequence-id>/activate" \
     -H "X-Tiga-Auth: $TIGA_API_KEY"
   ```

---

## Workflow D: Manage P13Ns Directly

List, inspect, update, or delete personalizations independently of step authoring:

- List all: `GET /api/v1/p13ns` (or `?step_id=<step-uuid>` for one step's p13ns)
- Get one: `GET /api/v1/p13n/<p13n-id>`
- Update: `PUT /api/v1/p13n/<p13n-id>` — writable fields: `label`, `prompt`, `word_limit`, `default_value`, `temperature`
- Delete: `DELETE /api/v1/p13n/<p13n-id>`

> **Warning:** If a deleted p13n is linked to a step, also remove its `{{.key}}` merge field from the step's content, otherwise the merge field renders as blank text.

Full payloads, preview-run polling, and prompt-writing guidance with examples: `references/p13n-api.md`.

---

## Merge Fields

See `tiga-gtm/docs/merge-fields.md` for the full reference including entity types, display labels, and the common field list (Person, Account, LinkedIn, User, Dates).

**Key rule:** `email_body` and `linkedin_message` are HTML — merge fields in them require the `<span class="tiga-merge">` HTML format. `instructions` (UserTask/PhoneCall) and AI prompt fields (p13n prompts, signal prompts) use plain `{{.FieldName}}` syntax.

**Signature rule:** never end an `email_body` with `{{.UserName}}` — the user's email signature is appended automatically at send time. Close with `Best,` and nothing after it.

Get the full list including custom columns: `GET /api/v1/mergefields`

---

**Related skills:** **sequence-runner** to enroll people in the sequence and monitor performance; **signals** for persistent facts used in filtering/scoring; **flow-builder** for `play_type: flow` agent automations.
