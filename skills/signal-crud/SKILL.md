---
name: signal-crud
description: "Manage signal definitions using the Tiga API — create, read, update, configure, and delete signals. Use this skill when the user wants to set up a new signal, view or list existing signals, change a signal's configuration (prompt, type, settings), or delete a signal. Triggers on phrases like 'create a signal', 'show me my signals', 'update this signal', 'change the signal config', 'delete this signal', or 'what signals do I have?'. Note: to run a signal against a list of up to 250 records, use run-signal instead. For lists over 250, use bulk-signals instead."
---

# Signal CRUD Skill

Create, read, update, and delete signal definitions in Tiga.

**Before starting:** Read `tiga-gtm/skills/signal-crud/references/signal-types.md` for the type index and shared fields. For the specific signal type the user wants, read the corresponding `references/type-<name>.md` file.

**Base URL:** `https://app.tigalabs.com`
**Auth:** `X-Tiga-Auth: $TIGA_API_KEY` on every request.

**Related skills:**
- **run-signal** — run a signal on up to 250 people or accounts
- **bulk-signals** — run signals on large lists (250+ records)

---

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
  ...
]
```

---

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

---

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

> Before building `computed_config`, see the **Signal Type Reference Docs** section below.

**Response:** `200 OK` — the created signal object. Save the `id` — required for running, updating, and deleting.

After a successful create, output to the user:

Show the user the newly created signal:

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

---

## Update a Signal

```bash
PUT /api/v1/signal/:id
```

**Writable fields:** `label`, `computed_config`, `can_trigger_play`, `is_user_signal`

> `is_user_signal` requires Signal Admin role.

1. `GET /api/v1/signal/:id` to fetch the current config.
2. Read the reference doc for the signal's type — see **Signal Type Reference Docs** below.
3. Send the full updated `computed_config` — partial patches are not supported.

```json
{
  "label": "Updated Label",
  "computed_config": { ... }
}
```

**Response:** `200 OK` — empty body.

---

## Delete a Signal

```bash
DELETE /api/v1/signal/:id
```

> Deleting removes the signal from all lists it was attached to. Confirm with the user before proceeding.

**Response:** `204 No Content` — empty body.

---

## Signal Type Reference Docs

Each `computed_config.type` has its own reference file with required fields, optional fields, and an example. Read the relevant file before building or updating a `computed_config`.

| `computed_config.type` | Reference |
|------------------------|-----------|
| `gpt` | `tiga-gtm/skills/signal-crud/references/type-gpt.md` |
| `hiring_for_role` | `tiga-gtm/skills/signal-crud/references/type-hiring-for-role.md` |
| `linkedin_posts` | `tiga-gtm/skills/signal-crud/references/type-linkedin-posts.md` |
| `hired_executive` | `tiga-gtm/skills/signal-crud/references/type-hired-executive.md` |
| `sec_document` | `tiga-gtm/skills/signal-crud/references/type-sec-document.md` |
| `role_departure` | `tiga-gtm/skills/signal-crud/references/type-role-departure.md` |
| `started_new_role` | `tiga-gtm/skills/signal-crud/references/type-started-new-role.md` |
| `search` | `tiga-gtm/skills/signal-crud/references/type-search.md` |
| `technographics` | `tiga-gtm/skills/signal-crud/references/type-technographics.md` |

---

## Discover Merge Fields

Find available `{{.FieldName}}` variables for use in `gpt` signal prompts:

```bash
GET /api/v1/account/columns?mode=merge_fields
GET /api/v1/person/columns?mode=merge_fields
```
