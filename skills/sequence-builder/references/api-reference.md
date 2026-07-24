# Tiga API Reference — Sequence Builder Subset

## Authentication & Headers

**Base URL:** `https://app.tigalabs.com` (production). The base URL is environment-specific — users may run against their own host (e.g. `http://localhost:3000` in dev, or a custom domain). Honor whatever the user gives you; scripts conventionally read it from `TIGA_BASE`.

**Required auth header (all endpoints):**
```
X-Tiga-Auth: YOUR_API_KEY
Content-Type: application/json
```

Store the key in an env var: `export TIGA_API_KEY="your_key_here"`

**Pagination header** (optional, on list endpoints):
```json
Tiga-Pagination: {"page": 1, "page_size": 25, "sort_by": "created_at", "sort_order": "desc"}
```

**Filter header** (optional, on list endpoints):
```json
Tiga-Filter: {"search_term": "acme", "list_id": "uuid", "sequence_id": "uuid", "filter": []}
```

---

## Sequence Steps API

Steps are the building blocks of sequences. Modify steps only while the sequence is **inactive** — use `POST /api/v1/sequence/:id/deactivate` first.

The sending user's email signature is appended automatically to every outgoing email — do not end `email_body` with a signature or `{{.UserName}}`; close with `Best,` and nothing after it.

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/sequence/:id/add-step` | Add a step to a sequence |
| GET | `/api/v1/step/:id` | Get full step content |
| PATCH | `/api/v1/step/:id` | Update a step's content |
| DELETE | `/api/v1/step/:id` | Delete a step |

**Add step** (`POST /api/v1/sequence/:id/add-step?stepToAppendToId=<uuid>`):

`stepToAppendToId` — the step to insert *after*. Use `00000000-0000-0000-0000-000000000000` (nil UUID) to insert as the first step.

```json
{
  "action": "SequenceEmail",
  "step_name": "Initial Outreach",
  "email_subject": "Quick question about {{.AccountName}}",
  "email_body": "Hi {{.FirstName}},\n\n{{.my_p13n_key}}\n\nBest,",
  "can_run_on_weekends": false
}
```

| Field | Description |
|-------|-------------|
| `action` | `SequenceEmail`, `LinkedInMessage`, or `LinkedInConnect` |
| `step_name` | Display name |
| `email_subject` | Subject line (SequenceEmail only) |
| `email_body` | Email body — supports `{{.FieldName}}` merge fields |
| `linkedin_message` | Message content (LinkedInMessage only) |
| `can_run_on_weekends` | Default: false |

Response includes the new step `ID`.

**Get step** (`GET /api/v1/step/:id`):

Returns the full step object including `EmailBody`, `EmailSubject`, `LinkedInMessage`, `Action`, `Name`, timing fields, and all other persisted values. Always GET a step before patching it — `SequenceEmail` steps require both `EmailSubject` and `EmailBody` in the PATCH body, so you need the current values if you're only changing one.

**Update step** (`PATCH /api/v1/step/:id`):

Send `Action` and the content fields to update. For `SequenceEmail`, always send both `EmailSubject` and `EmailBody` together. Accepts both PascalCase (`EmailBody`) and snake_case (`email_body`).

```json
{
  "Action": "SequenceEmail",
  "EmailSubject": "Updated subject",
  "EmailBody": "Hi {{.FirstName}},\n\n{{.personalized_opening_a1b2c3}}\n\nBest,"
}
```

> When step content is updated, any p13n `{{.key}}` merge fields that no longer appear in the email body, subject, or LinkedIn message are deleted from the p13n table.

---

## Sequences API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/sequences` | List sequences |
| GET | `/api/v1/sequence/:id/description` | Get Markdown summary (steps + metadata) |
| POST | `/api/v1/sequence/:id/activate` | Activate sequence |
| POST | `/api/v1/sequence/:id/deactivate` | Deactivate sequence |

### List Sequences

Returns a paginated list of sequences in your workspace with summary statistics.

**Headers:**

| Header | Required | Description |
|--------|----------|-------------|
| `X-Tiga-Auth` | Yes | Your API key |
| `Tiga-Pagination` | No | JSON: page, page_size, sort_by, sort_order |
| `Tiga-Filter` | No | JSON: search_term, filter |

**Response fields:**

| Field | Type | Description |
|-------|------|-------------|
| `ID` | uuid | Sequence UUID |
| `Name` | string | Sequence name |
| `PlayType` | string | Type: sequence, flow, or signal-list-build |
| `IsEnabled` | boolean | Whether currently active |
| `steps_exist` | boolean | Whether sequence has at least one step |
| `TotalCount` | integer | Total matching sequences (for pagination) |

### Get Sequence Description

Returns a human-readable Markdown summary of the sequence and its steps, including each step's UUID. Use this to discover step IDs before adding, updating, or deleting steps.

```
GET /api/v1/sequence/:id/description
```

**Response:** `200 OK` — `text/markdown`. Includes sequence name, ID, type, status (Active/Inactive), creation date, and a numbered list of steps with action type, schedule, and UUID.

```
# Q3 Outbound — Mid-Market

**ID:** `<sequence-uuid>`
**Type:** sequence
**Status:** Inactive
**Created:** 2026-05-01

## Steps (2)

1. **Initial Outreach** (SequenceEmail) — immediately (weekdays only)
   ID: `<step-uuid-1>`

2. **LinkedIn Follow-up** (LinkedInMessage) — after 3 days (weekdays only)
   ID: `<step-uuid-2>`
```

### Activate / Deactivate a Sequence

Sequences must be **inactive** to modify steps. Use deactivate before making step changes, then reactivate when done.

```
POST /api/v1/sequence/:id/activate
POST /api/v1/sequence/:id/deactivate
```

Both endpoints are idempotent — calling activate on an already-active sequence (or deactivate on an already-inactive one) returns `200` without error.

**Activate response (`200`):**
```json
{"message": "sequence activated", "is_enabled": true}
```

**Deactivate response (`200`):**
```json
{"message": "sequence deactivated", "is_enabled": false}
```

**Activate error responses:**

| Status | Meaning |
|--------|---------|
| `400` | Sequence has no steps, missing required field, or incomplete email content |
| `428` | Tasks are still updating from a previous change — retry after a few seconds |
