# Running Signals: Full Payloads and Scoring Workflows

Auth: `X-Tiga-Auth: $TIGA_API_KEY` on every request.

## Synchronous run — full request/response

### Run for a person (email or LinkedIn URL)

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

### Run for an account (domain or LinkedIn URL)

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

Read `status` before using `value` — see the status table (1-5) in the signals SKILL.md.

## Workflow: Stacked Signals for Scoring

**Use when:** You want to score and prioritize accounts based on multiple signals firing simultaneously (e.g., funding AND hiring AND tech adoption = hot account).

1. **Define your signal stack** — Choose 2-5 signals that together indicate high buying intent. Examples:
   - Raised funding in last 90 days
   - Actively hiring for a relevant role
   - Using a competitor's product (technographic)
   - Company headcount growing >20% YoY
   - Recent executive hire in a relevant function

2. **Create all signals** — One `POST /api/v1/signal` per signal. Collect all signal IDs. For specialized signal types, use `"type"` values: `"hiring_for_role"` (hiring), `"technographics"` (tech stack), `"started_new_role"` / `"role_departure"` (people movement).

3. **Create a list with all signals attached:**
```bash
curl -X POST "https://app.tigalabs.com/api/v1/lists" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "list": {
      "name": "Stacked Signal List - 2026-03-20",
      "object_type": "account",
      "list_signals": {
        "<signal-id-1>": true,
        "<signal-id-2>": true,
        "<signal-id-3>": true
      }
    },
    "run_signals_config": {
      "signal_ids": ["<signal-id-1>", "<signal-id-2>", "<signal-id-3>"]
    }
  }'
```

4. **Poll all signals to completion** — Use `POST /api/v1/lists-signal/bulk-status` with all signal IDs. Wait until all statuses are non-zero (1=done, 2=failed, 3=N/A). Poll every 5-10 seconds.

5. **Score accounts** — Read signal values for each account. Assign 1 point per "yes" signal. Accounts with score ≥ N (e.g., 2 of 3) are prioritized.

6. **Create a priority sub-list** — Move high-scoring accounts to a new `"Priority TAL - <date>"` list via `POST /api/v1/lists` and `POST /api/v1/lists/:id/add-members`.

## Workflow: Multi-Dimensional Account Scoring

**Use when:** You need comprehensive account scoring across multiple dimensions (e.g., ICP fit + buying intent + engagement + timing).

1. **Define scoring dimensions** — Create 3-5 signals across different categories:
   - **ICP Fit**: Does the account match firmographic criteria?
   - **Buying Intent**: Recent funding, hiring signals, tech evaluation
   - **Timing**: Fiscal year end, contract renewal season
   - **Engagement**: Recent website visits, content downloads
   - **Competitive**: Currently using a competitor product

2. **Create signals for each dimension** — Use `POST /api/v1/signal` for each. Design prompts that return structured answers (yes/no with detail) for easy parsing.

   Example ICP Fit signal:
```json
{
  "label": "ICP Fit Score",
  "is_computed_column": true,
  "type": "text",
  "computed_config": {
    "type": "gpt",
    "prompt": "Evaluate {{.AccountName}} ({{.AccountWebsite}}) against this ICP: [describe ICP]. Rate as Strong Fit, Moderate Fit, or Weak Fit. Explain in one sentence.",
    "is_account_insight": true,
    "can_use_web_search": true,
    "word_limit": 60
  }
}
```

3. **Run all signals on the list** — `POST /api/v1/lists/:id/run-all-signal` with all signal IDs.

4. **Poll to completion** and read results.

5. **Tier accounts** — Based on composite scores:
   - **Tier 1** (3+ strong signals): Immediate outreach
   - **Tier 2** (2 strong signals): Nurture sequence
   - **Tier 3** (0-1 strong signals): Monitor

6. **Create tiered sub-lists** — One list per tier for different outreach strategies.
