# Tiga API Reference — Signals Subset

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

## Accounts API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/account/:id` | Get single account |

---

## People API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/people` | List people (supports Tiga-Pagination, Tiga-Filter) |
| GET | `/api/v1/person/:id/signals` | Get AI signal values for a person |

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
| POST | `/api/v1/lists` | Create list |
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

**Run signals body** (`POST /api/v1/lists/:id/run-all-signal`):
```json
{
  "signal_ids": ["uuid1", "uuid2"]
}
```
Signal IDs optional; uses list's saved configuration if omitted. Jobs queue asynchronously.

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

**Status values:**
- `0` — Not computed yet
- `1` — Done (success)
- `2` — Failed
- `3` — N/A (signal not applicable to this record)

---

## Signals API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/signals` | List signals |
| GET | `/api/v1/signal/:id` | Get single signal |
| POST | `/api/v1/signal` | Create signal |
| PUT | `/api/v1/signal/:id` | Update signal |
| DELETE | `/api/v1/signal/:id` | Delete signal |

> **Note:** The synchronous per-record run endpoint (`POST /api/v1/signal/:id/run-signal`) is documented in `references/running-signals.md`, not here.

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
