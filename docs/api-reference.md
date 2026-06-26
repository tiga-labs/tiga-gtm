# Tiga API Reference

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
| POST | `/api/v1/account` | Create account |
| GET | `/api/v1/account/:id` | Get single account |
| GET | `/api/v1/account/:id/li-fact` | Get scraped LinkedIn company data |
| PUT | `/api/v1/account/:id` | Update account |
| DELETE | `/api/v1/accounts` | Bulk delete (requires People Admin) |

**Create account body:**
```json
{
  "name": "Acme Corp",
  "domain": "acme.com",
  "linkedin_url": "https://www.linkedin.com/company/acme"
}
```
- `domain` and `linkedin_url` must be unique — returns `409 Conflict` if duplicate.

**Delete accounts body:**
```json
{
  "account_ids": ["uuid1", "uuid2"],
  "select_all": false,
  "excluded_account_ids": []
}
```

**LinkedIn company data** (`GET /api/v1/account/:id/li-fact`):
- Path param `:id` is the account UUID. Returns the scraped LinkedIn company fact Tiga has on file for the account.
- Returns `204 No Content` if no fact is on file; `404` if the account is not found.
- Response includes: name, description, website, domain, company size, latest funding, LinkedIn IDs/URL, recent posts, open jobs, keywords, industry, location, employee count.
```json
{
  "name": "10Pearls",
  "description": "View all 2,240 employees",
  "website": "https://10pearls.com",
  "domain": "10pearls.com",
  "tagline": "",
  "company_size": { "size": "1,001-5,000 employees" },
  "latest_funding": null,
  "latest_funding_date": "0001-01-01T00:00:00Z",
  "linked_in_id": "10pearls",
  "linked_in_urn_id": "327623",
  "linked_in_url": "https://ca.linkedin.com/company/10pearls",
  "posts": [
    {
      "date": "2025-12-10",
      "name": "10Pearls",
      "post_id": "urn:li:activity:7404513024566575104",
      "post_link": "https://www.linkedin.com/feed/update/urn:li:activity:7404513024566575104",
      "post_text": "Turns out, nothing brings a team together like cracking clues under pressure…",
      "total_links": "32"
    }
  ],
  "recent_posts": [],
  "jobs": [
    { "listdate": "2025-12-05", "location": "Tysons Corner, VA", "subtitle": "10Pearls", "title": "HR Generalist" }
  ],
  "recent_funding": false,
  "keywords": ["Mobile Applications", "Cyber Security", "DevOps", "Artificial Intelligence"],
  "ticker_symbol": "",
  "industry": "IT Services and IT Consulting",
  "location": "Vienna, Virginia",
  "is_website_valid": true,
  "employee_count": 0
}
```

---

## People API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/people` | List people (supports Tiga-Pagination, Tiga-Filter) |
| POST | `/api/v1/people` | Create person |
| PUT | `/api/v1/person/:id` | Update person |
| DELETE | `/api/v1/person/:id` | Delete person |
| GET | `/api/v1/person/:id/signals` | Get AI signal values for a person |
| GET | `/api/v1/person/:id/li-fact` | Get scraped LinkedIn profile data |

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

**LinkedIn profile data** (`GET /api/v1/person/:id/li-fact`):
- Query param: `shouldFetchIfNotFound=true` triggers a live fetch from LinkedIn (consumes credits)
- Returns `204 No Content` if unavailable
- Response includes: name, headline, about, experience, education, skills, interests, recommendations, posts, location, LinkedIn ID, promotion dates, role change indicators
- `experience` is a flattened text summary; `experience_data` is the structured equivalent. `raw_profile` holds the full provider payload. Long arrays are abbreviated below.
```json
{
  "first_name": "Aaron",
  "last_name": "Levine",
  "about": "Seasoned, results-oriented, collaborative financial executive…",
  "headline": "Chief Financial Officer at Prophix",
  "posts": [
    {
      "date": "2026-06-01",
      "post_id": "urn:li:activity:7467219151045103617",
      "post_link": "https://www.linkedin.com/feed/update/urn:li:activity:7467219151045103617",
      "post_text": "Most finance leaders think they have a speed problem. They don't…"
    }
  ],
  "recent_posts": null,
  "education": "The Johns Hopkins University - Carey Business School, MBA (Finance)\nUniversity of Delaware, BS (Accounting)",
  "experience_data": [
    {
      "HasNoEndDate": false,
      "company": { "name": "Prophix", "linkedin_url": "https://www.linkedin.com/company/prophix-software/" },
      "roles": [
        { "title": "Chief Financial Officer", "is_current_role": true, "employment_type": "Full-time", "start_date": "2024-01-01T00:00:00Z", "end_date": "0001-01-01T00:00:00Z" }
      ]
    }
  ],
  "country": "United States",
  "geo": "Washington DC-Baltimore Area",
  "skills": "Business Strategy, Private Equity, Mergers & Acquisitions, Financial Modeling…",
  "linked_in_id": "aaronmlevine",
  "latest_new_job_date": "2024-01-01T00:00:00Z",
  "recent_role_change": false,
  "raw_profile": { "…": "full provider payload (positions, educations, skills, geo, urn)" },
  "current_title": "Chief Financial Officer",
  "licenseAndCertificates": [
    { "authority": "State of Maryland", "name": "Certified Public Accountant", "start_month": 0, "start_year": 0 }
  ]
}
```

**Signals response** (`GET /api/v1/person/:id/signals`):
```json
[
  {
    "category": "signal-label",
    "insight": "computed text value",
    "insight_event_date": "2026-03-01T00:00:00Z",
    "not_found": false,
    "insight_data": {},
    "insight_source": "web"
  }
]
```

---

## Lists API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/lists` | List all lists (filter: `?object_type=person\|account`) |
| GET | `/api/v1/lists/:id` | Get single list |
| POST | `/api/v1/lists` | Create list |
| PUT | `/api/v1/lists/:id` | Update list |
| DELETE | `/api/v1/lists/` | Bulk delete lists |
| POST | `/api/v1/lists/:id/add-members` | Add members to list |
| POST | `/api/v1/lists/:id/run-all-signal` | Trigger signal computation for list |
| POST | `/api/v1/lists/:id/stop-all-signal` | Cancel running signals |
| POST | `/api/v1/lists-signal/bulk-status` | Check signal compute status |

**Create list body:**
```json
{
  "list": {
    "name": "Q2 Target Accounts",
    "object_type": "account",
    "list_signals": {
      "<signal_id>": true
    }
  },
  "run_signals_config": {
    "signal_ids": ["signal-uuid-1", "signal-uuid-2"]
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

**Run signals body** (`POST /api/v1/lists/:id/run-all-signal`):
```json
{
  "signal_ids": ["uuid1", "uuid2"]
}
```
Signal IDs optional; uses list's saved configuration if omitted. Jobs queue asynchronously.

**Bulk status request** (check if signals are done):
```json
POST /api/v1/lists-signal/bulk-status
{
  "signal_ids": ["signal-uuid-1"],
  "account_ids": ["account-uuid-1", "account-uuid-2"],
  "list_id": "list-uuid"
}
```
Use `people_ids` instead of `account_ids` for person lists (not both).

**Status values:**
- `0` — Not computed yet
- `1` — Done (success)
- `2` — Failed
- `3` — N/A (signal not applicable to this record)

---

## P13N API (AI Personalizations)

P13ns are AI-generated text snippets computed fresh for each person when their sequence task is created. They are step-linked: each p13n belongs to a specific sequence step and its output is embedded in the step's email body or LinkedIn message via a merge field (`{{.key}}`).

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/p13ns` | List p13ns (optional `?step_id=<uuid>`) |
| GET | `/api/v1/p13n/:id` | Get single p13n |
| POST | `/api/v1/p13n` | Create p13n |
| PUT | `/api/v1/p13n/:id` | Update p13n |
| DELETE | `/api/v1/p13n/:id` | Delete p13n |
| POST | `/api/v1/p13n/:id/run` | Async: run p13n on a person |
| GET | `/api/v1/p13n/:id/run-status` | Poll run status (`?person_id=<uuid>`) |

**Create p13n body:**
```json
{
  "label": "Personalized Opening",
  "step_id": "<step-uuid>",
  "prompt": "Write a 2-sentence opening for {{.FirstName}} at {{.AccountName}}. Reference: {{.PersonLi_Headline}}.",
  "word_limit": 60,
  "default_value": "I came across your profile and was impressed by your work.",
  "temperature": 0.6
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `label` | Yes | Display name. Also seeds the `key` (e.g. `personalized_opening_a1b2c3`) |
| `step_id` | Recommended | UUID of the sequence step. When set, p13n is auto-computed at task creation and `is_linkedin_msg` is inferred from the step's action type. |
| `prompt` | Yes | AI instruction. Use `{{.FieldName}}` merge fields. LinkedIn/company facts are fetched when the prompt references them (e.g. `{{.PersonLi_Headline}}`). |
| `word_limit` | No | Max output words (default: 80) |
| `default_value` | No | Fallback text if person lacks required data |
| `temperature` | No | 0.0–1.0 (default: 0.5) |
| `is_linkedin_msg` | No | Explicit override for LinkedIn vs. email output format. Inferred from `step_id`'s action when omitted. Set to `true` for `LinkedInMessage`/`LinkedInConnect` steps if not providing `step_id`. |

**Response includes `key`** — the merge field identifier. Use `{{.key}}` in step templates.

**Update p13n writable fields:** `label`, `prompt`, `word_limit`, `default_value`, `temperature`

**Run p13n on person (async):**
```json
POST /api/v1/p13n/:id/run
{
  "person_id": "<person-uuid>"
}
```
Or find-or-create: `{ "person": {"email": "jane@acme.com"} }`

Returns: `{ "p13n_id": "...", "person_id": "...", "status": "Running" }`

**Poll run status:**
```
GET /api/v1/p13n/:id/run-status?person_id=<person-uuid>
```

Terminal status values: `"Complete"` (with `value` field), `"Not Found"`, `"Missing Dependencies"`, `"Error"`, `"Precondition Not Met"`. Non-terminal: `"Running"`. Poll every 5–10s, timeout at 120s.

---

## Sequence Steps API

Steps are the building blocks of sequences. Modify steps only while the sequence is **inactive** — use `POST /api/v1/sequence/:id/deactivate` first.

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/sequence/:id/add-step` | Add a step to a sequence |
| GET | `/api/v1/step/:id` | Get full step content |
| PATCH | `/api/v1/step/:id` | Update a step's content |
| DELETE | `/api/v1/step/:id` | Delete a step |

**Add step** (`POST /api/v1/sequence/:id/add-step?stepToAppendToId=<uuid>`):

`stepToAppendToId` — the step to insert *after*. Use `00000000-0000-0000-0000-000000000000` (nil UUID) to insert as the first step.

```json
{
  "action": "SequenceEmail",
  "step_name": "Initial Outreach",
  "email_subject": "Quick question about {{.AccountName}}",
  "email_body": "Hi {{.FirstName}},\n\n{{.my_p13n_key}}\n\nBest,\n{{.UserName}}",
  "can_run_on_weekends": false
}
```

| Field | Description |
|-------|-------------|
| `action` | `SequenceEmail`, `LinkedInMessage`, or `LinkedInConnect` |
| `step_name` | Display name |
| `email_subject` | Subject line (SequenceEmail only) |
| `email_body` | Email body — supports `{{.FieldName}}` merge fields |
| `linkedin_message` | Message content (LinkedInMessage only) |
| `can_run_on_weekends` | Default: false |

Response includes the new step `ID`.

**Get step** (`GET /api/v1/step/:id`):

Returns the full step object including `EmailBody`, `EmailSubject`, `LinkedInMessage`, `Action`, `Name`, timing fields, and all other persisted values. Always GET a step before patching it — `SequenceEmail` steps require both `EmailSubject` and `EmailBody` in the PATCH body, so you need the current values if you're only changing one.

**Update step** (`PATCH /api/v1/step/:id`):

Send `Action` and the content fields to update. For `SequenceEmail`, always send both `EmailSubject` and `EmailBody` together. Accepts both PascalCase (`EmailBody`) and snake_case (`email_body`).

```json
{
  "Action": "SequenceEmail",
  "EmailSubject": "Updated subject",
  "EmailBody": "Hi {{.FirstName}},\n\n{{.personalized_opening_a1b2c3}}\n\nBest,\n{{.UserName}}"
}
```

> When step content is updated, any p13n `{{.key}}` merge fields that no longer appear in the email body, subject, or LinkedIn message are deleted from the p13n table.

---

## Signals API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/signals` | List signals |
| GET | `/api/v1/signal/:id` | Get single signal |
| POST | `/api/v1/signal` | Create signal |
| PUT | `/api/v1/signal/:id` | Update signal |
| DELETE | `/api/v1/signal/:id` | Delete signal |

**List query params:**
- `is_computed_column=true` — AI-computed signals only
- `account_columns_only=true` — Account signals only
- `person_columns_only=true` — Person signals only

**Create signal body:**
```json
{
  "label": "Recent Funding News",
  "is_computed_column": true,
  "type": "text",
  "computed_config": {
    "type": "gpt",
    "prompt": "Has {{.AccountName}} raised funding in the last 90 days? Answer yes or no with a brief reason.",
    "is_account_insight": true,
    "can_use_web_search": true,
    "expiration_in_days": 90,
    "temperature": 0.4,
    "word_limit": 50
  }
}
```

**Signal `type` field:** `"text"` (default) or `"picklist"`

**`computed_config` object — full schema:**

Core fields:
- `type` (string) — `gpt`, `hiring_for_role`, `sec_document`, `linkedin_posts`, `hired_executive`, `role_departure`, `started_new_role`, `search`, `technographics`
- `description` (string)
- `prompt` (string) — required for `gpt` type
- `is_account_insight` (boolean)
- `is_standard_insight` (boolean)
- `expiration_in_days` (integer, default: 30)
- `email_settings` (string) — `always_create`, `never_create`, `create_if_no_play`, `notification`
- `word_limit` (integer)
- `default_value` (string)
- `required_dependencies` (string[])

AI model fields (for `gpt` type):
- `model` (string) — auto-set on create
- `api` (string) — `Agentic` or `ChatCompletion`
- `temperature` (float, 0.0–1.0, default: 0.4)
- `max_tokens` (integer, default: 4048)
- `frequency_penalty` (float, 0.0–2.0)
- `can_use_web_search` (boolean)
- `advanced_model_verify` (boolean)
- `should_classify_output_as_bool` (boolean)
- `response_type` (string) — `word`, `sentence`, `paragraph`, `full`
- `few_shot_examples` (string)
- `recompute_on_dependencies` (string[])

Precondition fields:
- `has_precondition` (boolean)
- `precondition.asset_type` (string)
- `precondition.property` (string)
- `precondition.property_type` (string)
- `precondition.operator` (string)
- `precondition.value` (string)

**Update signal writable fields:** `label`, `computed_config`, `can_trigger_play`, `is_user_signal` (requires Signal Admin)

**Custom merge fields:** Discover via `GET /api/v1/account/columns?mode=merge_fields` or `GET /api/v1/person/columns?mode=merge_fields`

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

---

## Data Endpoints (Third-Party Proxies)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/apollo-organization-search` | Search Apollo.io organization database |
| POST | `/api/v1/apollo-people-search` | Search Apollo.io people database |
| POST | `/api/v1/li-person-fact` | LinkedIn person data by public profile URL (read-only lookup) |
| POST | `/api/v1/li-company-fact` | LinkedIn company data by public company URL (read-only lookup) |

**Apollo organization search** — parameters passed as query strings (no request body):
```
POST /api/v1/apollo-organization-search?q_organization_name=Acme%20Corp&page=1&per_page=10
```
Full Apollo request/response schema: https://docs.apollo.io/reference/organization-search

**Apollo people search body:**
```json
{
  "person_titles": ["sales manager"],
  "q_organization_domains_list": ["apollo.io"],
  "page": 1,
  "per_page": 10
}
```
Returns name/title/company/LinkedIn URL — no emails or phones (use Waterfall Enrich for those). Full Apollo request/response schema: https://docs.apollo.io/reference/people-api-search

**LinkedIn person fact** (`POST /api/v1/li-person-fact`):
- Read-only lookup by public profile URL — does **not** create a person in your workspace. If not yet collected, it's fetched from LinkedIn on demand and cached.
- Query param `shouldIncludePosts=true` fetches the person's recent posts; when omitted (default), `posts` and `recent_posts` are `null`.
- Body: `{"linkedin_url": "https://www.linkedin.com/in/aaronmlevine"}` (required).
- `400` if the body can't be parsed, `linkedin_url` is missing, or the URL can't be resolved to a profile id; `204` if no fact can be found or fetched.
```bash
curl -X POST "https://app.tigalabs.com/api/v1/li-person-fact" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" -H "Content-Type: application/json" \
  -d '{"linkedin_url": "https://www.linkedin.com/in/aaronmlevine"}'
```
Response is the same `LiPersonFact` shape shown under People API → *LinkedIn profile data* (with `posts`/`recent_posts` populated only when `shouldIncludePosts=true`).

**LinkedIn company fact** (`POST /api/v1/li-company-fact`):
- Read-only lookup by public company-page URL — does **not** create an account in your workspace. If not yet collected, it's researched on LinkedIn on demand and cached.
- Query param `shouldIncludePosts=true` includes the company's recent posts; when omitted (default), `posts` and `recent_posts` are `null`.
- Body: `{"linkedin_url": "https://www.linkedin.com/company/10pearls"}` (required).
- `400` if the body can't be parsed, `linkedin_url` is missing, or the URL can't be resolved to a company id; `204` if no fact can be found or researched.
```bash
curl -X POST "https://app.tigalabs.com/api/v1/li-company-fact" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" -H "Content-Type: application/json" \
  -d '{"linkedin_url": "https://www.linkedin.com/company/10pearls"}'
```
Response is the same `LiCompanyFact` shape shown under Accounts API → *LinkedIn company data*.

---

## Secrets Access API

Retrieve OAuth tokens for connected integrations. Tokens are auto-refreshed before return.

| Method | Path | Token scope |
|--------|------|-------------|
| GET | `/api/v1/current-user/microsoft-oauth-token` | User: Mail, Calendar |
| GET | `/api/v1/current-org/hubspot-oauth-token` | Org: CRM, sequences |
| GET | `/api/v1/current-org/salesforce-oauth-token` | Org: Full Salesforce REST |
| GET | `/api/v1/current-user/google-oauth-token` | User: Gmail, Calendar |

**Response:**
```json
{"access_token": "...", "expiry": "2026-03-17T12:00:00Z"}
```
If not connected: `{"message": "service account not connected"}`

---

## HubSpot API

Sync Tiga people to HubSpot without calling the HubSpot API directly. Tiga handles OAuth, contact matching, and field mapping internally.

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/hubspot/create-or-update-contact` | Find or create a HubSpot contact for a Tiga person, then update their properties |

**Request body:**
```json
{
  "person_id": "uuid",
  "hubspot_owner_id": "987654321",
  "sync_account_association": false,
  "field_mappings": { "title": "jobtitle" },
  "find_person_by": {
    "email": true,
    "linkedin_url": true
  }
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `person_id` | Yes | Tiga person UUID |
| `hubspot_owner_id` | No | HubSpot owner ID — only applied on new contact creation; existing contacts' owner is not changed |
| `sync_account_association` | No | If `true`, also finds/creates the HubSpot company and associates the contact to it. Person must have an account in Tiga. |
| `field_mappings` | No | Flat tiga-field → hubspot-field map. When omitted, defaults are used: email, firstname, lastname, hs_linkedin_url, jobtitle, phone, company |
| `find_person_by.email` | No | Search HubSpot by email before creating (default: `true`) |
| `find_person_by.linkedin_url` | No | Search HubSpot by LinkedIn URL before creating (default: `true`) |

**Response (200):**
```json
{
  "hubspot_contact_id": "123456789",
  "contact_created": true
}
```

**Error responses:** `400` — Missing/invalid `person_id` or person has no account when `sync_account_association` is true. `401` — Invalid API key. `404` — Person not found.

---

## Sequences API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/sequences` | List sequences |
| POST | `/api/v1/sequence` | Create sequence |
| GET | `/api/v1/sequence/:id/description` | Get Markdown summary (steps + metadata) |
| GET | `/api/v1/sequence/:id/metrics` | Get per-step metrics |
| POST | `/api/v1/sequence/:id/activate` | Activate sequence |
| POST | `/api/v1/sequence/:id/deactivate` | Deactivate sequence |
| POST | `/api/v1/sequence/:id/add-people` | Add people to sequence |

### List Sequences

Returns a paginated list of sequences in your workspace with summary statistics.

```
GET /api/v1/sequences
```

**Headers:**

| Header | Required | Description |
|--------|----------|-------------|
| `X-Tiga-Auth` | Yes | Your API key |
| `Tiga-Pagination` | No | JSON: page, page_size, sort_by, sort_order |
| `Tiga-Filter` | No | JSON: search_term, filter |

**Response fields:**

| Field | Type | Description |
|-------|------|-------------|
| `ID` | uuid | Sequence UUID |
| `Name` | string | Sequence name |
| `PlayType` | string | Type: sequence, flow, or signal-list-build |
| `Owner` | string | Sequence owner name |
| `OwnerId` | uuid | Sequence owner UUID |
| `IsEnabled` | boolean | Whether currently active |
| `ActivePeople` | integer | People currently active in the sequence |
| `NeedsApproval` | integer | Tasks waiting for approval |
| `RunningTasks` | integer | Currently running tasks |
| `steps_exist` | boolean | Whether sequence has at least one step |
| `TotalCount` | integer | Total matching sequences (for pagination) |
| `UpdatedAt` | datetime | Last updated timestamp |

**Example request:**
```bash
curl -X GET "https://app.tigalabs.com/api/v1/sequences" \
  -H "X-Tiga-Auth: YOUR_API_KEY" \
  -H "Tiga-Pagination: {\"page\":1,\"page_size\":2,\"sort_by\":\"updated_at\",\"sort_order\":\"desc\"}"
```

### Create a Sequence

```
POST /api/v1/sequence
```

**Request body:**

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Sequence display name |
| `play_type` | No | `"sequence"` (default), `"flow"`, or `"signal-list-build"` |
| `business_goal` | No | Free-text description of the goal |

```json
{
  "name": "Q3 Outbound — Mid-Market",
  "play_type": "sequence",
  "business_goal": "Book meetings with VP Sales at mid-market SaaS companies"
}
```

**Response:** `201 Created` — full sequence object. Save the `ID` — required for all subsequent step and people operations.

---

### Get Sequence Description

Returns a human-readable Markdown summary of the sequence and its steps, including each step's UUID. Use this to discover step IDs before adding, updating, or deleting steps.

```
GET /api/v1/sequence/:id/description
```

**Response:** `200 OK` — `text/markdown`. Includes sequence name, ID, type, status (Active/Inactive), creation date, and a numbered list of steps with action type, schedule, and UUID.

```
# Q3 Outbound — Mid-Market

**ID:** `<sequence-uuid>`
**Type:** sequence
**Status:** Inactive
**Created:** 2026-05-01

## Steps (2)

1. **Initial Outreach** (SequenceEmail) — immediately (weekdays only)
   ID: `<step-uuid-1>`

2. **LinkedIn Follow-up** (LinkedInMessage) — after 3 days (weekdays only)
   ID: `<step-uuid-2>`
```

---

### Activate / Deactivate a Sequence

Sequences must be **inactive** to modify steps. Use deactivate before making step changes, then reactivate when done.

```
POST /api/v1/sequence/:id/activate
POST /api/v1/sequence/:id/deactivate
```

Both endpoints are idempotent — calling activate on an already-active sequence (or deactivate on an already-inactive one) returns `200` without error.

**Activate response (`200`):**
```json
{"message": "sequence activated", "is_enabled": true}
```

**Deactivate response (`200`):**
```json
{"message": "sequence deactivated", "is_enabled": false}
```

**Activate error responses:**

| Status | Meaning |
|--------|---------|
| `400` | Sequence has no steps, missing required field, or incomplete email content |
| `428` | Tasks are still updating from a previous change — retry after a few seconds |

---

### Get Metrics for a Sequence

Returns per-step performance metrics for a sequence.

```
GET /api/v1/sequence/:id/metrics
```

**Path parameters:** `id` (uuid) — Sequence UUID

**Query parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sortBy` | string | Sort field (default: step_name) |
| `sortOrder` | string | asc or desc (default: asc) |
| `startDate` | string | ISO 8601 datetime filter start |
| `endDate` | string | ISO 8601 datetime filter end |

**Response:** Three top-level keys:

| Field | Type | Description |
|-------|------|-------------|
| `activity` | array | Per-step activity metrics |
| `pending` | array | Per-step pending task counts |
| `duration` | integer | Estimated sequence duration in days |

**Activity object fields:** `step_id`, `step_name`, `step_type`, `added_to_sequence`, `email_send`, `email_open`, `email_reply`, `email_click`, `email_bounce`, `li_message_send`, `li_connection_send`, `li_connection_accepted`, `call_logged`

### Add People to a Sequence

Adds people to an active sequence. Duplicates are automatically excluded.

```
POST /api/v1/sequence/:id/add-people
```

**Path parameters:** `id` (uuid) — Sequence UUID (must be enabled)

**Request body:**

| Field | Type | Description |
|-------|------|-------------|
| `people_ids` | uuid[] | Person UUIDs to add |
| `excluded_people_ids` | uuid[] | Optional. UUIDs to exclude |
| `filter` | object | Optional. Dynamic people filter |
| `step_id` | uuid | Optional. Step to add at (default: first) |
| `list_id` | uuid | Optional. Scope to list members |
| `search_term` | string | Optional. Free-text search |
| `select_all` | boolean | Optional. Select all matching people |

**Response:**

| Field | Type | Description |
|-------|------|-------------|
| `new_people` | uuid[] | Successfully added UUIDs |
| `duplicates` | uuid[] | Already-in-sequence UUIDs (skipped) |

**Error responses:** `400` — Invalid ID or body. `404` — Sequence not found or not enabled.
