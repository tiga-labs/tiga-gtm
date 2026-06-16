# Signal Type: `hiring_for_role`

Detects whether an account is actively hiring for specific job titles across LinkedIn, Indeed, and/or TheirStack.

**Scope:** Account only

---

## Example

```json
{
  "label": "Hiring for VP of Sales",
  "is_computed_column": true,
  "type": "text",
  "computed_config": {
    "type": "hiring_for_role",
    "is_account_insight": true,
    "hiring_for_role": {
      "job_titles": ["VP of Sales", "Head of Sales", "Director of Sales"],
      "location": "CA",
      "should_check_linkedin": true,
      "should_check_indeed": true,
      "should_check_their_stack": false
    },
    "expiration_in_days": 14
  }
}
```

---

## Fields

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `is_account_insight` | boolean | Yes | Must be `true` |
| `hiring_for_role.job_titles` | string[] | Yes | Job titles to search for |
| `hiring_for_role.should_check_linkedin` | boolean | Yes | Search LinkedIn job listings |
| `hiring_for_role.should_check_indeed` | boolean | Yes | Search Indeed job listings |
| `hiring_for_role.should_check_their_stack` | boolean | Yes | Search TheirStack job listings |
| `hiring_for_role.location` | string | No | US state code (e.g. `"CA"`, `"NY"`) |
| `expiration_in_days` | integer | No | Recommended: 14 days |

> At least one of `should_check_linkedin`, `should_check_indeed`, or `should_check_their_stack` must be `true`.

> The account must have a LinkedIn URL — signals without one are marked `MISSING_DEPENDENCIES`.
