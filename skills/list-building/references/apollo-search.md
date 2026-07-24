# Apollo Search via the Tiga Proxy

Tiga proxies three Apollo.io endpoints: organization search, people search, and bulk match. Together they form the Apollo-native list-building path: find companies, find the people at them (free, no credits), slim the list, then reveal contact data for only the people you keep.

**Auth and base URL** follow the plugin-wide convention: every request sends `X-Tiga-Auth: $TIGA_API_KEY` (and `Content-Type: application/json` when there's a body). `TIGA_BASE` defaults to `https://app.tigalabs.com`; honor whatever host the user gives you. Never hardcode the key.

The proxies mirror Apollo's endpoints, so Apollo's full filter vocabulary applies. Authoritative parameter docs:

- Organization search: https://docs.apollo.io/reference/organization-search
- People search: https://docs.apollo.io/reference/people-api-search
- Bulk match (bulk people enrichment): https://docs.apollo.io/reference/bulk-people-enrichment

**Credits:** people search is free — it consumes no credits and returns no contact data. Bulk match consumes **50 credits per matched record**. An org that has hit its credit limit gets `402` from bulk match.

---

## Organization search — POST /api/v1/apollo-organization-search

Find companies matching an ICP. Parameters are passed as query strings, not a request body.

```bash
curl -X POST "$TIGA_BASE/api/v1/apollo-organization-search?organization_num_employees_ranges[]=50,200&organization_locations[]=United%20States&q_organization_keyword_tags[]=saas&page=1&per_page=25" \
  -H "X-Tiga-Auth: $TIGA_API_KEY"
```

### Common filters

| ICP attribute | Apollo filter | Notes |
|---|---|---|
| Company name | `q_organization_name` | Substring match on a specific name |
| Known domains | `q_organization_domains_list` | Up to 1,000 domains per call (no `www.` or `@`) |
| Apollo IDs | `organization_ids` | Exact Apollo organization IDs |
| Employee count | `organization_num_employees_ranges` | Array of `"min,max"` strings, e.g. `["50,200", "200,500"]` |
| Revenue | `revenue_range[min]` / `revenue_range[max]` | Integers, no currency symbols or commas |
| Geography (HQ) | `organization_locations` | Cities, states, or countries; `organization_not_locations` excludes |
| Industry | `q_organization_keyword_tags` | Keyword tags like `"saas"`, `"consulting"`, `"mining"` |
| Tech stack | `currently_using_any_of_technology_uids` | Apollo technology UIDs (underscored, e.g. `"salesforce"`) |
| Funding | `latest_funding_amount_range[min/max]`, `total_funding_range[min/max]`, `latest_funding_date_range[min/max]` | Integers; dates as `YYYY-MM-DD` |
| Hiring activity | `q_organization_job_titles`, `organization_job_locations`, `organization_num_jobs_range[min/max]`, `organization_job_posted_at_range[min/max]` | Companies with open roles |

### Pagination

`page` + `per_page` (max 100 per page; Apollo caps a search at 50,000 records — up to 500 pages). Paginate until you have enough accounts or results thin out.

**Quirk (verified):** a page can return fewer rows than `per_page` — even zero — while `pagination.total_entries` is large and later pages still have rows. Don't treat an empty page as the end of results; keep paginating and use `pagination.total_entries` / `total_pages` as the guide.

### Reading results

Response shape: `{"organizations": [...], "pagination": {"page", "per_page", "total_entries", "total_pages"}}`. Each organization carries the fields you need for an account CSV: `name`, `primary_domain`, `website_url`, `linkedin_url` (employee/location fields are present but often null). Dedupe by `primary_domain`.

---

## People search — POST /api/v1/apollo-people-search

Find people by title/seniority at specific companies. The workhorse of named-account builds. **Free — no credits consumed.**

This endpoint is a pure mirror of Apollo's People Search API: parameters are passed as **query strings** — it does **not** accept a JSON request body.

```bash
curl -X POST "$TIGA_BASE/api/v1/apollo-people-search?person_titles[]=sales%20manager&q_organization_domains_list[]=apollo.io&page=1&per_page=25" \
  -H "X-Tiga-Auth: $TIGA_API_KEY"
```

### Common filters

| Targeting | Apollo filter | Notes |
|---|---|---|
| Titles | `person_titles` | Array of title strings; partial/similar matches by default (`include_similar_titles` defaults to `true` — set `false` for exact matches only) |
| Seniority | `person_seniorities` | `owner`, `founder`, `c_suite`, `partner`, `vp`, `head`, `director`, `manager`, `senior`, `entry`, `intern` |
| Person location | `person_locations` | Where the person resides (cities/states/countries) |
| Email status | `contact_email_status` | `verified`, `unverified`, `likely to engage`, `unavailable` |
| Target accounts | `q_organization_domains_list` | **Up to 1,000 domains per call** — batch named accounts rather than one call per company |
| Company filters | `organization_ids`, `organization_locations`, `organization_num_employees_ranges`, `revenue_range[min/max]` | Same semantics as organization search |
| Tech stack | `currently_using_any_of_technology_uids`, `currently_using_all_of_technology_uids`, `currently_not_using_any_of_technology_uids` | Any / all / exclude variants |
| Keywords | `q_keywords` | Free-text narrowing |

Pagination: `page` + `per_page`, same 50,000-record cap (100 per page, up to 500 pages) as organization search.

### What you get back (and don't)

The response is **partial and obfuscated** — presence signals, not contact data. Each match in `people[]` carries:

- `id` — the Apollo person id. **This is the key output**: it's what you pass to bulk match to reveal the person.
- `first_name` and `last_name_obfuscated` (e.g. `"Sm***h"`) — no full last name.
- `title` (may be null) and an `organization` stub with `name` plus `has_*` flags.
- Presence flags — `has_email`, `has_city`, `has_state`, `has_country`, `has_direct_phone` — telling you what Apollo *could* reveal without exposing it.

**No email addresses, phone numbers, or LinkedIn URLs come back.** That's the point: people search is the free step for slimming and prioritizing. Once the list is down to the people you actually want, reveal them — either via `POST /api/v1/apollo-bulk-match` (below; Apollo-native, id → email) or via Tiga's waterfall enrich (`POST /api/v1/people/enrich-person`) when you also need phone numbers.

### Named-account hygiene

When searching against a domain list, diff the domains that appear in the results against the input list. Every domain with zero matches goes in the "couldn't find" half of the report — always show the user both halves.

---

## Bulk match — POST /api/v1/apollo-bulk-match

Reveal contact data (email addresses) for **up to 10 people per call** by matching against Apollo's Bulk People Enrichment API. Identify each person by whatever Apollo accepts — an `id` returned from people search, or `name` / `first_name`+`last_name` / `email` / `domain` / `organization_name` / `linkedin_url`. People are passed in a JSON request body.

**Costs 50 credits per matched record.** Confirm with the user before revealing a large list — a 100-person reveal is 10 calls and up to 5,000 credits.

```bash
curl -X POST "$TIGA_BASE/api/v1/apollo-bulk-match" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "details": [
      { "id": "APOLLO_PERSON_ID" },
      { "first_name": "Jane", "last_name": "Smith", "domain": "acme.com" }
    ],
    "reveal_personal_emails": true
  }'
```

### Body parameters

| Field | Required | Notes |
|---|---|---|
| `details` | Yes | Array of up to **10** person objects; fields are forwarded to Apollo as-is. Prefer `{"id": "..."}` from people search — it's the most precise match key |
| `reveal_personal_emails` | No | `true` to include personal email addresses in the matches. Defaults to `false` |

### Reading results

`matches[]` — one entry per matched person — carries the revealed contact data plus a full (un-obfuscated) profile: `email`, `email_status` (e.g. `"verified"`), `first_name`, `last_name`, `name`, `title`, `linkedin_url`, `city`/`state`/`country`, `organization`, and `employment_history`. Top-level counters summarize the spend: `total_requested_enrichments`, `unique_enriched_records`, `missing_records`, `credits_consumed`. Unmatched people cost nothing.

### Limits and errors

| Status | Condition |
|---|---|
| `400` | `details` has more than 10 entries, or `reveal_phone_number` was passed — **phone reveal is not supported** via the proxy (use Tiga waterfall enrich for phone) |
| `402` | The org has reached its credit limit |
