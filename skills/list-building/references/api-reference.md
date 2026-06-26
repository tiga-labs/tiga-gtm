# Tiga API Reference — List Building Subset

## Authentication & Headers

**Base URL:** `https://app.tigalabs.com` (production). The base URL is environment-specific — users may run against their own host (e.g. `http://localhost:3000` in dev, or a custom domain). Honor whatever the user gives you; scripts conventionally read it from `TIGA_BASE`.

**Required auth header (all endpoints):**
```
X-Tiga-Auth: YOUR_API_KEY
Content-Type: application/json
```

Store the key in an env var: `export TIGA_API_KEY="your_key_here"`

**Pagination header** (optional, on list endpoints):
```json
Tiga-Pagination: {"page": 1, "page_size": 25, "sort_by": "created_at", "sort_order": "desc"}
```

**Filter header** (optional, on list endpoints):
```json
Tiga-Filter: {"search_term": "acme", "list_id": "uuid", "sequence_id": "uuid", "filter": []}
```

---

## Accounts API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/accounts` | List accounts (supports Tiga-Pagination, Tiga-Filter) |
| GET | `/api/v1/account/:id` | Get single account |
| POST | `/api/v1/account` | Create account |

**Create account body:**
```json
{
  "name": "Acme Corp",
  "domain": "acme.com",
  "linkedin_url": "https://www.linkedin.com/company/acme"
}
```
- `domain` and `linkedin_url` must be unique — returns `409 Conflict` if duplicate.

---

## People API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/people` | List people (supports Tiga-Pagination, Tiga-Filter) |
| POST | `/api/v1/people` | Create person |

**Create person body:**
```json
{
  "first_name": "Jane",
  "last_name": "Smith",
  "email_address": "jane@acme.com",
  "title": "VP of Sales",
  "person_linkedin": "https://www.linkedin.com/in/janesmith",
  "account_name": "Acme Corp",
  "website": "acme.com",
  "phone": "+14155550100"
}
```

**Filter by list** (via Tiga-Filter header):
```json
Tiga-Filter: {"list_id": "list-uuid"}
```

---

## Data Endpoints

Read-only LinkedIn lookups by public URL — useful for enriching list rows. Neither creates a person/account in your workspace; results are cached on first fetch.

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/li-person-fact` | LinkedIn person data by public profile URL |
| POST | `/api/v1/li-company-fact` | LinkedIn company data by public company URL |

**LinkedIn person fact** (`POST /api/v1/li-person-fact`):
- Body: `{"linkedin_url": "https://www.linkedin.com/in/aaronmlevine"}` (required).
- Query param `shouldIncludePosts=true` includes recent posts; otherwise `posts`/`recent_posts` are `null`.
- `204` if no fact can be found or fetched.
```json
{
  "first_name": "Aaron",
  "last_name": "Levine",
  "headline": "Chief Financial Officer at Prophix",
  "current_title": "Chief Financial Officer",
  "experience_data": [
    {
      "company": { "name": "Prophix", "linkedin_url": "https://www.linkedin.com/company/prophix-software/" },
      "roles": [ { "title": "Chief Financial Officer", "is_current_role": true, "start_date": "2024-01-01T00:00:00Z" } ]
    }
  ],
  "country": "United States",
  "geo": "Washington DC-Baltimore Area",
  "skills": "Business Strategy, Private Equity, Mergers & Acquisitions…",
  "linked_in_id": "aaronmlevine",
  "posts": null,
  "recent_posts": null
}
```

**LinkedIn company fact** (`POST /api/v1/li-company-fact`):
- Body: `{"linkedin_url": "https://www.linkedin.com/company/10pearls"}` (required).
- Query param `shouldIncludePosts=true` includes recent posts; otherwise `posts`/`recent_posts` are `null`.
- `204` if no fact can be found or researched.
```json
{
  "name": "10Pearls",
  "domain": "10pearls.com",
  "website": "https://10pearls.com",
  "company_size": { "size": "1,001-5,000 employees" },
  "linked_in_id": "10pearls",
  "linked_in_url": "https://ca.linkedin.com/company/10pearls",
  "industry": "IT Services and IT Consulting",
  "location": "Vienna, Virginia",
  "keywords": ["Mobile Applications", "Cyber Security", "DevOps"],
  "recent_funding": false,
  "posts": null,
  "recent_posts": null
}
```

---

## Lists API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/lists` | List all lists (filter: `?object_type=person\|account`) |
| POST | `/api/v1/lists` | Create list |
| POST | `/api/v1/lists/:id/add-members` | Add members to list |

**Create list body:**
```json
{
  "list": {
    "name": "Q2 Target Accounts",
    "object_type": "account"
  }
}
```
Optional fields: `object_ids`, `excluded_object_ids`, `filter`, `from_list_id`, `search_term`, `select_all`. Advanced person-list selection also accepts `sequence_id`, `task_status`, and `step_id` when `select_all` is true.

**Add members body** (`POST /api/v1/lists/:id/add-members`):
```json
{
  "object_ids": ["uuid1", "uuid2"],
  "excluded_object_ids": ["uuid3"],
  "filter": {},
  "from_list_id": "uuid",
  "search_term": "string",
  "select_all": false
}
```

> **Request body validation:** This API route rejects unknown fields. To add explicit records, provide `object_ids` as a non-empty array; do not use `member_ids`. To add by `filter`, `from_list_id`, `search_term`, or sequence task status, set `select_all: true`. Sending an empty `object_ids` array without `select_all: true`, omitting both `object_ids` and `select_all`, or using a misnamed field returns `400` with an explanation. After calling this endpoint, verify membership with `GET /api/v1/accounts` or `GET /api/v1/people` using `Tiga-Filter: {"list_id":"<id>"}`; `total_count` should be > 0 before handing off to signals or sequences.

---

## Waterfall Enrich API (async)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/people/enrich-person` | Submit enrichment job → returns `enrich_id` |
| GET | `/api/v1/enrich/:id` | Poll enrichment status |

**Submit enrichment:**
```json
{
  "first_name": "Jane",
  "last_name": "Smith",
  "company_name": "Acme Corp",
  "domain": "acme.com",
  "person_linkedin_url": "https://www.linkedin.com/in/janesmith",
  "title": "VP of Sales",
  "company_linkedin_url": "https://www.linkedin.com/company/acme"
}
```
- `first_name`, `last_name`, `company_name` are required
- `person_linkedin_url` and `domain` significantly increase accuracy

**Poll response (running):**
```json
{"data_import_status": "Running", ...}
```

**Poll response (complete):**
```json
{
  "data_import_status": "Person And Account Created",
  "email_address": "jane@acme.com",
  "phone": "+14155550100",
  "person_id": "uuid",
  "account_name": "Acme Corp",
  "domain": "acme.com"
}
```

---

## Find People with Agent API (async)

This searches LinkedIn for new contacts.

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/agent/find-people` | Submit search → returns `status_id` |
| GET | `/api/agent/find-people/:id/status` | Poll for results |

**Submit search:**
```json
{
  "contact_description": "VP of Engineering at Series B SaaS companies with 50-200 employees in the US",
  "model": "gpt-5.4-2026-03-05"
}
```
Valid models: `gpt-5.4-2026-03-05`, `gpt-5.2-2025-12-11`, `gpt-5.1-2025-11-13`

**Poll response (complete):**
```json
{
  "status": "Complete",
  "created_flux_ids": ["uuid-1", "uuid-2"],
  "created_people": [
    {
      "first_name": "Jane",
      "last_name": "Smith",
      "title": "VP of Engineering",
      "account_name": "Acme Corp",
      "person_linkedin": "https://www.linkedin.com/in/janesmith"
    }
  ],
  "conversation": []
}
```

**Status values:** `"Running"` | `"Complete"` | `"Error - <reason>"`
