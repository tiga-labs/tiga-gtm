# Tiga API Reference

## Authentication & Headers

**Base URL:** `https://app.tigalabs.com`

**Required auth header (all endpoints):**
```
X-Tiga-Auth: YOUR_API_KEY
Content-Type: application/json
```

Store the key in an env var: `export TIGA_API_KEY="your_key_here"`

**Pagination header** (REQUIRED for paginated list endpoints like `GET /api/v1/accounts` and `GET /api/v1/people`):
```
Tiga-Pagination: {"page": 1, "page_size": 100, "sort_by": "name", "sort_order": "asc"}
```
**IMPORTANT:** Query parameters (`?page=2&per_page=100`) do NOT work for pagination. You MUST use the `Tiga-Pagination` header with JSON. Without this header, the API always returns only the first page of results regardless of query params. Increment `"page"` to paginate through results. Use `total_count` from the response to know when to stop.

**Filter header** (optional, on list endpoints):
```json
Tiga-Filter: {"search_term": "acme", "list_id": "uuid", "sequence_id": "uuid", "filter": []}
```

---

## Accounts API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/accounts` | List accounts (supports Tiga-Pagination, Tiga-Filter) |
| POST | `/api/v1/account` | Create account |
| GET | `/api/v1/account/:id` | Get single account (includes `custom_columns` with signal values) |
| PUT | `/api/v1/account/:id` | Update account |
| DELETE | `/api/v1/accounts` | Bulk delete (requires People Admin) |

**Create account body:**
```json
{
  "name": "Acme Corp",
  "domain": "acme.com",
  "linkedin_url": "https://www.linkedin.com/company/acme"
}
```
- `domain` and `linkedin_url` must be unique — returns `409 Conflict` (plain text body, not JSON) if duplicate.
- The 409 body is a string like: `Account with LinkedIn URL "..." already owned by <user>`. It does NOT contain the existing account's ID.
- **To resolve existing account IDs:** Pre-fetch all accounts using `GET /api/v1/accounts` with `Tiga-Pagination` header and build a lookup map (by normalized LinkedIn URL and lowercase name) BEFORE creating accounts. Match CSV rows against the lookup map first, and only call `POST /api/v1/account` for unmatched rows.
- **Set the `website` field** when creating or updating accounts if your signals use `{{.AccountWebsite}}` in prompts. The `domain` field does NOT satisfy the `AccountWebsite` merge field — you must explicitly set `website` via `PUT /api/v1/account/:id` with `{"website": "https://example.com"}`.

**Delete accounts body:**
```json
{
  "account_ids": ["uuid1", "uuid2"],
  "select_all": false,
  "excluded_account_ids": []
}
```

---

## People API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/people` | List people (supports Tiga-Pagination, Tiga-Filter) |
| POST | `/api/v1/people` | Create person |
| PUT | `/api/v1/person/:id` | Update person |
| DELETE | `/api/v1/person/:id` | Delete person |
| GET | `/api/v1/person/:id/signals` | Get AI signal values for a person |
| GET | `/api/v1/person/:id/li-fact` | Get scraped LinkedIn profile data |

**Create person body:**
```json
{
  "first_name": "Jane",
  "last_name": "Smith",
  "email_address": "jane@acme.com",
  "title": "VP of Sales",
  "person_linkedin": "https://www.linkedin.com/in/janesmith",
  "account_name": "Acme Corp",
  "website": "acme.com",
  "phone": "+14155550100"
}
```

**Filter by list** (via Tiga-Filter header):
```json
Tiga-Filter: {"list_id": "list-uuid"}
```

**LinkedIn profile data** (`GET /api/v1/person/:id/li-fact`):
- Query param: `shouldFetchIfNotFound=true` triggers a live fetch from LinkedIn (consumes credits)
- Returns `204 No Content` if unavailable
- Response includes: name, headline, about, experience, education, skills, interests, recommendations, posts, location, LinkedIn ID, promotion dates, role change indicators

**Signals response** (`GET /api/v1/person/:id/signals`):
```json
[
  {
    "category": "signal-label",
    "insight": "computed text value",
    "insight_event_date": "2026-03-01T00:00:00Z",
    "not_found": false,
    "insight_data": {},
    "insight_source": "web"
  }
]
```

---

## Lists API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/lists` | List all lists (filter: `?object_type=person\|account`) |
| GET | `/api/v1/lists/:id` | Get single list |
| POST | `/api/v1/lists` | Create list |
| PUT | `/api/v1/lists/:id` | Update list |
| DELETE | `/api/v1/lists/` | Bulk delete lists |
| POST | `/api/v1/lists/:id/add-members` | Add members to list |
| POST | `/api/v1/lists/:id/run-all-signal` | Trigger signal computation for list |
| POST | `/api/v1/lists/:id/stop-all-signal` | Cancel running signals |
| POST | `/api/v1/lists-signal/bulk-status` | Check signal compute status |

**Create list body:**
```json
{
  "list": {
    "name": "Q2 Target Accounts",
    "object_type": "account",
    "list_signals": {
      "<signal_id>": true
    }
  },
  "run_signals_config": {
    "signal_ids": ["signal-uuid-1", "signal-uuid-2"]
  }
}
```
Optional fields: `object_ids`, `excluded_object_ids`, `filter`, `from_list_id`, `search_term`, `select_all`.

**Add members body** (`POST /api/v1/lists/:id/add-members`):
```json
{
  "object_ids": ["uuid1", "uuid2"],
  "excluded_object_ids": ["uuid3"],
  "filter": {},
  "from_list_id": "uuid",
  "search_term": "string",
  "select_all": false
}
```

**Attach signals to existing list** (`PUT /api/v1/lists/:id`):
```json
{
  "list": {
    "name": "List Name",
    "list_signals": {
      "<signal-id-1>": true,
      "<signal-id-2>": true
    }
  }
}
```
**Note:** The `name` field is required in the PUT body even if you're only updating `list_signals`.

**Run signals body** (`POST /api/v1/lists/:id/run-all-signal`):
```json
{
  "signal_ids": ["uuid1", "uuid2"]
}
```
Signal IDs optional; uses list's saved configuration if omitted. Jobs queue asynchronously. **Response is plain text `OK` (status 200), not JSON.** Signals that already have terminal results (status 1, 2, or 3) are NOT re-computed — delete and recreate the signal for fresh results.

**Bulk status request** (check if signals are done):
```json
POST /api/v1/lists-signal/bulk-status
{
  "signal_ids": ["signal-uuid-1"],
  "account_ids": ["account-uuid-1", "account-uuid-2"],
  "list_id": "list-uuid"
}
```
Use `people_ids` instead of `account_ids` for person lists (not both).

**Bulk status response shape:** See `async-patterns.md` for the full response. Key: `signal_status_map[account_id][signal_id].status` (note: account first, then signal).

**Status values:**
- `0` — Not computed yet
- `1` — Done (success) — result in `.value`
- `2` — Failed
- `3` — N/A (missing merge field dependency, check `dependencies_missing` array)

---

## Signals API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/signals` | List signals (returns JSON array, not object) |
| GET | `/api/v1/signal/:id` | Get single signal |
| POST | `/api/v1/signal` | Create signal |
| PUT | `/api/v1/signal/:id` | Update signal |
| DELETE | `/api/v1/signal/:id` | Delete signal |

**List query params:**
- `is_computed_column=true` — AI-computed signals only
- `account_columns_only=true` — Account signals only
- `person_columns_only=true` — Person signals only

**Create signal body:**
```json
{
  "label": "Recent Funding News",
  "is_computed_column": true,
  "type": "text",
  "computed_config": {
    "type": "gpt",
    "prompt": "Has {{.AccountName}} raised funding in the last 90 days? Answer yes or no with a brief reason.",
    "is_account_insight": true,
    "can_use_web_search": true,
    "expiration_in_days": 90,
    "temperature": 0.4,
    "word_limit": 50
  }
}
```

**Signal `type` field:** `"text"` (default) or `"picklist"`

**`computed_config` object — full schema:**

Core fields:
- `type` (string) — `gpt`, `hiring_for_role`, `sec_document`, `linkedin_posts`, `hired_executive`, `role_departure`, `started_new_role`, `search`, `technographics`
- `description` (string)
- `prompt` (string) — required for `gpt` type
- `is_account_insight` (boolean)
- `is_standard_insight` (boolean)
- `expiration_in_days` (integer, default: 30)
- `email_settings` (string) — `always_create`, `never_create`, `create_if_no_play`, `notification`
- `word_limit` (integer)
- `default_value` (string)
- `required_dependencies` (string[])

AI model fields (for `gpt` type):
- `model` (string) — auto-set on create
- `api` (string) — `Agentic` or `ChatCompletion`
- `temperature` (float, 0.0–1.0, default: 0.4)
- `max_tokens` (integer, default: 4048)
- `frequency_penalty` (float, 0.0–2.0)
- `can_use_web_search` (boolean)
- `advanced_model_verify` (boolean)
- `should_classify_output_as_bool` (boolean)
- `response_type` (string) — `word`, `sentence`, `paragraph`, `full`
- `few_shot_examples` (string)
- `recompute_on_dependencies` (string[])

Precondition fields:
- `has_precondition` (boolean)
- `precondition.asset_type` (string)
- `precondition.property` (string)
- `precondition.property_type` (string)
- `precondition.operator` (string)
- `precondition.value` (string)

**Update signal writable fields:** `label`, `computed_config`, `can_trigger_play`, `is_user_signal` (requires Signal Admin)

**Custom merge fields:** Discover via `GET /api/v1/account/columns?mode=merge_fields` or `GET /api/v1/person/columns?mode=merge_fields`

---

## Waterfall Enrich API (async)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/people/enrich-person` | Submit enrichment job → returns `enrich_id` |
| GET | `/api/v1/enrich/:id` | Poll enrichment status |

**Submit enrichment:**
```json
{
  "first_name": "Jane",
  "last_name": "Smith",
  "company_name": "Acme Corp",
  "domain": "acme.com",
  "person_linkedin_url": "https://www.linkedin.com/in/janesmith",
  "title": "VP of Sales",
  "company_linkedin_url": "https://www.linkedin.com/company/acme"
}
```
- `first_name`, `last_name`, `company_name` are required
- `person_linkedin_url` and `domain` significantly increase accuracy

**Poll response (running):**
```json
{"data_import_status": "Running", ...}
```

**Poll response (complete):**
```json
{
  "data_import_status": "Person And Account Created",
  "email_address": "jane@acme.com",
  "phone": "+14155550100",
  "person_id": "uuid",
  "account_name": "Acme Corp",
  "domain": "acme.com"
}
```

---

## Find People with Agent API (async)

This searches LinkedIn for new contacts.

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/agent/find-people` | Submit search → returns `status_id` |
| GET | `/api/agent/find-people/:id/status` | Poll for results |

**Submit search:**
```json
{
  "contact_description": "VP of Engineering at Series B SaaS companies with 50-200 employees in the US",
  "model": "gpt-5.4-2026-03-05"
}
```
Valid models: `gpt-5.4-2026-03-05`, `gpt-5.2-2025-12-11`, `gpt-5.1-2025-11-13`

**Poll response (complete):**
```json
{
  "status": "Complete",
  "created_flux_ids": ["uuid-1", "uuid-2"],
  "created_people": [
    {
      "first_name": "Jane",
      "last_name": "Smith",
      "title": "VP of Engineering",
      "account_name": "Acme Corp",
      "person_linkedin": "https://www.linkedin.com/in/janesmith"
    }
  ],
  "conversation": []
}
```

**Status values:** `"Running"` | `"Complete"` | `"Error - <reason>"`

---

## Data Endpoints (Third-Party Proxies)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/apollo-organization-search` | Search Apollo.io organization database |

**Apollo organization search body:**
```json
{
  "q_organization_name": "Acme Corp",
  "page": 1,
  "per_page": 10
}
```
Full Apollo request/response schema: https://docs.apollo.io/reference/organization-search

---

## Secrets Access API

Retrieve OAuth tokens for connected integrations. Tokens are auto-refreshed before return.

| Method | Path | Token scope |
|--------|------|-------------|
| GET | `/api/v1/current-user/microsoft-oauth-token` | User: Mail, Calendar |
| GET | `/api/v1/current-org/hubspot-oauth-token` | Org: CRM, sequences |
| GET | `/api/v1/current-org/salesforce-oauth-token` | Org: Full Salesforce REST |
| GET | `/api/v1/current-user/google-oauth-token` | User: Gmail, Calendar |

**Response:**
```json
{"access_token": "...", "expiry": "2026-03-17T12:00:00Z"}
```
If not connected: `{"message": "service account not connected"}`

---

## Sequences API

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

**Example request:**
```bash
curl -X GET "https://app.tigalabs.com/api/v1/sequences" \
  -H "X-Tiga-Auth: YOUR_API_KEY" \
  -H "Tiga-Pagination: {\"page\":1,\"page_size\":2,\"sort_by\":\"updated_at\",\"sort_order\":\"desc\"}"
```

### Get Metrics for a Sequence

Returns per-step performance metrics for a sequence.

```
GET /api/v1/sequence/:id/metrics
```

**Path parameters:** `id` (uuid) — Sequence UUID

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
