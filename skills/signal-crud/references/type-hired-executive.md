# Signal Type: `hired_executive`

Detects whether an account has recently announced hiring a new executive via their LinkedIn company page posts.

**Scope:** Account only

---

## Example

```json
{
  "label": "New Executive Hire",
  "is_computed_column": true,
  "type": "text",
  "computed_config": {
    "type": "hired_executive",
    "is_account_insight": true,
    "prompt": "Did {{.AccountName}} announce hiring a new C-suite or VP-level executive?",
    "date_range": "THREE_MONTHS",
    "word_limit": 60
  }
}
```

---

## Fields

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `is_account_insight` | boolean | Yes | Must be `true` |
| `prompt` | string | Yes | Question to evaluate posts against — scope it to executive hiring |
| `date_range` | string | No | Time window — same values as `linkedin_posts` |
| `word_limit` | integer | No | Max words in output |
| `few_shot_examples` | string | No | Examples to guide output format |
| `default_value` | string | No | Fallback if no matching posts found |

**`date_range` values:** `"TWO_WEEKS"`, `"ONE_MONTH"`, `"THREE_MONTHS"`, `"SIX_MONTHS"`, `"TWELVE_MONTHS"`, `"THIS_QUARTER"`, `"THIS_YEAR"`

---

## Behavior

- Uses the same LinkedIn post pipeline as `linkedin_posts` but with a prompt focused on executive hiring announcements.
- Extracts the hired executive's title and name when found.
- Dependencies auto-set to `CompanyLi_Posts`.
- Sets `NOT_FOUND` if no executive hire posts are found in the date range.
