# Signal Types Index

Reference files for each `computed_config.type` value.

| Type | Scope | Reference |
|------|-------|-----------|
| `gpt` | Account or Person | `references/type-gpt.md` |
| `hiring_for_role` | Account only | `references/type-hiring-for-role.md` |
| `linkedin_posts` | Account or Person | `references/type-linkedin-posts.md` |
| `hired_executive` | Account only | `references/type-hired-executive.md` |
| `sec_document` | Account only | `references/type-sec-document.md` |
| `role_departure` | Account only | `references/type-role-departure.md` |
| `started_new_role` | Person only | `references/type-started-new-role.md` |
| `search` | Account or Person | `references/type-search.md` |
| `technographics` | Account only | `references/type-technographics.md` |

---

## Shared Fields (all types)P

These fields apply to every `computed_config` regardless of type:

| Field | Type | Notes |
|-------|------|-------|
| `is_account_insight` | boolean | `true` for account signals, `false` for person signals |
| `expiration_in_days` | integer | Days before result expires and recomputes (default: 30) |
| `default_value` | string | Fallback if computation returns nothing |
| `word_limit` | integer | Max words in output |
| `email_settings` | string | `"always_create"`, `"never_create"`, `"create_if_no_play"`, `"notification"` |
| `has_precondition` | boolean | Set `true` to enable conditional execution |
| `precondition.asset_type` | string | `"account"` or `"person"` |
| `precondition.property` | string | Field name to check |
| `precondition.property_type` | string | Data type of the field |
| `precondition.operator` | string | Comparison operator |
| `precondition.value` | string | Value to compare against |
