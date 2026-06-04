# Signal Type: `started_new_role`

Detects whether a person has recently started a new position.

**Scope:** Person only

---

## Example

```json
{
  "label": "Started New Job This Year",
  "is_computed_column": true,
  "type": "text",
  "computed_config": {
    "type": "started_new_role",
    "is_account_insight": false,
    "started_new_role_config": {
      "started_new_job_within": "THIS_YEAR",
      "should_exclude_advisor_roles": true
    }
  }
}
```

---

## Fields

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `is_account_insight` | boolean | Yes | Must be `false` |
| `started_new_role_config.started_new_job_within` | string | Yes | Time window — see values below |
| `started_new_role_config.should_exclude_advisor_roles` | boolean | No | Filter out advisory/board positions |

**Default (if config omitted):** `started_new_job_within: "THIS_YEAR"`

**`started_new_job_within` values:** `"TWO_WEEKS"`, `"ONE_MONTH"`, `"THREE_MONTHS"`, `"SIX_MONTHS"`, `"TWELVE_MONTHS"`, `"THIS_QUARTER"`, `"THIS_YEAR"`

---

## Behavior

- Reads the person's LinkedIn profile for job history.
- If cached profile data is older than 3 months, automatically fetches a fresh copy (consumes credits).
- Filters positions that started within the time window.
- If `should_exclude_advisor_roles` is `true`, uses the LLM to classify and exclude advisory positions.
- Returns the first matching new position.
