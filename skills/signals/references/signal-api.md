# Signal Definition API (CRUD)

Full request/response detail for managing signal definitions. Auth: `X-Tiga-Auth: $TIGA_API_KEY` on every request.

## List Signals

```bash
GET /api/v1/signals
```

**Query params:**
- `is_computed_column=true` — AI-computed signals only
- `account_columns_only=true` — account signals only
- `person_columns_only=true` — person signals only

**Response:** `200 OK` — array of signal objects

```json
[
  {
    "id": "a1b2c3d4-0000-0000-0000-000000000001",
    "org_id": "org-uuid",
    "label": "Recent Funding News",
    "key": "recent_funding_news",
    "type": "text",
    "object_type": "account",
    "is_computed_column": true,
    "is_user_signal": false,
    "can_trigger_play": false,
    "computed_config": { "type": "gpt", "..." : "..." },
    "updated_at": "2026-05-01T12:00:00Z",
    "updated_by": "Jane Smith"
  }
]
```

## Get a Signal

```bash
GET /api/v1/signal/:id
```

Always GET before updating — send the full updated `computed_config`, not a partial patch.

**Response:** `200 OK` — single signal object, same shape as list but with one additional field:

```json
{
  "id": "a1b2c3d4-0000-0000-0000-000000000001",
  "org_id": "org-uuid",
  "label": "Recent Funding News",
  "key": "recent_funding_news",
  "type": "text",
  "object_type": "account",
  "is_computed_column": true,
  "is_user_signal": false,
  "can_trigger_play": false,
  "computed_config": {
    "type": "gpt",
    "prompt": "Has {{.AccountName}} raised funding in the last 90 days?",
    "is_account_insight": true,
    "can_use_web_search": true,
    "expiration_in_days": 90,
    "temperature": 0.4,
    "word_limit": 50
  },
  "signal_sources": [],
  "updated_at": "2026-05-01T12:00:00Z",
  "updated_by": "Jane Smith",
  "owned_by": "Jane Smith"
}
```

> `owned_by` is only present on this endpoint — it's the display name of the user who owns the signal.

## Create a Signal

```bash
POST /api/v1/signal
```

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

- `type` — `"text"` (default) or `"picklist"`
- `is_computed_column` — always `true` for AI signals

> Before building `computed_config`, read `signal-types.md` and the relevant `type-*.md` file in this directory.

**Response:** `200 OK` — the created signal object. Save the `id` — required for running, updating, and deleting.

After a successful create, show the user the newly created signal:

**See signal here: https://app.tigalabs.com/app#/signal/:id/configure**

```json
{
  "id": "a1b2c3d4-0000-0000-0000-000000000001",
  "org_id": "org-uuid",
  "label": "Recent Funding News",
  "key": "recent_funding_news",
  "type": "text",
  "object_type": "account",
  "is_computed_column": true,
  "is_user_signal": false,
  "can_trigger_play": false,
  "computed_config": {
    "type": "gpt",
    "prompt": "Has {{.AccountName}} raised funding in the last 90 days? Answer yes or no with a brief reason.",
    "is_account_insight": true,
    "can_use_web_search": true,
    "expiration_in_days": 90,
    "temperature": 0.4,
    "word_limit": 50
  },
  "signal_sources": [],
  "updated_at": "2026-05-14T09:30:00Z",
  "updated_by": "Jane Smith"
}
```

## Update a Signal

```bash
PUT /api/v1/signal/:id
```

**Writable fields:** `label`, `computed_config`, `can_trigger_play`, `is_user_signal`

> `is_user_signal` requires Signal Admin role.

1. `GET /api/v1/signal/:id` to fetch the current config.
2. Read the reference doc for the signal's type (`type-*.md` in this directory).
3. Send the full updated `computed_config` — partial patches are not supported.

```json
{
  "label": "Updated Label",
  "computed_config": { ... }
}
```

**Response:** `200 OK` — empty body.

## Delete a Signal

```bash
DELETE /api/v1/signal/:id
```

> Deleting removes the signal from all lists it was attached to. Confirm with the user before proceeding.

**Response:** `204 No Content` — empty body.
