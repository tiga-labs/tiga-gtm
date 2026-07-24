# Tiga API Reference — Sequence Runner Subset

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

## Users API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/me` | Get the API key's own user + workspace |
| GET | `/api/v1/users` | List workspace users (requires Admin) |

### Get Current User

```
GET /api/v1/me
```

Returns the user and workspace behind the API key. **No Admin role required — works with any key.** Use this to resolve "me" before filtering sequences by owner (`GET /api/v1/engagement/people`, `OwnerId` matching on `GET /api/v1/sequences`) or assigning ownership.

**Response fields:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | uuid | The key's user UUID |
| `name` | string | User's display name |
| `email` | string | User's email |
| `org_id` | uuid | Workspace UUID |
| `org_name` | string | Workspace name |
| `is_admin` | boolean | Whether the key can call Admin-gated endpoints (e.g. `GET /api/v1/users`) |
| `is_play_admin` | boolean | Whether the key can call Play-Admin-gated endpoints (e.g. assign-owner) |
| `is_people_admin` | boolean | Whether the key can call People-Admin-gated endpoints (e.g. `DELETE /api/v1/accounts`) |

### List Users

Returns all users in your workspace, sorted by name. Use this to resolve a user's name or email to their UUID — e.g. before assigning sequence ownership.

**Response fields:** `id` (uuid), `name` (string), `email` (string), `created_at` (datetime).

**Error responses:** `401` — API key's user is not an Admin.

---

## Sequences API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/sequences` | List sequences |
| GET | `/api/v1/sequence/:id/metrics` | Get per-step metrics |
| POST | `/api/v1/sequence/:id/activate` | Activate sequence |
| POST | `/api/v1/sequence/:id/deactivate` | Deactivate sequence |
| POST | `/api/v1/sequence/:id/add-people` | Add people to sequence |
| POST | `/api/v1/sequence/:id/remove-people` | Remove people from sequence |
| POST | `/api/v1/sequence/:id/assign-owner` | Reassign sequence owner (requires Play Admin) |

### List Sequences

Returns a paginated list of sequences in your workspace with summary statistics.

```
GET /api/v1/sequences
```

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
| `Owner` | string | Sequence owner name |
| `OwnerId` | uuid | Sequence owner UUID |
| `IsEnabled` | boolean | Whether currently active |
| `ActivePeople` | integer | People currently active in the sequence |
| `NeedsApproval` | integer | Tasks waiting for approval |
| `RunningTasks` | integer | Currently running tasks |
| `steps_exist` | boolean | Whether sequence has at least one step |
| `TotalCount` | integer | Total matching sequences (for pagination) |
| `UpdatedAt` | datetime | Last updated timestamp |

### Activate / Deactivate a Sequence

Sequences must be **active** to enroll people, and **inactive** to modify steps.

```
POST /api/v1/sequence/:id/activate
POST /api/v1/sequence/:id/deactivate
```

Both endpoints are idempotent — calling activate on an already-active sequence (or deactivate on an already-inactive one) returns `200` without error.

**Activate error responses:**

| Status | Meaning |
|--------|---------|
| `400` | Sequence has no steps, missing required field, or incomplete email content |
| `428` | Tasks are still updating from a previous change — retry after a few seconds |

### Get Metrics for a Sequence

Returns per-step performance metrics for a sequence (aggregate counts — for the people behind the counts, use the Engagement API).

```
GET /api/v1/sequence/:id/metrics
```

**Query parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sortBy` | string | Sort field (default: step_name) |
| `sortOrder` | string | asc or desc (default: asc) |
| `startDate` | string | ISO 8601 datetime filter start |
| `endDate` | string | ISO 8601 datetime filter end |

**Response:** Three top-level keys:

| Field | Type | Description |
|-------|------|-------------|
| `activity` | array | Per-step activity metrics |
| `pending` | array | Per-step pending task counts |
| `duration` | integer | Estimated sequence duration in days |

**Activity object fields:** `step_id`, `step_name`, `step_type`, `added_to_sequence`, `email_send`, `email_open`, `email_reply`, `email_click`, `email_bounce`, `li_message_send`, `li_connection_send`, `li_connection_accepted`, `call_logged`

### Add People to a Sequence

Adds people to an active sequence. Duplicates are automatically excluded.

```
POST /api/v1/sequence/:id/add-people
```

**Path parameters:** `id` (uuid) — Sequence UUID (must be enabled)

**Query parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `can_enrich_missing_data` | boolean | Optional, default `false`. If `true`, the server will *attempt* to enrich a missing email/LinkedIn URL from whatever contact info the person already has before enrolling them — not guaranteed to find it. **Always set this to `true`** — otherwise people missing the field a step needs get silently left with errored tasks. |

**Request body:**

| Field | Type | Description |
|-------|------|-------------|
| `people_ids` | uuid[] | Person UUIDs to add |
| `excluded_people_ids` | uuid[] | Optional. UUIDs to exclude |
| `filter` | object | Optional. Dynamic people filter |
| `step_id` | uuid | Optional. Step to add at (default: first) |
| `list_id` | uuid | Optional. Scope to list members |
| `search_term` | string | Optional. Free-text search |
| `select_all` | boolean | Optional. Select all matching people |

**Response:**

| Field | Type | Description |
|-------|------|-------------|
| `new_people` | uuid[] | Successfully added UUIDs |
| `duplicates` | uuid[] | Already-in-sequence UUIDs (skipped) |

**Error responses:** `400` — Invalid ID or body. `404` — Sequence not found or not enabled.

### Remove People from a Sequence

Removes people from a sequence, ending their pending tasks.

```
POST /api/v1/sequence/:id/remove-people
```

**Path parameters:** `id` (uuid) — Sequence UUID

**Request body:**

| Field | Type | Description |
|-------|------|-------------|
| `people_ids` | uuid[] | Person UUIDs to remove |
| `excluded_people_ids` | uuid[] | Optional. UUIDs to keep even if matched by the other criteria |
| `filter` | object | Optional. Dynamic people filter |
| `search_term` | string | Optional. Free-text search |
| `select_all` | boolean | Optional. Select all matching people in the sequence |
| `task_status` | string | Optional. With `select_all: true`, select people by their task status in the sequence |
| `step_id` | uuid | Optional. With `task_status`, scope the status match to one step |

**Response:** `200` with empty body on success.

**Error responses:** `400` — Invalid ID or body.

### Assign Sequence Owner

Reassigns a sequence to a different user in your workspace. The sequence's tasks and emails are reassigned to the new owner in the same operation. Requires the API key's user to be a Play Admin.

```
POST /api/v1/sequence/:id/assign-owner
```

**Request body:**

| Field | Type | Description |
|-------|------|-------------|
| `assign_to_user_id` | uuid | New owner's user UUID (must belong to your workspace) |
| `can_reassign_people` | boolean | Optional. If people in the sequence are owned by someone other than the new owner, `true` reassigns those people too; `false` (default) makes the request fail with `403 needs to reassign people` |

**Resolving the user UUID:** when the target is the caller themselves ("assign it to me"), call `GET /api/v1/me` — it works with any key and returns the key's user `id`. For any other user, call `GET /api/v1/users` (requires Admin) and match on `name` or `email`. If exactly one user matches, use their `id`. If zero or several match, ask the user to clarify rather than guessing — this operation reassigns live tasks and emails. If `GET /api/v1/users` returns `401` (the API key lacks Admin — check `is_admin` on `/api/v1/me` first), fall back to the `Owner`/`OwnerId` fields of `GET /api/v1/sequences`, or ask the user for the UUID.

**Response:** `200` with empty body on success.

**Error responses:** `400` — Invalid ID or body, sequence not found, or user not in workspace. `403` — API key's user is not a Play Admin, or people need reassignment and `can_reassign_people` is false.

---

## Engagement API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/engagement/people` | List people by sequence engagement (who opened, replied, clicked, ...) |

Returns the **people** behind sequence metrics — e.g. "everyone who opened an email from a sequence I own". Where `GET /api/v1/sequence/:id/metrics` returns aggregate per-step counts, this endpoint returns one row per person, with their engagement counts across all metrics.

**Access model:** any API key in the workspace can query engagement for any owner (including `owner_id=all` for workspace-wide results). This deliberately matches the sequence metrics endpoints — the workspace is the security boundary — but note it returns person-level data, not aggregates.

```
GET /api/v1/engagement/people?metric=open
```

**Query parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `metric` | string | **Required.** One or more metric names, comma-separated with OR semantics — `metric=open,click,reply` returns people who did *any* of those. Unknown values return `400` listing the valid names. |
| `owner_id` | string | Scope to sequences owned by one user: a user UUID, `me` (the API key's user), or `all` (no owner filter). **Default: `me`** when `sequence_id` is absent; no owner filter when `sequence_id` is given. |
| `sequence_id` | uuid | Scope to a single sequence. `404` if not found in your workspace. |
| `startDate` | string | `YYYY-MM-DD` or `YYYY-MM-DDTHH:MM:SS.mmmZ`. Default: beginning of time. |
| `endDate` | string | Same formats. Default: now. The range is **half-open** (`>= startDate`, `< endDate`), and a date-only `endDate` means *through the end of that day* — `endDate=2026-07-01` includes all of July 1. |

**Metric values:**

| Metric | Meaning |
|--------|---------|
| `open` | Opened an email. Bot-filtered server-side (scanner/proxy opens are excluded) and deduped per email — don't re-filter. |
| `click` | Clicked a link or attachment in an email. Deduped per email. |
| `reply` | Replied to an email |
| `bounce` | An email to them bounced |
| `send` | Was sent an email |
| `li-reply` | Replied on LinkedIn (message reply or reply received) |
| `call` | Has a logged phone call |

Only activity attached to a sequence counts — activity logged outside any sequence (e.g. a manually logged call) is not included.

**Headers:**

| Header | Required | Description |
|--------|----------|-------------|
| `X-Tiga-Auth` | Yes | Your API key |
| `Tiga-Pagination` | No | JSON: `page` (default 1), `page_size` (default 100, max 1000), `sort_by`, `sort_order` |

`sort_by` accepts `last_matched_at` (default, `desc`), `person_name`, or any count field (`email_open_count`, `email_click_count`, `email_reply_count`, `email_send_count`, `email_bounce_count`, `li_reply_count`, `call_count`).

**Response** — `{"rows": [...], "total_count": N}`. Every row includes all metric counts regardless of which `metric` you filtered by; `last_matched_at` is the most recent activity *of the requested metric(s)*:

```json
{
  "rows": [
    {
      "person_id": "b3f1...",
      "person_name": "Ada Lovelace",
      "person_email": "ada@example.com",
      "title": "VP Engineering",
      "account_id": "97c2...",
      "account_name": "Analytical Engines Inc",
      "email_send_count": 3,
      "email_open_count": 2,
      "email_click_count": 1,
      "email_reply_count": 1,
      "email_bounce_count": 0,
      "li_reply_count": 0,
      "call_count": 0,
      "last_matched_at": "2026-07-01T14:22:03Z"
    }
  ],
  "total_count": 128
}
```

`account_id`/`account_name` are `null`/`""` when the person has no account.

**Example — everyone who opened an email from any sequence I own, this quarter:**
```bash
curl -X GET "https://app.tigalabs.com/api/v1/engagement/people?metric=open&startDate=2026-07-01" \
  -H "X-Tiga-Auth: YOUR_API_KEY" \
  -H "Tiga-Pagination: {\"page\":1,\"page_size\":100}"
```

**Error responses:** `400` — missing/unknown `metric`, invalid `owner_id`/`sequence_id`/date, invalid pagination or sort. `404` — `sequence_id` not found in your workspace.

---

## Lists API (extract — materializing engagement results)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/lists` | Create list |
| POST | `/api/v1/lists/:id/add-members` | Add members to list |

**Create list body** (person list for engagement results):
```json
{
  "list": {
    "name": "Opened — my sequences — July",
    "object_type": "person"
  }
}
```

**Add members body** (`POST /api/v1/lists/:id/add-members`):
```json
{
  "object_ids": ["uuid1", "uuid2"]
}
```

> **Request body validation:** This API route rejects unknown fields. To add explicit records, provide `object_ids` as a non-empty array; do not use `member_ids`. After calling this endpoint, verify membership with `GET /api/v1/people` using `Tiga-Filter: {"list_id":"<id>"}`; `total_count` should be > 0 before handing off to signals or sequences.
