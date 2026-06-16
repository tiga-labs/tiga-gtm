# HubSpot Sync Reference

Sync Tiga people and accounts to HubSpot using Tiga's native HubSpot integration endpoints. These endpoints handle the OAuth token management, contact matching, and field mapping internally — you do not need to call the HubSpot API directly.

**Before starting:** Read `tiga-gtm/docs/api-reference.md` for full endpoint details, including the HubSpot API section. For reading the raw HubSpot OAuth token to call HubSpot's API directly, use the Secrets Access endpoints documented there instead.

## Workflow A: Sync a Person to HubSpot

**Use when:** You have one or more Tiga people you want to create or update as HubSpot contacts. Tiga will search for an existing contact by email and/or LinkedIn URL before creating a new one, then push the person's current field values.

1. **Identify the person(s) to sync** — you need their Tiga `person_id` (UUID). If you don't have it, look them up first:
```bash
curl -X GET "https://app.tigalabs.com/api/v1/people" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Tiga-Filter: {\"search_term\": \"<name or email>\"}"
```

2. **Sync the person to HubSpot:**
```bash
curl -X POST "https://app.tigalabs.com/api/v1/hubspot/create-or-update-contact" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "person_id": "<tiga-person-uuid>",
    "find_person_by": {
      "email": true,
      "linkedin_url": true
    }
  }'
```

   **Key request fields:**

   | Field | Required | Notes |
   |---|---|---|
   | `person_id` | Yes | Tiga person UUID |
   | `hubspot_owner_id` | No | HubSpot owner ID to assign — **only applied on new contact creation** |
   | `sync_account_association` | No | If `true`, also finds/creates the HubSpot company and links the contact to it. Person must have an account in Tiga. |
   | `field_mappings` | No | Custom tiga-field → hubspot-field map (e.g. `{"title": "jobtitle"}`). Omit to use defaults: email, firstname, lastname, hs_linkedin_url, jobtitle, phone, company |
   | `find_person_by.email` | No | Search HubSpot by email before creating (default: `true`) |
   | `find_person_by.linkedin_url` | No | Search HubSpot by LinkedIn URL before creating (default: `true`) |

3. **Check the response:**
```json
{
  "hubspot_contact_id": "123456789",
  "contact_created": true
}
```
   - `contact_created: true` — a new HubSpot contact was created
   - `contact_created: false` — an existing contact was found and updated

4. **For bulk syncs** — loop through person IDs and POST for each. There is no batch endpoint; call sequentially or in a small parallel pool.

### With account association

To also sync the person's company to HubSpot and link them:
```bash
curl -X POST "https://app.tigalabs.com/api/v1/hubspot/create-or-update-contact" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "person_id": "<tiga-person-uuid>",
    "sync_account_association": true,
    "find_person_by": {
      "email": true,
      "linkedin_url": true
    }
  }'
```
The person must have an account associated in Tiga or the request returns `400`.

### With custom field mappings

To control exactly which Tiga fields map to which HubSpot properties:
```bash
curl -X POST "https://app.tigalabs.com/api/v1/hubspot/create-or-update-contact" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "person_id": "<tiga-person-uuid>",
    "field_mappings": {
      "email_address": "email",
      "first_name": "firstname",
      "last_name": "lastname",
      "title": "jobtitle",
      "phone": "phone",
      "linkedin_url": "hs_linkedin_url"
    }
  }'
```
When `field_mappings` is provided, only the mapped fields are sent to HubSpot. Omit it to use built-in defaults.

## Workflow B: Fetch HubSpot List Members as Tiga People

**Use when:** You want to read the contacts from a HubSpot list by name and get them back as Tiga-compatible people objects (e.g. to inspect, filter, or feed into a downstream workflow).

1. **Fetch the list members:**
```bash
curl -X GET "https://app.tigalabs.com/api/v1/hubspot/list-members?list_name=My+List+Name" \
  -H "X-Tiga-Auth: $TIGA_API_KEY"
```

   **Query parameters:**

   | Parameter | Required | Notes |
   |---|---|---|
   | `list_name` | Yes | Exact name of the HubSpot list (case-sensitive) |

2. **Check the response:**
```json
{
  "people": [
    {
      "crm_id": "12345678",
      "first_name": "Jane",
      "last_name": "Smith",
      "email_address": "jane@acme.com",
      "linkedin_url": "https://www.linkedin.com/in/janesmith",
      "title": "VP of Sales",
      "phone": "+14155550100",
      "city": "San Francisco",
      "state": "CA",
      "country": "United States",
      "account_domain": "Acme Corp"
    }
  ]
}
```

   **Field notes:**
   - `crm_id` — the HubSpot contact object ID
   - `account_domain` — populated from the HubSpot `company` property (the company name string, not a domain)
   - All other zero-value fields (e.g. `id`, `account_id`) are omitted — these contacts have not been imported into Tiga
   - The list name must match exactly; use `GET /api/hubspot/lists?searchTerm=<name>` (internal API) to look up names if needed

## Workflow C: Add Tiga People to a HubSpot List

**Use when:** You have one or more Tiga people (by `person_id`) and want to add them to a HubSpot list. Tiga will find or create each contact in HubSpot using email/LinkedIn, then enroll them in the list.

1. **Add people to the list by HubSpot list ID:**
```bash
curl -X POST "https://app.tigalabs.com/api/v1/hubspot/add-to-list" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "person_ids": ["<tiga-person-uuid>", "<tiga-person-uuid>"],
    "list_id": "<hubspot-list-id>"
  }'
```

   **Or by list name** (Tiga resolves the name to a HubSpot list ID automatically — exact match required):
```bash
curl -X POST "https://app.tigalabs.com/api/v1/hubspot/add-to-list" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "person_ids": ["<tiga-person-uuid>"],
    "list_name": "My HubSpot List"
  }'
```

   **Request fields:**

   | Field | Required | Notes |
   |---|---|---|
   | `person_ids` | Yes | Array of Tiga person UUIDs |
   | `list_id` | Conditional | HubSpot list ID — use this if known, avoids extra lookup |
   | `list_name` | Conditional | Exact HubSpot list name — required if `list_id` omitted |

   At least one of `list_id` or `list_name` must be provided.

2. **Check the response:**
```json
{
  "list_id": "12345",
  "added": 3,
  "failed": 0
}
```
   - `added` — number of people successfully enrolled in the list
   - `failed` — number that could not be added (person not found, HubSpot API error, etc.)
   - Returns `400` if none of the people could be added

### Notes
- If a person doesn't have a `crm_id` in Tiga, the endpoint will attempt to find or create a HubSpot contact by email/LinkedIn before adding them to the list.
- Only MANUAL lists support membership adds via the HubSpot API. Attempting to add to a DYNAMIC list will result in failures.
- To look up a HubSpot list ID by name beforehand, use `GET /api/v1/hubspot/list-members?list_name=<name>` (Workflow B) which will fail fast with a clear error if the name is not found.
