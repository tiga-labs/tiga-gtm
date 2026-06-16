# Signal Type: `gpt`

General-purpose AI signal. Write a prompt; Tiga runs it against each record using the LLM with optional web search.

**Scope:** Account or person (set `is_account_insight` accordingly)

---

## Example

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

---

## Fields

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `prompt` | string | Yes | Supports `{{.MergeField}}` variables. Dependencies are auto-extracted from the template. |
| `is_account_insight` | boolean | Yes | `true` for account signals, `false` for person signals |
| `can_use_web_search` | boolean | No | Allow live web search during computation |
| `temperature` | float | No | 0.0–1.0, default: 0.4 |
| `max_tokens` | integer | No | Default: 4048 |
| `frequency_penalty` | float | No | 0.0–2.0 |
| `word_limit` | integer | No | Max words in the output |
| `response_type` | string | No | `"word"`, `"sentence"`, `"paragraph"`, `"full"` |
| `api` | string | No | `"Agentic"` (default, uses tools) or `"ChatCompletion"` |
| `should_classify_output_as_bool` | boolean | No | Normalize output to yes/no |
| `few_shot_examples` | string | No | Examples to guide output format |
| `advanced_model_verify` | boolean | No | Run a second-pass verification |
| `default_value` | string | No | Fallback if computation returns nothing |
| `expiration_in_days` | integer | No | Days before result expires and recomputes (default: 30) |
| `recompute_on_dependencies` | string[] | No | Signal IDs that trigger a recompute when updated |

> `model` is auto-set on create — do not set manually.

---

## Merge Fields

Dependencies are extracted automatically from `{{.FieldName}}` variables in the prompt. If a required dependency is missing for a record, the signal is marked `MISSING_DEPENDENCIES` (uses `default_value` if set).

**Common account fields:** `{{.AccountName}}`, `{{.AccountWebsite}}`, `{{.AccountLinkedIn}}`
**Common person fields:** `{{.FirstName}}`, `{{.LastName}}`, `{{.Title}}`, `{{.PersonLinkedIn}}`
**Date helpers:** `{{.Last90Days}}`, `{{.Last180Days}}`, `{{.Last365Days}}`

Discover all available fields:
```bash
GET /api/v1/account/columns?mode=merge_fields
GET /api/v1/person/columns?mode=merge_fields
```
