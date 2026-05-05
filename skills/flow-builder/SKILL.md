---
name: flow-builder
description: "Build Tiga 'flow' play_type sequences end-to-end via the Tiga API using curl. Use this skill whenever the user wants to programmatically create or configure a flow (an agent flow / multi-step automation that imports, enriches, researches, filters, and routes leads), wire up steps like Import From HubSpot, Waterfall Enrich, LinkedIn Research, Account Fit (ICP), Run Signal, or Add To Sequence, or asks to script the construction of an inbound or webinar followup flow. Also trigger on: 'build me a flow', 'create an agent flow', 'set up a webinar inbound sequence', 'add a HubSpot import step', 'configure an ICP filter step', or any request to assemble a Tiga sequence with `play_type: flow` rather than the plain outreach `play_type: sequence`."
---

# Tiga Flow Builder

This skill captures everything needed to construct a `play_type: flow` Tiga sequence with configured steps via curl. Flows are different from regular outreach sequences — they're agent-style automations that feed people in (HubSpot, list, prompt), enrich/research them, gate them through filters and signals, and hand them off (to a sequence, list, webhook, etc.).

The canonical reference implementation is in `scripts/build_agent_flow.sh` — it creates a 6-step "Webinar agent flow" end to end. Use it as a template; copy and adapt the relevant blocks rather than rebuilding from scratch.

**Before starting:** Skim `tiga-gtm/docs/api-reference.md` for the broader Sequences API surface — but note that several endpoints and config schemas used here are NOT documented there. The undocumented pieces are captured below; trust this skill over the public docs where they conflict.

## When this skill applies

Use this skill when the user wants to script construction of a Tiga flow, especially when their request involves any of these step types:

- HubSpot list import (`SyncFromHubspotFeeder`)
- Inbound webhook trigger (`WebhookFeeder`) — for real-time form-submission flows
- Waterfall enrichment (`WaterfallEnrich`)
- LinkedIn research at person or account level (`LinkedInResearch`)
- ICP filter on company size / industry / revenue (`AccountIcpFilter`)
- Running a Tiga signal as a flow gate (`RunSignal`)
- Routing to another sequence by owner (`AddToSequence`)

If the user just wants to add people to an existing outreach sequence or write email copy, that's the `outreach` skill, not this one.

## Recommended flow shape for inbound

For real-time inbound (HubSpot form submissions, webhooks), the canonical chain is:

`WebhookFeeder` → `WaterfallEnrich` → `LinkedInResearch` (account-level) → `AccountIcpFilter` → `AddToSequence`

**Always run `LinkedInResearch` before `AccountIcpFilter`.** The ICP filter checks company industry/size/revenue, which often isn't populated on inbound contacts (a webinar form may only capture email/firstname/lastname). LinkedIn account research populates the account fields just-in-time so the ICP filter has data to match against. Without this step, the ICP filter rejects valid leads because the account is mostly empty.

For batch/list-based feeds (`SyncFromHubspotFeeder`, `ListFeeder`), the same ordering applies — research before filter.

## Workflow

1. **Confirm intent.** Get the flow name, the list of step types, and any per-step inputs the user has in mind (HubSpot list name, ICP industries/sizes, signal UUID, target followup sequence, etc.).
2. **Resolve external IDs first.** HubSpot list IDs come from the Tiga HubSpot OAuth proxy, then HubSpot's `/crm/v3/lists/search`. Signal UUIDs come from the user. Owner user IDs come from `GET /api/v1/sequences` (any sequence owned by them) or by asking.
3. **Create the flow shell.** `POST /api/v1/sequence` with `{name, play_type: "flow"}` returns the sequence object including `ID`.
4. **Add steps in order.** `POST /api/v1/sequence/:id/add-step?stepToAppendToId=<prev>` with `{action, step_name}`. The first step uses the zero UUID `00000000-0000-0000-0000-000000000000`. Capture each returned step `ID` to chain the next call.
5. **PATCH each step's config.** `PATCH /api/v1/step/:id` with the per-action config body. PATCH always returns `OK` (200) — there is **no validation feedback** and no read-back endpoint. Always tell the user to verify in the UI.
6. **Verify.** `GET /api/v1/sequence/:id/description` returns a markdown summary (step names + types in order). `GET /api/v1/sequence/:id/metrics` returns activity[] with `step_type` strings.

## API basics

- Base URL: `https://villageparkrecords.com` (or whatever the user has stored). Honor what's in their environment.
- Auth header: `X-Tiga-Auth: $TIGA_API_KEY` — the key lives in a `.env` file the user maintains.
- Content-Type: `application/json` for all POST/PATCH bodies.

### Endpoints actually exposed for flow construction

| Method | Path | Notes |
|---|---|---|
| `POST` | `/api/v1/sequence` | Create sequence. Body `{name, play_type, business_goal?}`. Returns full object with `ID`. |
| `POST` | `/api/v1/sequence/:id/add-step?stepToAppendToId=<prev_or_zero_uuid>` | Add step. Body `{action, step_name}`. Returns step object with `ID`. |
| `PATCH` | `/api/v1/step/:id` | Update step config. Body uses lowercase `config` key. Always 200 OK; no validation. |
| `GET` | `/api/v1/sequence/:id/description` | Markdown summary (step names/types/order). |
| `GET` | `/api/v1/sequence/:id/metrics` | Per-step activity; useful to discover `step_type` strings on existing flows. |
| `GET` | `/api/v1/current-org/hubspot-oauth-token` | OAuth token for direct HubSpot API calls. |

### NOT exposed (work around in UI)

- `DELETE /api/v1/sequence/:id` — 404. Sequences must be deleted in the Tiga UI.
- `GET /api/v1/step/:id` — 404. No way to read step config back via API; verify in UI.
- `POST /api/v1/step/:id` — 404 (only PATCH works for updates).

## Step action types and config schemas

Every config is wrapped: `{"config": {"<action_snake_case>": { ... }}}`. The inner key matches the action's snake_case name (e.g. `SyncFromHubspotFeeder` → `sync_from_hubspot`).

### `SyncFromHubspotFeeder` — Import From HubSpot

Resolve the HubSpot list ID first by getting the OAuth token from Tiga, then calling HubSpot's list search:

```bash
HS_TOKEN=$(curl -sS -H "X-Tiga-Auth: $TIGA_API_KEY" \
  "$BASE/api/v1/current-org/hubspot-oauth-token" | jq -r .access_token)
curl -sS -X POST -H "Authorization: Bearer $HS_TOKEN" -H "Content-Type: application/json" \
  -d '{"query":"Webinar Submissions","count":50}' \
  "https://api.hubapi.com/crm/v3/lists/search"
```

Config body for the step:

```json
{
  "config": {
    "sync_from_hubspot": {
      "list_id": "100",
      "object_type_id": "0-1",
      "field_mappings": {
        "person_mappings": {
          "first_name": "firstname",
          "last_name": "lastname",
          "email_address": "email",
          "title": "jobtitle",
          "phone": "phone",
          "mobile_phone": "mobilephone",
          "linkedin_url": "hs_linkedin_url",
          "city": "city",
          "state": "state",
          "country": "country",
          "account_name": "company"
        },
        "account_mappings": {}
      }
    }
  }
}
```

`object_type_id: "0-1"` is HubSpot's contact object. `list_id` is HubSpot's list ID as a string.

### `WebhookFeeder` — inbound webhook trigger

Use this instead of `SyncFromHubspotFeeder` when you need real-time enrollment (e.g. firing a flow the moment someone submits a HubSpot form, rather than polling a list every 15 minutes).

**Add-step body** (passes extra flags directly on add-step, not via PATCH):

```json
{
  "action": "WebhookFeeder",
  "step_name": "Webhook Feeder",
  "requires_human_approval": true,
  "can_run_on_weekends": false
}
```

**Config body** (PATCH `/api/v1/step/:id`):

```json
{
  "config": {
    "webhook_feeder": {
      "webhook_id": "<auto-uuid>",
      "output_type": "people"
    }
  }
}
```

The `webhook_id` is auto-generated by Tiga at add-step time and returned in the add-step response under `config.webhook_feeder.webhook_id`. Capture it from that response — there is no other way to retrieve it.

**Webhook URL pattern:** `https://villageparkrecords.com/wh/v1/<shortcode>` where `<shortcode>` is server-derived from `webhook_id` and **NOT exposed by any API endpoint**. The user must open the WebhookFeeder step in the Tiga UI and copy the URL — there is no programmatic way to discover it.

**Expected request body** (Tiga rejects with `400: must have "email_address" or "person_linkedin"` if shape is wrong):

| Field | Required | Notes |
|---|---|---|
| `email_address` | one of these two | Person's email |
| `person_linkedin` | one of these two | Person's LinkedIn URL |
| `first_name` | optional | |
| `last_name` | optional | |
| `title` | optional | |
| `phone` | optional | |
| `company_linkedin` | optional | Account's LinkedIn URL |
| `account_name` | optional | |
| `website` | optional | Account's domain |

The webhook returns `400: sequence not active or not found` until the flow's status is `Active` in the UI — that's how you confirm the URL is correct without enabling the flow.

### `WaterfallEnrich`

```json
{
  "config": {
    "waterfall_enrich": {
      "settings": {
        "providers": [
          {"name": "Findymail", "type": "findymail"},
          {"name": "Hunter.io", "type": "hunter"},
          {"name": "Prospeo", "type": "prospeo"},
          {"name": "Datagma", "type": "datagma"},
          {"name": "Dropcontact", "type": "dropcontact"}
        ],
        "is_linkedin_url_required": true,
        "is_email_address_required": true,
        "is_phone_number_required": false,
        "should_validate_with_zero_bounce": false
      },
      "flow_behavior": "continue_if_found"
    }
  }
}
```

`flow_behavior: "continue_if_found"` is "continue if enriched" in the UI — drops people who couldn't be enriched.

### `LinkedInResearch`

```json
{
  "config": {
    "linked_in_research": {
      "research_person": false,
      "research_account": true
    }
  }
}
```

Note the snake_case key is `linked_in_research` (with the underscore between `linked` and `in`), not `linkedin_research`.

### `AccountIcpFilter` — Account Fit

```json
{
  "config": {
    "account_icp_filter": {
      "company_sizes": ["51-200", "201-500", "501-1,000", "1001-5,000"],
      "revenues": [],
      "industries": ["Software", "Healthcare"],
      "allow_related_industries": false,
      "flow_behavior": "continue_if_match"
    }
  }
}
```

Valid `company_sizes` values are exact strings: `"1-10"`, `"11-50"`, `"51-200"`, `"201-500"`, `"501-1,000"`, `"1001-5,000"`, `"5,001-10,000"`, `"10,001+"`. Industries are free strings — match the UI's spelling.

### `RunSignal` — gate the flow on a Tiga signal

```json
{
  "config": {
    "run_signal": {
      "signal_id": "<signal-uuid>",
      "is_account_insight": true,
      "should_flow_if_signal_found": true,
      "flow_behavior": "continue_if_found"
    }
  }
}
```

Use this for territory routing, custom-fit checks, or any signal-based gate. Set `is_account_insight: false` for person-level signals.

### `AddToSequence` — hand off to another sequence (with owner routing)

```json
{
  "config": {
    "add_to_sequence": {
      "mode": "by_person_owner",
      "sequence_id": null,
      "sequence_name": "",
      "step_id": null,
      "step_name": "",
      "owner_to_sequence_mappings": [
        {
          "user_id": "<user-uuid>",
          "user_name": "Mike Ball",
          "sequence_id": "<target-sequence-uuid>",
          "sequence_name": "inbound followup",
          "step_id": null,
          "step_name": null
        }
      ]
    }
  }
}
```

`mode: "by_person_owner"` routes each person to a different sequence based on who owns them in the CRM — useful for distributing leads across reps. For a single-target hand-off, still use `by_person_owner` with one mapping (this is what the UI builds).

### Other observed action types (less common)

`ListFeeder`, `PromptFeeder`, `PromptAcctFeeder`, `ReadFileFeeder`, `VerifyEmail`, `AddToList`, `DataExport`, `WebhookNotification`, `FindPplOnLiForAcct`, `FindCntsForAcctAgent`. Plus the standard outreach types: `SequenceEmail`, `HtmlEmail`, `UserTask`, `LinkedInMessage`, `LinkedInConnect`. If a user wants one of these in a flow and you don't have the schema, ask them to add it once in the UI and paste the resulting step JSON — that's the fastest way to learn the config shape.

## Discovering unknown step config

If a user wants a step type that's not documented here:

1. Ask them to add it once in the UI on any test flow.
2. Have them paste the step JSON (the full object — they can grab it from network inspector or the UI's debug view).
3. The `Action` field gives the action_type string; the `config` field shows the schema.
4. Mirror that body in a PATCH call, substituting their values.

You can also enumerate `step_type` strings from existing flows via `GET /api/v1/sequence/:id/metrics` — every entry in `activity[]` includes `step_type`. This is how the original action_type set was discovered.

## Building a flow: minimum viable script

```bash
#!/usr/bin/env bash
set -euo pipefail
set -a; source .env; set +a

BASE="https://villageparkrecords.com"
AUTH="X-Tiga-Auth: $TIGA_API_KEY"
ROOT="00000000-0000-0000-0000-000000000000"

api() {
  local method=$1 url=$2 body=${3:-}
  if [[ -n "$body" ]]; then
    curl -sS -X "$method" -H "$AUTH" -H "Content-Type: application/json" -d "$body" "$url"
  else
    curl -sS -X "$method" -H "$AUTH" "$url"
  fi
}

# 1. Create flow
SEQ_ID=$(api POST "$BASE/api/v1/sequence" \
  '{"name":"My Flow","play_type":"flow"}' | jq -r .ID)

# 2. Add and capture each step
add_step() {
  api POST "$BASE/api/v1/sequence/$SEQ_ID/add-step?stepToAppendToId=$1" \
    "{\"action\":\"$2\",\"step_name\":\"$3\"}" | jq -r .ID
}
S1=$(add_step "$ROOT" SyncFromHubspotFeeder "Import")
S2=$(add_step "$S1" WaterfallEnrich "Enrich")
# ... etc

# 3. PATCH config on each step
api PATCH "$BASE/api/v1/step/$S2" \
  '{"config":{"waterfall_enrich":{...}}}'
```

See `scripts/build_agent_flow.sh` for the fully fleshed-out version with HubSpot list lookup, ICP defaults, and AddToSequence wiring.

## Wiring HubSpot to a `WebhookFeeder` (creating HubSpot assets)

When the user wants the script to set up the HubSpot side too — finding the form, creating a workflow that POSTs to the Tiga webhook — there are several quirks to know.

### Required HubSpot scopes

The default Tiga HubSpot OAuth grant does NOT include `forms` or `automation`. Both are required to:

- List/find forms via `GET /marketing/v3/forms` (needs `forms`)
- Create flows/workflows via `/automation/v3/workflows` or `/automation/v4/flows` (needs `automation`)

Have the user disconnect/reconnect HubSpot in Tiga settings to grant these. Verify scopes before doing any HubSpot work:

```bash
HS_TOKEN=$(curl -sS -H "X-Tiga-Auth: $TIGA_API_KEY" \
  "$BASE/api/v1/current-org/hubspot-oauth-token" | jq -r .access_token)
curl -sS "https://api.hubapi.com/oauth/v1/access-tokens/$HS_TOKEN" | jq '.scopes'
# Must include "forms" and "automation"
```

### Use v4 flows API, not v3 workflows

`POST /automation/v3/workflows` exists but supports only a fixed set of action types — `CUSTOM_CODE` is **not** in the v3 list. Use v4 flows (`POST /automation/v4/flows`) instead.

Field names also differ between v3 and v4. In v3 the form filter uses `form` (not `formId`). In v4 the form filter uses `formId`. Get this wrong and HubSpot silently strips the value — your workflow accepts ANY form submission instead of the one you wanted.

### v4 flow body for "form submission → custom code → Tiga webhook"

```json
{
  "name": "Webinar Form -> Tiga Inbound Flow",
  "isEnabled": false,
  "type": "CONTACT_FLOW",
  "objectTypeId": "0-1",
  "flowType": "WORKFLOW",
  "startActionId": "1",
  "nextAvailableActionId": "2",
  "enrollmentCriteria": {
    "shouldReEnroll": false,
    "listFilterBranch": {
      "filterBranches": [{
        "filterBranches": [],
        "filters": [{
          "formId": "<hubspot-form-uuid>",
          "operator": "FILLED_OUT",
          "filterType": "FORM_SUBMISSION"
        }],
        "filterBranchType": "AND",
        "filterBranchOperator": "AND"
      }],
      "filters": [],
      "filterBranchType": "OR",
      "filterBranchOperator": "OR"
    },
    "unEnrollObjectsNotMeetingCriteria": false,
    "reEnrollmentTriggersFilterBranches": [],
    "type": "LIST_BASED"
  },
  "actions": [{
    "type": "CUSTOM_CODE",
    "actionId": "1",
    "actionTypeId": "0-32",
    "actionTypeVersion": 0,
    "runtime": "NODE20X",
    "sourceCode": "<see below>",
    "inputFields": [
      {"name": "email",     "value": {"type": "OBJECT_PROPERTY", "propertyName": "email"}},
      {"name": "firstname", "value": {"type": "OBJECT_PROPERTY", "propertyName": "firstname"}},
      {"name": "lastname",  "value": {"type": "OBJECT_PROPERTY", "propertyName": "lastname"}}
    ],
    "outputFields": []
  }]
}
```

Critical detail: `inputFields` must use this exact shape — `{"name": ..., "value": {"type": "OBJECT_PROPERTY", "propertyName": ...}}`. Other shapes (`@type`, `propertySource`, `propertyDefinition`, top-level `propertyName`) all 400 or silently store empty fields. If `inputFields` is empty in the read-back, your custom code will run with `event.inputFields.* === undefined` and POST an empty body — that's the symptom: empty body at the webhook.

**Action type IDs to know:**
- `0-12` — Send a webhook (built-in; no body customization, sends fixed contact-properties shape)
- `0-32` — Custom code (use this for any custom body — like Tiga's expected schema)

`0-32` is `CUSTOM_CODE`; valid `runtime` values are `NODE20X`, `NODE16X`, `NODE12X`, `PYTHON39`, `PYTHON36` (NOT `NODE_20`, NOT `NODE20`).

Discover full action-type catalog via `GET /automation/v4/action-types`.

### Custom code template (HubSpot → Tiga webhook)

```javascript
const axios = require("axios");
exports.main = async (event, callback) => {
  const url = "https://villageparkrecords.com/wh/v1/<shortcode>";
  const body = {
    email_address: event.inputFields.email,
    first_name: event.inputFields.firstname,
    last_name: event.inputFields.lastname
  };
  console.log("Posting:", JSON.stringify(body));
  try {
    const resp = await axios.post(url, body, {headers: {"Content-Type": "application/json"}});
    callback({outputFields: {status: String(resp.status), response: JSON.stringify(resp.data).slice(0, 500)}});
  } catch (e) {
    const status = e.response ? e.response.status : 0;
    const data = e.response ? e.response.data : e.message;
    console.log("Error:", status, JSON.stringify(data));
    callback({outputFields: {status: String(status), response: JSON.stringify(data).slice(0, 500)}});
  }
};
```

`axios` is preinstalled in HubSpot's NODE20X runtime.

### Why not just use the built-in webhook action (`0-12`)?

It sends HubSpot's default contact-properties shape (e.g. `{vid, properties: {email: {value: "..."}, ...}}` or flat HubSpot field names like `email`/`firstname`). Tiga's webhook expects `email_address`/`first_name`/`last_name` and rejects the request with `400: Invalid Request must have "email_address" or "person_linkedin"`. Custom code is the simplest way to reshape the payload without a middleware.

### Forms that don't show up

`GET /marketing/v3/forms` only returns "marketing" forms. If you can't find the form there:

- Try `GET /forms/v2/forms` (legacy endpoint, broader coverage)
- The form ID is the same UUID across both APIs

### Cleaning up

- HubSpot v4 flows: `DELETE /automation/v4/flows/<id>` (returns 204)
- HubSpot v3 workflows: `DELETE /automation/v3/workflows/<id>` (returns 204)
- Tiga sequences: cannot be deleted via API — only in the UI

When iterating, make scripts idempotent by deleting prior HubSpot workflows with the same name, then reusing the existing Tiga flow if name+play_type match (since Tiga flows can't be deleted).

## Common gotchas

- **Steps are chained, not numbered.** Each step's `next_step_id` points to the following step. To insert at the start, use `stepToAppendToId=<zero-uuid>`. To append at the end, pass the previous step's ID.
- **Config keys are lowercase `config`, not `Config`.** The PATCH endpoint accepts both for top-level fields, but the inner `config` object on the step is canonically lowercase.
- **`action` in add-step is PascalCase; the inner config key is snake_case.** E.g., `action: "SyncFromHubspotFeeder"` but `config.sync_from_hubspot`.
- **PATCH silently 200s on bogus bodies.** No JSON schema validation — your only feedback is opening the step in the UI. After every config PATCH, recommend the user check the UI.
- **Don't try to delete sequences via API.** It 404s. Tell the user to delete in the UI.
- **Verify with `description` between adds.** If you suspect a step landed wrong, hit `/sequence/:id/description` for a quick markdown view of the chain.
- **Webhook URL is not retrievable via API.** After creating a `WebhookFeeder` step, `webhook_id` (UUID) is in the add-step response, but the `<shortcode>` portion of `https://villageparkrecords.com/wh/v1/<shortcode>` is server-derived and not in any response. The user must paste it from the UI.
- **HubSpot WEBHOOK action (`0-12`) ≠ Tiga's webhook schema.** Always use `CUSTOM_CODE` (`0-32`) when posting to Tiga so you can reshape `email`→`email_address`, `firstname`→`first_name`, `lastname`→`last_name`.
- **HubSpot `inputFields` shape is fragile.** The only working shape is `{"name": ..., "value": {"type": "OBJECT_PROPERTY", "propertyName": ...}}`. If your custom code receives `undefined` for everything, this is why.
- **Run `LinkedInResearch` before `AccountIcpFilter`.** Inbound forms rarely populate company industry/size; without account research populating those fields just-in-time, the ICP filter rejects valid leads.
