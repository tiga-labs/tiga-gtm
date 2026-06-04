# Signal Type: `linkedin_posts`

Analyzes recent LinkedIn posts from a company page or person profile and evaluates them against a prompt.

**Scope:** Account or person (set `is_account_insight` accordingly)

---

## Example

```json
{
  "label": "Posted About AI",
  "is_computed_column": true,
  "type": "text",
  "computed_config": {
    "type": "linkedin_posts",
    "is_account_insight": false,
    "prompt": "Has {{.FirstName}} {{.LastName}} posted about AI or machine learning?",
    "date_range": "THREE_MONTHS",
    "word_limit": 60
  }
}
```

---

## Fields

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `is_account_insight` | boolean | Yes | `true` for company page posts, `false` for person posts |
| `prompt` | string | Yes | Question to evaluate each post against |
| `date_range` | string | No | Time window — see values below |
| `word_limit` | integer | No | Max words in output |
| `few_shot_examples` | string | No | Examples to guide output format |
| `default_value` | string | No | Fallback if no matching posts found |

**`date_range` values:**

| Value | Window |
|-------|--------|
| `"TWO_WEEKS"` | Last 2 weeks |
| `"ONE_MONTH"` | Last month |
| `"THREE_MONTHS"` | Last 3 months |
| `"SIX_MONTHS"` | Last 6 months |
| `"TWELVE_MONTHS"` | Last 12 months |
| `"THIS_QUARTER"` | Current quarter |
| `"THIS_YEAR"` | Current year |

---

## Behavior

- Iterates posts within `date_range` and evaluates each against the prompt using the LLM.
- Returns the first matching post's content.
- Sets `NOT_FOUND` if no posts match after filtering.
- Dependencies auto-set to `CompanyLi_Posts` (account) or `PersonLi_Posts` (person).
