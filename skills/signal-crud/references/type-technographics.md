# Signal Type: `technographics`

Detects whether an account uses specific technologies by querying TheirStack.

**Scope:** Account only

---

## Example

```json
{
  "label": "Uses Salesforce",
  "is_computed_column": true,
  "type": "text",
  "computed_config": {
    "type": "technographics",
    "is_account_insight": true,
    "technographics": {
      "technologies": [
        { "name": "Salesforce", "key": "salesforce", "logo": "" },
        { "name": "HubSpot", "key": "hubspot", "logo": "" }
      ]
    },
    "expiration_in_days": 180
  }
}
```

---

## Fields

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `is_account_insight` | boolean | Yes | Must be `true` |
| `technographics.technologies` | object[] | Yes | List of technologies to detect |
| `technographics.technologies[].name` | string | Yes | Display name (e.g. `"Salesforce"`) |
| `technographics.technologies[].key` | string | Yes | TheirStack slug for matching (e.g. `"salesforce"`) |
| `technographics.technologies[].logo` | string | No | Logo URL (display only) |
| `expiration_in_days` | integer | No | Recommended: 180 days (TheirStack data is updated infrequently) |

---

## Behavior

- Queries TheirStack for the account's tech stack using the account domain.
- Matches configured technologies against the TheirStack response.
- Returns a comma-separated list of detected technologies.
- Sets `NOT_FOUND` if none of the configured technologies are detected.
- Results cached for 6 months via a Fact record per account.
