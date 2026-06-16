# Apollo Search via the Tiga Proxy

Tiga proxies two Apollo.io search endpoints. They are the fastest way to build a list: results come back immediately and **without paid enrichment**, so you can slim and prioritize before spending on waterfall enrich.

**Auth and base URL** follow the plugin-wide convention: every request sends `X-Tiga-Auth: $TIGA_API_KEY` and `Content-Type: application/json`. `TIGA_BASE` defaults to `https://app.tigalabs.com`; honor whatever host the user gives you. Never hardcode the key.

The proxy passes the JSON body through to Apollo, so Apollo's full filter vocabulary applies. Authoritative parameter docs:

- Organization search: https://docs.apollo.io/reference/organization-search
- People search: https://docs.apollo.io/reference/people-api-search

---

## Organization search — POST /api/v1/apollo-organization-search

Find companies matching an ICP.

```bash
curl -X POST "$TIGA_BASE/api/v1/apollo-organization-search" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "organization_num_employees_ranges": ["50,200"],
    "organization_locations": ["United States"],
    "q_organization_keyword_tags": ["saas"],
    "page": 1,
    "per_page": 25
  }'
```

### Common filters

| ICP attribute | Apollo filter | Notes |
|---|---|---|
| Company name | `q_organization_name` | Substring match on a specific name |
| Employee count | `organization_num_employees_ranges` | Array of `"min,max"` strings, e.g. `["50,200", "200,500"]` |
| Revenue | `revenue_range[min]` / `revenue_range[max]` | Integers, no currency symbols or commas |
| Geography (HQ) | `organization_locations` | Cities, states, or countries; `organization_not_locations` excludes |
| Industry | `q_organization_keyword_tags` | Keyword tags like `"saas"`, `"consulting"`, `"mining"` |
| Tech stack | `currently_using_any_of_technology_uids` | Apollo technology UIDs (underscored, e.g. `"salesforce"`) |
| Funding | `latest_funding_amount_range[min/max]`, `total_funding_range[min/max]` | Integers |
| Hiring activity | `q_organization_job_titles`, `organization_num_jobs_range[min/max]` | Companies with open roles |

### Pagination

`page` + `per_page` (max 100 per page; Apollo caps a search at 50,000 records). Paginate until you have enough accounts or results thin out.

**Quirk (verified):** a page can return fewer rows than `per_page` — even zero — while `pagination.total_entries` is large and later pages still have rows. Don't treat an empty page as the end of results; keep paginating and use `pagination.total_entries` / `total_pages` as the guide.

### Reading results

Response shape: `{"organizations": [...], "pagination": {"page", "per_page", "total_entries", "total_pages"}}`. Each organization carries the fields you need for an account CSV: `name`, `primary_domain`, `website_url`, `linkedin_url` (employee/location fields are present but often null). Dedupe by `primary_domain`.

---

## People search — POST /api/v1/apollo-people-search

Find people by title/seniority at specific companies. The workhorse of named-account builds.

```bash
curl -X POST "$TIGA_BASE/api/v1/apollo-people-search" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "person_titles": ["sales manager"],
    "q_organization_domains_list": ["apollo.io"],
    "page": 1,
    "per_page": 10
  }'
```

### Common filters

| Targeting | Apollo filter | Notes |
|---|---|---|
| Titles | `person_titles` | Array of title strings; pair with `include_similar_titles: false` for exact matches only |
| Seniority | `person_seniorities` | `owner`, `founder`, `c_suite`, `vp`, `director`, `manager`, `senior`, `entry`, `intern` |
| Person location | `person_locations` | Where the person resides (cities/states/countries) |
| Target accounts | `q_organization_domains_list` | **Up to 1,000 domains per call** — batch named accounts rather than one call per company |
| Company filters | `organization_locations`, `organization_num_employees_ranges`, `revenue_range[min/max]`, `currently_using_any_of_technology_uids` | Same semantics as organization search |
| Keywords | `q_keywords` | Free-text narrowing |

### What you get back (and don't)

Response shape: `{"people": [...], "contacts": [...], "pagination": {...}}`. Each person carries `first_name`, `last_name`, `name`, `title`, `linkedin_url`, `employment_history`, and `organization` (with `name` and `primary_domain`). **No usable contact data comes back** — `email` is a placeholder (`email_not_unlocked@domain.com`) and phone is null. That's the point: slim the list to the people you actually want, then resolve contact data with Tiga's waterfall enrich (`POST /api/v1/people/enrich-person`), which is the best source for verified email + phone.

### Named-account hygiene

When searching against a domain list, diff the domains that appear in the results against the input list. Every domain with zero matches goes in the "couldn't find" half of the report — always show the user both halves.
