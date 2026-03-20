---
name: signals
description: Create, run, and score AI signals on Tiga lists. Use this skill when the user wants to define buying signals, run signal research on account or people lists, stack multiple signals for scoring, or build multi-dimensional account scoring models. Covers single signals, stacked signals, and composite scoring workflows.
---

# Signals Skill

Create and run AI-powered signals on Tiga lists to research, filter, and score accounts or people.

**Before starting:** Read `tiga-gtm/docs/api-reference.md` for endpoint details. Read `tiga-gtm/docs/merge-fields.md` for available template variables in signal prompts. Read `tiga-gtm/docs/async-patterns.md` for polling signal computation status.

**Base URL:** `https://app.tigalabs.com`
**Auth:** `X-Tiga-Auth: $TIGA_API_KEY`

---

## Workflow A: Single Signal on a List

**Use when:** You have a list of accounts or people and want to filter/score them based on one buying signal (e.g., recent funding, hiring for a role, tech adoption).

### Steps

1. **Get or create a Tiga list** with target accounts/people.
   - List existing: `GET /api/v1/lists?object_type=account`
   - Create new: `POST /api/v1/lists` with `{"list": {"name": "<name>", "object_type": "account"}}`

2. **Create the signal:**
```bash
curl -X POST "https://app.tigalabs.com/api/v1/signal" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "Raised Funding Last 90 Days",
    "is_computed_column": true,
    "type": "text",
    "computed_config": {
      "type": "gpt",
      "prompt": "Has {{.AccountName}} raised a funding round in the last 90 days (after {{.Last90Days}})? Answer yes or no with round size if known.",
      "is_account_insight": true,
      "can_use_web_search": true,
      "expiration_in_days": 90,
      "word_limit": 40
    }
  }'
```

   For specialized signal types, use `"type"` values:
   - `"hiring_for_role"` — hiring signals
   - `"technographics"` — tech stack signals
   - `"started_new_role"` / `"role_departure"` — people movement signals

3. **Run the signal on the list:**
```bash
curl -X POST "https://app.tigalabs.com/api/v1/lists/<list-id>/run-all-signal" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"signal_ids": ["<signal-id>"]}'
```

4. **Poll for completion:**
```bash
curl -X POST "https://app.tigalabs.com/api/v1/lists-signal/bulk-status" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "signal_ids": ["<signal-id>"],
    "account_ids": ["<account-id-1>", "<account-id-2>"],
    "list_id": "<list-id>"
  }'
```
   Wait until all statuses are non-zero (1=done, 2=failed, 3=N/A). Poll every 5-10 seconds.

5. **Filter results** — Read signal values for each account via `GET /api/v1/account/:id` or person via `GET /api/v1/person/:id/signals`. Keep records where signal output starts with "yes" (or matches desired criteria).

6. **Create a filtered sub-list** with qualifying records using `POST /api/v1/lists` and `POST /api/v1/lists/:id/add-members`.

---

## Workflow B: Stacked Signals for Scoring

**Use when:** You want to score and prioritize accounts based on multiple signals firing simultaneously (e.g., funding AND hiring AND tech adoption = hot account).

### Steps

1. **Define your signal stack** — Choose 2-5 signals that together indicate high buying intent. Examples:
   - Raised funding in last 90 days
   - Actively hiring for a relevant role
   - Using a competitor's product (technographic)
   - Company headcount growing >20% YoY
   - Recent executive hire in a relevant function

2. **Create all signals** — One `POST /api/v1/signal` per signal (see Workflow A step 2 for format). Collect all signal IDs.

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

4. **Poll all signals to completion** — Use `bulk-status` with all signal IDs. Wait until all statuses are non-zero.

5. **Score accounts** — Read signal values for each account. Assign 1 point per "yes" signal. Accounts with score ≥ N (e.g., 2 of 3) are prioritized.

6. **Create a priority sub-list** — Move high-scoring accounts to a new `"Priority TAL - <date>"` list via `POST /api/v1/lists` and `POST /api/v1/lists/:id/add-members`.

---

## Workflow C: Multi-Dimensional Account Scoring

**Use when:** You need comprehensive account scoring across multiple dimensions (e.g., ICP fit + buying intent + engagement + timing).

### Steps

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
