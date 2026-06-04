---
name: run-signal
description: "Run an existing signal against one or more people or accounts in real time using the Tiga API. Use this skill by default whenever the user wants to run a signal — unless the list has more than 250 records, in which case use bulk-signals instead. Triggers on phrases like 'run this signal on Jane', 'check these companies against the signal', 'research this account', or any signal run on a small-to-medium list (up to 250 records)."
---

# Run Signal Skill

Run an existing signal against one or more people or accounts synchronously — no list infrastructure or polling required.

**Scale guidance:**
- **This skill (run-signal):** up to 250 records — call the endpoint once per record
- **bulk-signals:** more than 250 records — use the list + poll workflow instead

**Before starting:** You need a signal ID. If the signal doesn't exist yet, use the **signal-crud** skill to create one first.

---

## Run for a person (email or LinkedIn URL)

```bash
curl -X POST "https://app.tigalabs.com/api/v1/signal/<signal-id>/run-signal" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "person": {
      "email": "jane@acme.com",
      "linkedin": "https://www.linkedin.com/in/jane-doe"
    }
  }'
```

At least one of `email` or `linkedin` is required. Both can be provided — the lookup uses whichever matches first.

**Response:**
```json
{
  "person": {
    "id": "<person-id>",
    "custom_columns": {
      "<signal-id>": {
        "custom_column_id": "<signal-id>",
        "type": "text",
        "label": "Changed Jobs in Past Year",
        "value": "<b>2025-07-01</b> - Jane Doe started role: \"<b>Head of Demand Generation</b>\" at Acme",
        "status": 1,
        "is_account_insight": false,
        "is_computed_column": true
      }
    }
  }
}
```

The signal result lives at `person.custom_columns[<signal-id>]`. Read `status` before using `value`:

| Status | Constant | Meaning |
|--------|----------|---------|
| `1` | `SUCCESS` | Signal ran and returned a result — read `value` |
| `2` | `NOT_FOUND` | Signal ran but no matching data was found |
| `3` | `MISSING_DEPENDENCIES` | Required inputs (email, LinkedIn, etc.) were absent |
| `4` | `FAILED` | Signal execution errored |
| `5` | `PRECONDITION_FAILED` | A precondition check blocked execution |

---

## Run for an account (domain or LinkedIn URL)

```bash
curl -X POST "https://app.tigalabs.com/api/v1/signal/<signal-id>/run-signal" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "account": {
      "domain": "acme.com",
      "linkedin": "https://www.linkedin.com/company/acme"
    }
  }'
```

At least one of `domain` or `linkedin` is required. Domains are normalized automatically (scheme, path, and port are stripped).

**Response:**
```json
{
  "account": {
    "id": "<account-id>",
    "custom_columns": {
      "<signal-id>": {
        "custom_column_id": "<signal-id>",
        "type": "text",
        "label": "Recently Raised Funding",
        "value": "Acme raised a $20M Series B in March 2025",
        "status": 1,
        "is_account_insight": true,
        "is_computed_column": true
      }
    }
  }
}
```

The signal result lives at `account.custom_columns[<signal-id>]`. See the status table in the person section above.

---

## Behavior notes

- **Find-or-create:** If no matching person/account exists in your org, one is created automatically before the signal runs.
- **Synchronous:** The call blocks until the signal finishes — no polling required.
- **Always reruns:** Results are never served from cache. The signal always executes fresh regardless of prior results.
- **Signal type determines the input:** The signal's `is_account_insight` flag (set at creation time) controls whether you must supply `person` or `account` — you cannot override this per call.

---

**Related skills:** Use **signal-crud** to create the signal. For lists over 250 records, use **bulk-signals** instead. Use **contact-discovery** to find the person's details before running.

**Important:** You should always save person or account's tiga ID. Which will be useful for calling future tools and actions.