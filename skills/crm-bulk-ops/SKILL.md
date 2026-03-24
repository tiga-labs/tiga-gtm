---
name: crm-bulk-ops
description: "Build Go web applications that perform bulk CRM operations via the Tiga API (app.tigalabs.com). Use this skill whenever the user wants to build a reusable tool or web app for batch CRM work — cleaning names, enriching contacts in bulk, adding signal columns, syncing data, or any repeatable CRM operation that needs a UI with progress tracking, stop/resume, and undo. Also trigger when the user says 'build me a tool for...', 'I need an app to bulk update...', 'create a web UI for CRM cleanup', or wants a standalone Go application for CRM data processing. Note: for one-off CRM hygiene tasks (not building a tool), use crm-ops instead."
---

# CRM Bulk Ops Tool Builder

Build Go web applications that connect to CRMs (Salesforce, HubSpot) via the Tiga API and perform bulk operations with a real-time web UI. This skill is for **building reusable tools** — for one-off CRM hygiene workflows executed directly via API, use the **crm-ops** skill instead.

## When to use this skill

- User wants to **build a tool** (Go web app) that reads/writes CRM data in bulk
- User wants a web UI with progress tracking, stop/resume, and undo for CRM operations
- Common tools: clean account names, waterfall enrich contacts, add AI signal columns, sync CRM fields, deduplicate records

## Architecture

Every tool built with this skill follows the same pattern:

```
project/
├── main.go        # Go server: API handlers, CRM logic, worker pool
├── index.html     # Embedded single-page UI (dark theme)
├── .env           # TIGA_API_KEY (never hardcode)
├── go.mod
└── crm_ops_log.csv  # Generated at runtime — tracks all processed records
```

### Core components

1. **Tiga API client** — authenticates with `X-Tiga-Auth` header, fetches CRM OAuth tokens, calls utility/enrichment/signals endpoints
2. **CRM client** — uses OAuth token from Tiga to talk directly to Salesforce REST API or HubSpot API
3. **Worker pool** — concurrent goroutines for processing (default: 5 workers for API calls)
4. **Batch API** — Salesforce Composite API or HubSpot batch endpoints for bulk writes (default: 100 per batch)
5. **CSV logger** — every record processed gets a row with timestamp, operation, CRM ID, before/after values, and errors
6. **Stop/Resume** — cancellable context, CSV-based progress tracking for resume from where you left off
7. **Web UI** — embedded HTML with status bar, progress, action buttons (scan/apply/undo/stop/resume), results table

## Step-by-step build process

### 1. Understand the operation

Ask the user:
- **Which CRM?** Salesforce or HubSpot (determines token endpoint and API format)
- **What object?** Accounts, Contacts/People, Deals, etc.
- **What operation?** Clean names, enrich, add signals, sync fields, etc.
- **What Tiga endpoints?** Match the operation to the right Tiga API (see `references/tiga-api.md`)

### 2. Scaffold the project

```bash
mkdir <project-name> && cd <project-name>
go mod init <project-name>
go get github.com/joho/godotenv
```

Create `.env`:
```
TIGA_API_KEY=<user's key>
```

### 3. Build main.go

Follow the pattern in `references/go-template.md`. The template covers:

- **Configuration** — env vars, constants, Tiga base URL
- **CSV logging** — init, append, read processed IDs for resume
- **HTTP helper** — `apiDo()` logs every external API call with method, URL, status, bytes
- **Tiga auth** — fetch CRM OAuth token, trim trailing slashes from instance URLs
- **CRM query** — paginated reads (Salesforce SOQL or HubSpot search API)
- **Processing** — worker pool with configurable concurrency
- **CRM write** — batch updates via Composite API (SF) or batch API (HS)
- **Handlers** — scan, apply, undo, stop, reset, status
- **State machine** — idle → scanning → scanned → applying → applied, with stopped state for pause/resume

### 4. Build index.html

Dark-themed single-page app with:
- Status bar with colored dot (idle/working/done/stopped/error)
- Progress bar during operations
- Action buttons: Scan, Stop, Resume, Restart, Apply, Undo
- Stats cards: total records, to change, applied
- Results table: old value → new value
- Error display section
- Polls `/api/status` every second during operations

### 5. Configure launch.json for preview

Create `.claude/launch.json`:
```json
{
  "version": "0.0.1",
  "configurations": [
    {
      "name": "<project-name>",
      "runtimeExecutable": "go",
      "runtimeArgs": ["run", "."],
      "port": 8080
    }
  ]
}
```

## CRM-specific patterns

### Salesforce

- **Token**: `GET /api/v1/current-org/salesforce-oauth-token` → returns `access_token` + `instance_url`
- **Always trim trailing slash** from `instance_url` before building URLs
- **Query**: `GET {instance_url}/services/data/v59.0/query?q={SOQL}` — paginate via `nextRecordsUrl`
- **Single update**: `PATCH {instance_url}/services/data/v59.0/sobjects/{Object}/{Id}`
- **Batch update**: `POST {instance_url}/services/data/v59.0/composite` — up to 25 subrequests per call (use `allOrNone: false`)
  - Note: SF Composite API limit is 25, not 200. For larger batches, chunk into groups of 25.
- **Auth header**: `Authorization: Bearer {access_token}`

### HubSpot

- **Token**: `GET /api/v1/current-org/hubspot-oauth-token` → returns `access_token`
- **Base URL**: `https://api.hubapi.com`
- **Query**: `POST /crm/v3/objects/{objectType}/search` with filters
- **Single update**: `PATCH /crm/v3/objects/{objectType}/{id}`
- **Batch update**: `POST /crm/v3/objects/{objectType}/batch/update` — up to 100 per call
- **Auth header**: `Authorization: Bearer {access_token}`

## Operation-specific patterns

### Clean account/person names
- Tiga endpoint: `POST /api/v1/util/clean-account-name` or `POST /api/v1/util/clean-person-name`
- Use worker pool (5 concurrent) for scanning since each name is an independent API call
- Compare cleaned name to original — only flag changes

### Waterfall enrich contacts
- Tiga endpoint: `POST /api/v1/people/enrich-person` → returns `enrich_id`
- Poll: `GET /api/v1/enrich/{id}` until `data_import_status` is not "Running"
- Required fields: `first_name`, `last_name`, `company_name`
- Optional but accuracy-boosting: `person_linkedin_url`, `domain`
- Async — submit all enrichments, then poll in batches

### Add AI signal columns
- Create signal: `POST /api/v1/signal` with `computed_config` containing prompt
- Create or use a list: `POST /api/v1/lists` with `object_type` and `list_signals`
- Add members: `POST /api/v1/lists/{id}/add-members`
- Run signals: `POST /api/v1/lists/{id}/run-all-signal`
- Poll status: `POST /api/v1/lists-signal/bulk-status`

### Sync CRM fields
- Query both Tiga and CRM for the same records
- Diff field values
- Apply updates to whichever side is stale

## Key implementation details

- **Never hardcode API keys** — always use `.env` + `godotenv`
- **Log every API call** — `[API] METHOD URL -> STATUS (BYTES)` format
- **CSV log every record** — columns: timestamp, operation, crm_id, old_value, new_value, error
- **Trim trailing slashes** from all base URLs returned by APIs
- **Handle pagination** — both SF (`nextRecordsUrl`) and HS (`after` cursor)
- **Use `context.WithCancel`** for stop/resume — check cancellation between each item or batch
- **Resume reads CSV** to build a set of already-processed IDs, then skips them
- **Embed index.html** with `//go:embed` — single binary deployment
- **State machine** uses `sync.Mutex` — never hold the lock during API calls

## Reference files

- `tiga-gtm/docs/api-reference.md` — Complete Tiga API endpoint reference (canonical version)
- `references/tiga-api.md` — Condensed API reference for quick lookup during tool building
- `references/go-template.md` — Full Go code template with all patterns
