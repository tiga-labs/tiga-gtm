---
name: list-building
description: "Build GTM lists — target accounts and the people at them — using the Tiga API. Use this skill whenever the user wants to build a target account list (TAL), find companies to target, search for accounts matching an ICP, find lookalike companies, turn a natural language description into a structured prospect list, import conference company lists or scraped pages, find people at companies by role or title, enrich contacts with email and phone via waterfall enrichment, pull contacts from LinkedIn or Sales Navigator queries, enrich a local CSV/Excel/JSON file of people with LinkedIn data, or import the people who reacted to a LinkedIn post. Also trigger when the user mentions Apollo search, firmographics, account discovery, territory list builds, or says: 'build me a list', 'build me a TAL', 'build a territory list for my rep', 'find me companies like X', 'find me the VP of...', 'who works at X', 'get contact info for...', 'enrich these leads', 'add LinkedIn data to this file', 'who liked/reacted to this post'. NOT for detecting whether existing CRM contacts changed jobs (use crm-ops) and NOT for defining or running AI signals on lists you already have (use signals)."
---

# List Building Skill

Every GTM motion starts with a list. This skill builds them: identify the target **accounts** first, then find the right **people** at them, then enrich and hand off.

**Before starting:** Read `references/api-reference.md` for endpoint details and `tiga-gtm/docs/async-patterns.md` for polling patterns (Find People Agent, Waterfall Enrich).

**Related skills:** After the list is built, use **signals** to score/prioritize, **sequence-builder** + **outreach** to act on it, **flow-builder** to split it across reps. For contacts already in the CRM (job changes, stale data), use **crm-ops**.

---

## Operating principles

1. **Accounts first, then people.** Settle which companies you're targeting before searching for anyone at them. Even when the user leads with a title ("find me VPs of Eng"), pin down the account universe first.

2. **Search Apollo first.** Tiga proxies Apollo's database via `POST /api/v1/apollo-organization-search` and `POST /api/v1/apollo-people-search`. The API is fast and returns results **without** paid enrichment — people results carry name/title/company but no verified email or phone. That's desirable: the goal of the outreach usually dictates slimming or prioritizing the list before you pay to enrich it. Full filter and response detail: `references/apollo-search.md`. Use the Find People Agent (`POST /api/v1/agent/find-people`) only as a fallback for fuzzy, descriptive queries that Apollo filters can't express.

3. **Work in scripts and CSV files.** Build and iterate locally — it's flexible and doesn't muddy up Tiga or the CRM until the list is ready to commit. Create Tiga accounts/lists/people only in the commit phase (see Follow-ups).

4. **Always report found AND not-found.** When building from named accounts, keep a record of every account where no contacts matched. The final report has two halves: "here's what we found" and "here's what we couldn't find." This builds trust.

5. **Ask the user if they would like to enrich the list last.** Waterfall enrich last

---

## Step 0: Intake — goal and ICP

Ask before building (skip anything the user has already answered):

**What is the list for?**
- An **outreach sequence**? How long will it run, and what step types — LinkedIn, email, phone? This dictates list size and which fields matter (phone steps mean enrichment must resolve phone numbers; LinkedIn steps need profile URLs).
- A **territory list build**? Then coverage and segmentation matter more than per-contact depth.

**What is the ideal customer profile?**
- Titles and roles targeted
- What kind of businesses they sell to (industry / vertical)
- Company size (employee count) and revenue ranges
- Geo bounds — do they only do business in certain regions?
- **How many people per company?** Large enterprises can have many people in the same role. Agree on a per-account cap and how to focus on the right ones (seniority, department, region).
- Do they already know the **named accounts** — and even the titles/roles — they want to reach? (If yes → Workflow 2.)

---

## Choosing a build

| You have | Build | Workflow |
|---|---|---|
| An ICP or a natural-language description of the target market | Accounts from Apollo | 1 |
| Named accounts (often with known titles/roles) | People at those accounts | 2 |
| A handful of best-fit customers | Lookalike accounts | 3 |
| LinkedIn post URL(s) | Post reactors → people list | 4 |
| Company names from a conference or scraped page | Accounts from the list | 5 |
| A local file of people needing LinkedIn data | File enrichment | 6 |

Workflows 1, 3, and 5 usually feed Workflow 2 — that's the accounts-first pipeline.

---

## Workflow 1: ICP → Account List

**Use when:** You have a defined ICP (or a prose description of one) and need the account universe.

1. **Translate the ICP to Apollo filters.** From a prose description, extract industry, employee range, revenue, geography, and technologies first:
   - Employee count → `organization_num_employees_ranges` (e.g. `["50,200"]`)
   - Revenue → `revenue_range[min]` / `revenue_range[max]`
   - Geography → `organization_locations`
   - Industry → `q_organization_keyword_tags`
   - Technologies → `currently_using_any_of_technology_uids`

2. **Search Apollo:**
```bash
curl -X POST "$TIGA_BASE/api/v1/apollo-organization-search?organization_num_employees_ranges[]=50,200&organization_locations[]=United%20States&q_organization_keyword_tags[]=saas&page=1&per_page=25" \
  -H "X-Tiga-Auth: $TIGA_API_KEY"
```
   (`TIGA_BASE` defaults to `https://app.tigalabs.com`; the key always comes from the environment — never hardcode it.) Organization search params go in the query string, not the body. Full filter options: `references/apollo-search.md`.

3. **Paginate** (`page: 2`, `3`, ...) until you have enough accounts or results thin out. Start broad, then tighten filters based on result quality.

4. **Write to CSV** — one row per account: name, domain, linkedin_url, employee count, location. Dedupe by domain. Don't create Tiga accounts yet.

5. **Optionally validate with an ICP Fit Check signal** when the search came from a fuzzy prompt (runs after committing to Tiga — see Follow-ups):
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

6. **Continue to Workflow 2** to find the people, unless this is an accounts-only (territory) build.

---

## Workflow 2: Named Accounts → People

**Use when:** You know the accounts (from the user, or from Workflows 1/3/5) and need the right people at them. This is the canonical flow.

1. **Collect the account domains** — from the user's named-account list, a Workflow 1/3/5 CSV, or an existing Tiga list.

2. **Search Apollo for people** — batch domains into one call (`q_organization_domains_list` accepts up to 1,000):
```bash
curl -X POST "$TIGA_BASE/api/v1/apollo-people-search" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "person_titles": ["VP of Engineering", "Director of Engineering"],
    "person_seniorities": ["vp", "director"],
    "q_organization_domains_list": ["acme.com", "globex.com", "initech.com"],
    "page": 1,
    "per_page": 100
  }'
```
   Results include name, title, company, and LinkedIn URL — **not** verified email/phone. That comes later via waterfall enrich, after the list is slimmed.

3. **Apply the per-company cap** from intake. At large accounts many people share a role — keep the agreed number per account, preferring seniority, department, and region fit.

4. **Track the misses.** Record every input domain that returned zero matching people. The final report always shows both tables: accounts with contacts found, and accounts where nothing matched (with the count).

5. **Fallback — Find People Agent** for fuzzy or Sales-Navigator-style descriptive queries Apollo filters can't express:
```bash
curl -X POST "$TIGA_BASE/api/v1/agent/find-people" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "contact_description": "Head of Data Engineering at enterprise healthcare companies in the Northeast US, 500+ employees",
    "model": "gpt-5.4-2026-03-05"
  }'
```
   Async — capture `status_id`, then poll `GET $TIGA_BASE/api/agent/find-people/<status-id>/status` (note: no `/v1/` in the status path) every 5-10s until `status` is `"Complete"` or starts with `"Error"`; timeout at 420s. Valid models: `gpt-5.4-2026-03-05`, `gpt-5.2-2025-12-11`, `gpt-5.1-2025-11-13`.

6. **Write to CSV** — first_name, last_name, title, company, domain, linkedin_url. Enrichment is a follow-up action, not part of the build.

**Recurring pulls:** to keep a list fresh, re-run this workflow on a cadence and dedupe against people already in Tiga (`GET /api/v1/people` with a search filter) before enriching.

---

## Workflow 3: Seed Customers → Lookalikes

**Use when:** The user gives you some of their customers and wants more companies like them.

1. **Profile the seeds.** Create a Firmographic Summary signal and run it across the seed accounts (create a list with the seeds, attach, run, poll — mechanics in the **signals** skill):
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

2. **Synthesize the ICP.** Read the signal outputs and identify what the seeds share. Translate into Apollo filters (industry keywords, employee ranges, technologies).

3. **Search Apollo** with the synthesized ICP (Workflow 1, steps 2-4).

4. **Exclude the seeds and existing customers** by domain (see Follow-ups).

5. **Validate** with an ICP Fit Check signal (Workflow 1, step 5), then continue to Workflow 2 for people.

---

## Workflow 4: LinkedIn Post Reactors

**Use when:** The user has LinkedIn post URL(s) (or URNs / numeric activity ids) and wants the people who reacted as enriched contacts in a Tiga list — a tactical build. For people by role/title, use Workflow 2 instead.

`POST /api/v1/people/import-from-post-reactions` fetches everyone who reacted, de-dupes them, creates the people, and queues waterfall enrichment. **Critical quirk:** it returns `201` immediately with `total_people: 0`, and there is **no job-status endpoint** — track progress by polling the list's member count until it stabilizes; enrichment keeps settling for a few minutes after, so re-export later to catch more emails.

Use the bundled script — it runs the whole flow (submit → poll → CSV export):

```bash
export TIGA_API_KEY=...                       # required
export TIGA_BASE=https://app.tigalabs.com     # or the user's host
scripts/import_post_reactors.sh "<post_url>" ["list name"]
```

Env knobs: `LIST_ID` (append to an existing list), `MAX_LIST`, `POLL_TIMEOUT`, `POLL_INTERVAL`.

Full endpoint spec (request fields, response shape, error strings, `Tiga-Filter`/`Tiga-Pagination` headers, polling pattern): `references/import-post-reactions.md`.

---

## Workflow 5: Conference / Scraped Company List → Accounts

**Use when:** You have company names (a conference attendee-company list, a logos section, a directory page) and want an account list from them.

1. **Parse to CSV** — extract company names and domains from the raw input; resolve missing domains (Apollo org search by `q_organization_name` works); dedupe by domain.
2. **Optionally validate** — if the list is broad, run an ICP Fit Check signal (Workflow 1, step 5) after commit and keep only the "yes" rows.
3. **Continue to Workflow 2** for people, or commit as an accounts-only list (see Follow-ups).

---

## Workflow 6: Enrich a Local File with LinkedIn Data

**Use when:** The user provides a CSV/TSV/Excel/JSON file of people and wants LinkedIn profile data appended to each row (no Tiga list involved).

1. **Inspect the file** and confirm the LinkedIn URL column (usually `linkedin_url`, `linkedin`, `profile_url`, or `li_url`). If ambiguous or missing, ask — do not proceed without a confirmed URL column.
2. **Run the enrichment script** — full Python reference implementation in `references/enrich-local-file.md`. Output format matches input; original columns are preserved; LinkedIn fields are appended.
3. For large files (500+ rows), warn the user about API costs before running.

---

## Follow-ups: after the list is built

Common next actions once the CSV looks right — apply the ones the goal calls for:

- **Exclude customers.** Remove existing customers before any outreach: check the CRM (**crm-ops** can pull HubSpot lists; Tiga accounts via `GET /api/v1/accounts` with search) and ask the user whether there are other accounts to exclude. Dedupe by domain against the exclusion set.

- **Verify individual emails.** Before enrolling contacts in a sequence you can check whether an email address is deliverable without running the full waterfall enrich flow. One credit per call:
```bash
curl -X POST "$TIGA_BASE/api/v1/verify-email" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email": "jane@acme.com"}'
```
  Response: `is_valid` (`true`/`false`), `status` (`valid`, `invalid`, `catch-all`, `unknown`, etc.), and `sub_status` (reason when invalid). Skip contacts where `is_valid` is `false` and `status` is `invalid`. Keep `catch-all` contacts — those domains accept all mail so validity can't be determined. Full spec: `docs/api-reference.md` → *Email Verification API*.

- **Waterfall enrich.** Once you know you want the contact data, Tiga's waterfall enrich is the best way to get verified email + phone. Submit every person, collect `enrich_id`s, then poll in parallel:
```bash
curl -X POST "$TIGA_BASE/api/v1/people/enrich-person" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "first_name": "<first_name>",
    "last_name": "<last_name>",
    "company_name": "<account_name>",
    "domain": "<domain>",
    "person_linkedin_url": "<person_linkedin>",
    "title": "<title>"
  }'
```
   Poll `GET $TIGA_BASE/api/v1/enrich/<enrich-id>` every 5-10s until `data_import_status` is not `"Running"`. Enrichment creates the person in Tiga and links them to their account — capture `person_id` for downstream steps.

- **Commit to Tiga.** Create a list (`POST /api/v1/lists` with `object_type` `account` or `person`), create accounts (`POST /api/v1/account` — handle `409 Conflict` by looking up the existing record) or let enrichment create the people, then `POST /api/v1/lists/:id/add-members` with `object_ids` (not `member_ids`). Verify after add-members: `GET /api/v1/accounts` or `GET /api/v1/people` with `Tiga-Filter: {"list_id":"<id>"}` — `total_count` must be > 0 before handing off to signals or sequences.

- **Segment by territory.** Splitting lists is common — mostly by geo, sometimes by other parameters (size band, vertical, owner). Split the CSV or create per-territory Tiga lists. For routing to reps, use **flow-builder**.

- **Run signals.** Large lists can be prioritized by finding signals (funding, hiring, tech stack — the **signals** skill). Also a great vector for outreach messaging, but not always necessary.

- **Enroll in a sequence.** Hand off to **outreach** (`POST /api/v1/sequence/:id/add-people`).
