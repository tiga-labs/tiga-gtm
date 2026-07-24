# Commit a Built List to Tiga — Bulk Import (accounts + people)

Once a list is built into a local CSV (Workflows 1, 3, 5), the fastest way to commit it to Tiga is the bulk import endpoint. It takes a flat list of records, splits each row into an account and/or a person, de-dupes against existing data, optionally adds them to a list, and returns an `import_history_id`. It is **synchronous** — the response reflects exactly what was written, per row.

**Prefer this over per-record creation.** Most list-building workflows end with a local CSV. Committing it with one bulk call is simpler and safer than looping `POST /api/v1/account` / `POST /api/v1/people`:

- **No 409 handling.** Existing accounts/people are **upserted** — matched by domain/company-linkedin (accounts) or email/linkedin (people), and their non-empty incoming fields are merged in. You don't manage duplicates yourself.
- **One row → account + person.** Each row is split and the person is linked to its account automatically.
- **Custom columns, lists, and audit in one shot.** Set `custom_columns`, add everything to a named list, and get back an `import_history_id` that ties every imported object together.

The per-record path (`references/api-reference.md` → Accounts/People/Lists, and the "Commit to Tiga" follow-up) still works and is fine for one-off or highly granular commits — but for committing a CSV, reach for bulk import first.

**Not for:** enrichment (if rows lack emails/phones and you want them verified, run waterfall enrich — it also creates the people), or LinkedIn post reactors (use `references/import-post-reactions.md`).

## Requirements per row

- A **person** is identified by `email` **or** `linkedin_url`.
- An **account** is identified by `website`, `domain`, **or** `company_linkedin`.
- Every row must identify at least one. Descriptive-only fields (`first_name`, `account_name`, …) don't identify an entity on their own.

Max **5000** records per request — chunk larger files into separate calls.

## Workflow

1. **Map your CSV columns to the flat record shape** (fields below). A row can carry person fields, account fields, or both.
2. **Preflight (recommended).** `POST /api/v1/import/preflight` validates every row and reports, per row, whether it's importable and whether the person/account already exist — **no writes**. Fix anything it flags before committing.
3. **Upload.** `POST /api/v1/import/upload` creates/updates the records. Read the per-row `records` in the response to confirm what happened; `summary` gives the counts.
4. **Verify.** `GET /api/v1/people` or `GET /api/v1/accounts` with `Tiga-Filter: {"list_id":"<id>"}` — `total_count` should be > 0 before handing off to signals or sequences.

## Endpoint spec — POST /api/v1/import/preflight

Headers: `X-Tiga-Auth: <key>`, `Content-Type: application/json`.

Body: `{ "records": [ {…flat record…} ] }`. Returns `200` with a `summary` (counts of valid/invalid, new/existing) and a per-row `records` array — each entry has `valid`, the `person`/`account` `{present, valid, exists}` state, and any `errors`. Writes nothing.

## Endpoint spec — POST /api/v1/import/upload

Headers: `X-Tiga-Auth: <key>`, `Content-Type: application/json`.

Top-level body fields:

| Field | Type | Required | Description |
|---|---|---|---|
| `records` | array | yes | The rows to import (max 5000). |
| `list_id` | uuid | no | Add imported records to this existing list; only objects matching the list's object type are added. `404` if not found. |
| `list_name` | string | no | Create a new list with this name and add matching records. The list is typed by the import's contents (accounts-only → account list, otherwise person). Ignored when `list_id` is set. |
| `import_history_id` | uuid | no | Append to an existing import history; a new one is created when omitted. |
| `source_name` | string | no | Label for the import history. Defaults to `"API Import"`. |

**Record fields (flat)** — all optional except the identity requirement above:

- **Person:** `email`, `linkedin_url`, `first_name`, `last_name`, `title`, `phone`, `mobile_phone`, `secondary_email`, `person_city`, `person_state`, `person_country`, `work_city`, `work_state`, `work_country`
- **Account:** `website`, `domain`, `company_linkedin`, `account_name`, `account_industry`, `estimated_num_employees`, `account_street`, `account_city`, `account_region`, `account_postal`, `account_country`, `account_phone`
- **`custom_columns`:** an object mapping a custom column's **key** to its value (string/number/boolean). Each column's object type routes the value to the person or the account. Computed signals can't be set. Discover keys via `GET /api/v1/person/columns` and `GET /api/v1/account/columns`.

Example:

```bash
curl -sS -X POST "$TIGA_BASE/api/v1/import/upload" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "list_name": "Q3 ICP targets",
    "records": [
      {
        "email": "jane@acme.com",
        "first_name": "Jane",
        "last_name": "Doe",
        "title": "VP Sales",
        "account_name": "Acme",
        "website": "acme.com",
        "custom_columns": { "persona": "Champion", "lead_score": 87 }
      }
    ]
  }'
```

Response (`201`):

```json
{
  "import_history_id": "06b87362-8111-430c-994d-c5780211f19f",
  "list_id": "2f1c…",
  "summary": {
    "total": 1,
    "accounts_created": 1, "accounts_updated": 0,
    "people_created": 1, "people_updated": 0,
    "skipped": 0, "errors": 0
  },
  "records": [
    { "index": 0, "status": "ok",
      "person_id": "a1b2…", "person_status": "created",
      "account_id": "c3d4…", "account_status": "created" }
  ]
}
```

Per-row: `status` is `ok` or `error`; successful rows carry `person_status`/`account_status` of `created` or `updated`; error rows carry an `errors` array naming the offending field.

**Partial success:** invalid rows are skipped and reported per-row (`summary.skipped`) — the valid rows still import. Run preflight first to catch these before committing.

**Import history:** every imported person and account is associated with the returned `import_history_id`, so the whole commit is auditable/filterable afterward — including accounts that don't match a named list's type.

Errors: `400` malformed/empty/oversized body, or **no valid records** (the body includes the per-row validation so you can fix and resubmit); `401` bad API key; `404` unknown `list_id`/`import_history_id`.

## API basics

- **Base URL** is environment-specific. Production is `https://app.tigalabs.com`; honor whatever host the user gives you (read from `TIGA_BASE`).
- **Auth** is the `X-Tiga-Auth: $TIGA_API_KEY` header on every request. Never hardcode the key.

The list created here is a normal Tiga list, so downstream skills compose directly: `signals` to score, `sequence-runner` to enroll in a sequence, `crm-ops` to sync.
