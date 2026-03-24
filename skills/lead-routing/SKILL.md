---
name: lead-routing
description: "Route and filter leads using the Tiga API. Use this skill whenever the user wants to filter inbound leads against ICP criteria, check against customer blacklists, route leads to salespeople by territory or segment, handle website visitor triggers (RB2B), or find CEO connections for executive intros. Also trigger when the user says 'qualify these leads', 'route to the right rep', 'filter out existing customers', 'a visitor hit our website', or any task about deciding what to do with incoming leads."
---

# Lead Routing Skill

Filter, qualify, and route leads using Tiga signals and sequences.

**Before starting:** Read `tiga-gtm/docs/api-reference.md` for endpoint details. Read `tiga-gtm/docs/merge-fields.md` for signal prompt variables. Read `tiga-gtm/docs/async-patterns.md` for polling patterns.

**Related skills:** After routing, use **outreach** to enroll qualified leads in sequences. Workflow E (CEO Connection) uses the same Find People Agent + enrich pattern as **contact-discovery**.

---

## Workflow A: Inbound ICP + Blacklist Filtering

**Use when:** You have inbound leads and want to filter them through ICP whitelist criteria and a customer blacklist before adding qualified leads to a sequence.

### Steps

1. **Create ICP Fit signal:**
```json
POST /api/v1/signal
{
  "label": "ICP Fit Check",
  "is_computed_column": true,
  "type": "text",
  "computed_config": {
    "type": "gpt",
    "prompt": "Does {{.AccountName}} ({{.AccountWebsite}}) match our ICP? Criteria: <describe ICP - industry, size, geography, etc.>. Answer yes or no with a 1-sentence reason.",
    "is_account_insight": true,
    "can_use_web_search": true,
    "word_limit": 50
  }
}
```

2. **Create Customer Blacklist signal:**
```json
POST /api/v1/signal
{
  "label": "Customer Blacklist Check",
  "is_computed_column": true,
  "type": "text",
  "computed_config": {
    "type": "gpt",
    "prompt": "Is {{.AccountName}} ({{.AccountWebsite}}) an existing customer? Check against: <list customer domains or criteria>. Answer yes (existing customer - do not contact) or no (not a customer - safe to contact).",
    "is_account_insight": true,
    "can_use_web_search": false,
    "word_limit": 30
  }
}
```

3. **Run both signals on the inbound list** and poll to completion.

4. **Filter** — Keep leads where:
   - ICP Fit = "yes"
   - Customer Blacklist = "no" (not an existing customer)

5. **Add qualified leads to a sequence:**
```bash
curl -X POST "https://app.tigalabs.com/api/v1/sequence/<sequence-id>/add-people" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"people_ids": ["<person-id-1>", "<person-id-2>"]}'
```

---

## Workflow B: Signal-Based CRM Routing

**Use when:** You want to run location/size/industry signals on prospects and create CRM entries routed to the appropriate salesperson based on signal values.

### Steps

1. **Create routing signals** — e.g., company location, company size, industry:
```json
POST /api/v1/signal
{
  "label": "Company Region",
  "is_computed_column": true,
  "type": "text",
  "computed_config": {
    "type": "gpt",
    "prompt": "What region is {{.AccountName}} ({{.AccountWebsite}}) headquartered in? Answer one of: Northeast, Southeast, Midwest, West, International.",
    "is_account_insight": true,
    "can_use_web_search": true,
    "word_limit": 20,
    "temperature": 0.1
  }
}
```

2. **Run signals on the prospect list** and poll to completion.

3. **Read signal values** for each account/person.

4. **Route based on signal output** — Map signal values to salespeople:
   - Northeast → Salesperson A
   - Southeast → Salesperson B
   - West → Salesperson C
   - etc.

5. **Create CRM entries** — Get OAuth token and create records assigned to the appropriate salesperson via CRM API:
   - `GET /api/v1/current-org/hubspot-oauth-token` or
   - `GET /api/v1/current-org/salesforce-oauth-token`

---

## Workflow C: Signal-Based Lead Routing

**Use when:** You want to route leads to different sequences or lists based on signal values.

### Steps

1. **Create routing signals** (same as Workflow B, step 1).

2. **Run signals** and poll to completion.

3. **Read signal values** and categorize leads.

4. **Create destination lists** for each route:
```json
POST /api/v1/lists
{"list": {"name": "Route A - Northeast - 2026-03-20", "object_type": "person"}}
```

5. **Add leads to appropriate lists** via `POST /api/v1/lists/:id/add-members`.

6. **Optionally add to route-specific sequences** via `POST /api/v1/sequence/:id/add-people`.

---

## Workflow D: Website Visitor Trigger (RB2B)

**Use when:** A website visitor is identified (e.g., via RB2B) and you want to automatically qualify and add them to a sequence.

### Steps

1. **Create the person in Tiga:**
```bash
curl -X POST "https://app.tigalabs.com/api/v1/people" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "first_name": "<first>",
    "last_name": "<last>",
    "email_address": "<email>",
    "title": "<title>",
    "account_name": "<company>",
    "website": "<domain>"
  }'
```

2. **Run ICP Fit Check signal** on the person's account (Workflow A, steps 1-3).

3. **Run Customer Blacklist Check** (Workflow A, step 2).

4. **If qualified** (ICP fit = yes, not a customer):
   - Add to sequence: `POST /api/v1/sequence/:id/add-people`
   - Or add to a qualified visitors list for batch processing

5. **If not qualified** — Skip or add to a monitoring list.

---

## Workflow E: CEO Connection

**Use when:** A new account enters the pipeline and you want to find the CEO for a CEO-to-CEO introduction.

### Steps

1. **Find the CEO** using Find People Agent:
```bash
curl -X POST "https://app.tigalabs.com/api/v1/agent/find-people" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "contact_description": "CEO or Founder at <company name>",
    "model": "gpt-5.4-2026-03-05"
  }'
```

2. **Poll for results** — `GET /api/agent/find-people/:id/status` until complete.

3. **Enrich the CEO contact:**
```bash
curl -X POST "https://app.tigalabs.com/api/v1/people/enrich-person" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "first_name": "<first>",
    "last_name": "<last>",
    "company_name": "<company>",
    "person_linkedin_url": "<linkedin>",
    "title": "CEO"
  }'
```

4. **Poll enrichment** until complete.

5. **Add to CEO outreach sequence** or flag for manual CEO-to-CEO introduction.
