# Tiga API Reference

Base URL: `https://app.tigalabs.com`

All requests require: `X-Tiga-Auth: <API_KEY>` header.

## Secrets / OAuth Tokens

| Endpoint | Method | Returns |
|----------|--------|---------|
| `/api/v1/current-org/salesforce-oauth-token` | GET | `access_token`, `instance_url` |
| `/api/v1/current-org/hubspot-oauth-token` | GET | `access_token` |
| `/api/v1/current-user/microsoft-oauth-token` | GET | `access_token`, `expiry` |
| `/api/v1/current-user/google-oauth-token` | GET | `access_token`, `expiry` |

If not connected, returns: `{"message": "<service> account not connected"}`

## Utility API

### Clean Account Name
```
POST /api/v1/util/clean-account-name
Body: {"account_name": "ACME corp. INC"}
Response: {"cleaned_account_name": "Acme Corp"}
```

### Clean Person Name
```
POST /api/v1/util/clean-person-name
Body: {"first_name": "JOHN", "last_name": "doe jr."}
Response: {"cleaned_first_name": "John", "cleaned_last_name": "Doe Jr."}
```

## People API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/people` | GET | List people (paginated). Headers: `Tiga-Pagination`, `Tiga-Filter` |
| `/api/v1/people` | POST | Create person. Body: `first_name`, `last_name`, `email_address`, `title`, `person_linkedin`, `account_name`, `website`, `phone` |
| `/api/v1/person/:id` | PUT | Update person (full replace) |
| `/api/v1/person/:id` | DELETE | Delete person |
| `/api/v1/person/:id/signals` | GET | Get AI signals for person |
| `/api/v1/person/li-fact` | POST | Lookup/create person by LinkedIn URL |

## Accounts API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/accounts` | GET | List accounts (paginated). Headers: `Tiga-Pagination`, `Tiga-Filter` |
| `/api/v1/account` | POST | Create account. Body: `name`, `domain`, `linkedin_url` |
| `/api/v1/account/:id` | GET | Get single account |
| `/api/v1/account/:id` | PUT | Update account. Fields: `name`, `domain`, `industry`, `city`, `region`, `do_not_contact` |
| `/api/v1/accounts` | DELETE | Bulk delete. Body: `account_ids` array |

Account object fields: `id`, `name`, `industry`, `domain`, `website`, `logo_url`, `linked_in_url`, `estimated_num_employees`, address fields, `owner_id`, `stage`, `do_not_contact`, `custom_columns`, `sync_ids`

## Waterfall Enrich API

### Start Enrichment
```
POST /api/v1/people/enrich-person
Body: {
  "first_name": "Jane",        // required
  "last_name": "Smith",         // required
  "company_name": "Acme Corp",  // required
  "domain": "acme.com",         // optional, boosts accuracy
  "person_linkedin_url": "...", // optional, boosts accuracy
  "title": "VP Sales",          // optional
  "company_linkedin_url": "..." // optional
}
Response: {"enrich_id": "<uuid>"}
```

### Poll Enrichment Status
```
GET /api/v1/enrich/:id
Response: {
  "data_import_status": "Running" | "Person And Account Created" | ...,
  "email_address": "...",
  "phone": "...",
  "mobile_phone": "...",
  "person_id": "...",
  "account_name": "...",
  "domain": "...",
  "industry": "...",
  "title": "...",
  ...
}
```
Poll until `data_import_status` is not "Running".

## Signals API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/signals` | GET | List signals. Params: `is_computed_column`, `account_columns_only`, `person_columns_only` |
| `/api/v1/signal/:id` | GET | Get single signal |
| `/api/v1/signal` | POST | Create signal |
| `/api/v1/signal/:id` | PUT | Update signal |
| `/api/v1/signal/:id` | DELETE | Delete signal |

### Create AI Signal Example
```json
{
  "label": "Company Tech Stack",
  "is_computed_column": true,
  "computed_config": {
    "type": "gpt",
    "prompt": "Research this company's technology stack.",
    "is_account_insight": true,
    "can_use_web_search": true,
    "expiration_in_days": 90,
    "temperature": 0.4,
    "word_limit": 50
  }
}
```

### Computed Config Fields
- `type`: "gpt", "hiring_for_role", "technographics", etc.
- `prompt`: AI instruction text
- `is_account_insight`: true = runs on accounts, false = runs on people
- `can_use_web_search`: enable web browsing
- `expiration_in_days`: staleness threshold
- `temperature`: 0.0-1.0
- `max_tokens`: response length limit

### Field Merge Templates
Use `{{.FieldName}}` in prompts:
- Person: `{{.FirstName}}`, `{{.LastName}}`, `{{.EmailAddress}}`, `{{.LinkedInUrl}}`, `{{.Title}}`
- Account: `{{.AccountName}}`, `{{.AccountWebsite}}`, `{{.AccountIndustry}}`
- LinkedIn: `{{.PersonLi_Summary}}`, `{{.CompanyLi_Keywords}}`
- Time: `{{.Last30Days}}`, `{{.CurrentDate}}`

Discover custom merge fields: `GET /api/v1/account/columns?mode=merge_fields`

## Lists API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/lists` | GET | List all lists. Params: `object_type` |
| `/api/v1/lists/:id` | GET | Get single list |
| `/api/v1/lists` | POST | Create list. Body: `name`, `object_type`, `list_signals`, optional `object_ids`, `filter`, `from_list_id` |
| `/api/v1/lists/:id` | PUT | Update list |
| `/api/v1/lists/` | DELETE | Bulk delete. Body: `list_ids` array |
| `/api/v1/lists/:id/add-members` | POST | Add members. Body: `object_ids`, `filter`, `select_all` |
| `/api/v1/lists/:id/run-all-signal` | POST | Run signals on all members. Optional: `signal_ids` |
| `/api/v1/lists/:id/stop-all-signal` | POST | Stop signal computation |
| `/api/v1/lists-signal/bulk-status` | POST | Poll signal compute status. Values: 0=not computed, 1=success, 2=failed, 3=N/A |

## Sequences API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/sequences` | GET | List sequences with stats |
| `/api/v1/sequence/:id/metrics` | GET | Sequence performance metrics by step |
| `/api/v1/sequence/:id/add-people` | POST | Add people to sequence. Body: `people_ids`, `step_id`, `list_id` |

## Pagination Headers

For paginated endpoints, use these headers:
- `Tiga-Pagination`: `{"page": 1, "page_size": 50, "sort_by": "name", "sort_order": "asc"}`
- `Tiga-Filter`: `{"search_term": "acme", "filter": {...}}`
