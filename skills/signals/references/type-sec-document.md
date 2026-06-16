# Signal Type: `sec_document`

Searches an account's SEC filings using semantic search and summarizes relevant content.

**Scope:** Account only (public companies with SEC filings)

---

## Example

```json
{
  "label": "Budget Cuts Mentioned",
  "is_computed_column": true,
  "type": "text",
  "computed_config": {
    "type": "sec_document",
    "is_account_insight": true,
    "prompt": "Are there any mentions of budget cuts or cost reduction initiatives?",
    "description": "10-K",
    "word_limit": 150
  }
}
```

---

## Fields

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `is_account_insight` | boolean | Yes | Must be `true` |
| `prompt` | string | Yes | Search query — used as the semantic embedding input |
| `description` | string | Yes | Filing type to search: `"10-K"`, `"10-Q"`, `"8-K"` |
| `word_limit` | integer | No | Max output length (default: 150 characters) |
| `default_value` | string | No | Fallback if no relevant content found |

---

## Behavior

- Embeds the `prompt` and runs vector similarity search against stored SEC documents.
- Returns `NOT_FOUND` if no relevant document content is found.
- Cache key is based on `prompt` + `description` (filing type).
- Only works for accounts that have SEC documents indexed in Tiga.
