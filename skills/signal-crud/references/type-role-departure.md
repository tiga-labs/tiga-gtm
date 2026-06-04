# Signal Type: `role_departure`

Detects people who have recently left roles at an account, filtered by title or job level.

**Scope:** Account only

---

## Example

```json
{
  "label": "C-Suite Departure Last Month",
  "is_computed_column": true,
  "type": "text",
  "computed_config": {
    "type": "role_departure",
    "is_account_insight": true,
    "role_departed_account_config": {
      "departed_within": "ONE_MONTH",
      "titles": [],
      "job_levels": ["C-Team", "VPs"]
    }
  }
}
```

---

## Fields

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `is_account_insight` | boolean | Yes | Must be `true` |
| `role_departed_account_config.departed_within` | string | Yes | Time window — see values below |
| `role_departed_account_config.titles` | string[] | No | Specific job titles to filter for (e.g. `["CTO", "VP Sales"]`). Leave empty to rely on `job_levels` |
| `role_departed_account_config.job_levels` | string[] | No | Job level categories (e.g. `["C-Team", "VPs", "Directors"]`) |

**Defaults (if config omitted):** `departed_within: "ONE_MONTH"`, `job_levels: ["C-Team"]`, `titles: []`

**`departed_within` values:** `"TWO_WEEKS"`, `"ONE_MONTH"`, `"THREE_MONTHS"`, `"SIX_MONTHS"`, `"TWELVE_MONTHS"`, `"THIS_QUARTER"`, `"THIS_YEAR"`

---

## Behavior

- Queries the workforce data source for recent departures matching the title/level filters.
- Returns up to 5 matching departures with departure dates.
- Sets `NOT_FOUND` if no departures match.
