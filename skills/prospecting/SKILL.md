---
name: prospecting
description: "Build target account lists (TAL) using the Tiga API. Use this skill whenever the user wants to find companies to target, build a TAL, search for accounts matching an ICP, find lookalike companies, import conference attendee lists, or turn a natural language description into a structured prospect list. Also trigger when the user mentions Apollo search, firmographics, account discovery, 'find me companies like X', or any task about identifying which companies to go after."
---

# Prospecting Skill

Build target account lists (TALs) from various starting points using Tiga + Apollo APIs.

**Before starting:** Read `tiga-gtm/docs/api-reference.md` for endpoint details. Read `tiga-gtm/docs/merge-fields.md` when creating signal prompts.

**Next steps after prospecting:** Once you have a TAL, use the **contact-discovery** skill to find people at those accounts, or the **signals** skill to score/filter them first.

---

## Workflow A: ICP → Target Account List

**Use when:** You have a defined ICP (firmographics, technographics, industry, headcount, geography) and want to build a qualified TAL.

### Steps

1. **Translate ICP to Apollo filters:**
   - Firmographics → `organization_num_employees_ranges`, `revenue_range`
   - Geography → `organization_locations`
   - Industry → `q_organization_industry_tag_ids`
   - Company name → `q_organization_name`

2. **Search Apollo for matching accounts:**
```bash
curl -X POST "https://app.tigalabs.com/api/v1/apollo-organization-search" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "organization_num_employees_ranges": ["50,200"],
    "organization_locations": ["United States"],
    "q_organization_industry_tag_ids": ["<apollo-industry-id>"],
    "page": 1,
    "per_page": 25
  }'
```
   Full filter options: https://docs.apollo.io/reference/organization-search

3. **Paginate** through results (`page: 2`, `3`, ...) until you have enough accounts or results thin out.

4. **Create a Tiga list:**
```bash
curl -X POST "https://app.tigalabs.com/api/v1/lists" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"list": {"name": "TAL - <ICP Name> - 2026-03-20", "object_type": "account"}}'
```

5. **Create accounts** from Apollo results (deduplicate by domain):
```bash
curl -X POST "https://app.tigalabs.com/api/v1/account" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "<org.name>",
    "domain": "<org.primary_domain>",
    "linkedin_url": "<org.linkedin_url>"
  }'
```
   Handle `409 Conflict` — account already exists; retrieve existing ID via `GET /api/v1/accounts` with search.

6. **Add accounts to list:**
```bash
curl -X POST "https://app.tigalabs.com/api/v1/lists/<list-id>/add-members" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"object_ids": ["<account-id-1>", "<account-id-2>"]}'
```

---

## Workflow B: Prompt → Target Account List

**Use when:** You have a natural-language description of your target market but no structured ICP yet.

### Steps

1. **Extract ICP attributes from the prompt** — Parse the user's description into:
   - Industry / vertical
   - Employee count range
   - Revenue range
   - Geography
   - Key technologies
   - Business signals (growth stage, funding, hiring patterns)

2. **Run Apollo search** using extracted attributes (see Workflow A, steps 2-3). Start broad, then tighten filters based on result quality.

3. **Create accounts and list** (Workflow A, steps 4-6).

4. **Layer ICP validation signals** — Create an ICP Fit Check signal to validate each account:
```json
{
  "label": "ICP Fit Check",
  "is_computed_column": true,
  "type": "text",
  "computed_config": {
    "type": "gpt",
    "prompt": "Does {{.AccountName}} ({{.AccountWebsite}}) match this target profile: <paste ICP description>? Answer yes or no with a 1-sentence reason.",
    "is_account_insight": true,
    "can_use_web_search": true,
    "expiration_in_days": 30,
    "word_limit": 60
  }
}
```

5. **Run signal on the list**, poll to completion, and filter — keep only accounts where the signal returns "yes".

---

## Workflow C: Seed Accounts → Lookalikes

**Use when:** You have a list of known best-fit customers and want to find more companies like them.

### Steps

1. **Create a Firmographic Summary signal:**
```json
{
  "label": "Firmographic Summary",
  "is_computed_column": true,
  "type": "text",
  "computed_config": {
    "type": "gpt",
    "prompt": "Describe {{.AccountName}} ({{.AccountWebsite}}) in terms of: industry, business model, employee count range, target customer, and key technologies used. Be specific.",
    "is_account_insight": true,
    "can_use_web_search": true,
    "word_limit": 100
  }
}
```

2. **Run the signal across seed accounts** — Create a list with seeds, attach the signal, run it, and poll to completion.

3. **Synthesize ICP** — Read all signal outputs and identify common patterns across seeds. Translate these into structured Apollo search filters (industry tags, employee ranges, keywords).

4. **Search Apollo** with the synthesized ICP (Workflow A, steps 2-3).

5. **Exclude existing customers** — Filter out domains already in Tiga via `GET /api/v1/accounts` with search.

6. **Validate lookalikes** — Run an ICP Fit Check signal (Workflow B, step 4) on the new accounts.

7. **Create final TAL** with validated lookalike accounts.

---

## Workflow D: Conference List → TAL

**Use when:** You have a list of companies attending a conference and want to build a TAL from them.

### Steps

1. **Create accounts** for each conference company:
```bash
curl -X POST "https://app.tigalabs.com/api/v1/account" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "<company>", "domain": "<domain>", "linkedin_url": "<linkedin>"}'
```
   Handle `409 Conflict` for duplicates.

2. **Create a Tiga list:**
```json
POST /api/v1/lists
{"list": {"name": "Conference - <event name> - 2026-03-20", "object_type": "account"}}
```

3. **Add all accounts to the list** via `POST /api/v1/lists/:id/add-members`.

---

## Workflow E: Scraped Page → TAL

**Use when:** You have company names/domains scraped from a web page (e.g., a logos section, a directory) and want to build a TAL.

### Steps

1. **Parse the scraped data** — Extract company names and domains from the raw input.

2. **Create accounts** for each company (same as Workflow D, step 1). Use domain as the dedup key.

3. **Create a Tiga list** and add all accounts.

4. **Optionally validate with ICP signals** — If the scraped list is broad, run an ICP Fit Check signal (Workflow B, step 4) to filter down to relevant accounts.
