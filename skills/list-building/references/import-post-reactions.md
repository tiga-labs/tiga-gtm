# Import People from LinkedIn Post Reactions

Turn the reactors on a LinkedIn post into enriched Tiga contacts. Tiga fetches everyone who reacted, de-dupes them, creates the people in the workspace, and runs waterfall enrichment to fill in emails — all from a single post URL.

The canonical reference implementation is `scripts/import_post_reactors.sh` (in the list-building skill directory). It runs the whole flow (submit → poll → CSV export) and handles URNs and appending to an existing list. Copy and adapt it rather than rebuilding from scratch.

**Before starting:** Skim `tiga-gtm/docs/api-reference.md` for the broader People API surface. Note that the `import-from-post-reactions` endpoint is **not** in that doc — the full spec is captured below; trust this doc for it.

## When this applies

Use it when the user has one or more LinkedIn **post** URLs (or post URNs / numeric activity ids) and wants the people who reacted as contacts. Post URLs look like:

```
https://www.linkedin.com/posts/<author>_<slug>-activity-7466133283324579840-HWnp
```

`ugcPost` and `share` URLs work too, as does a bare URN (`urn:li:activity:7466133283324579840`) or numeric id (`7466133283324579840`).

If the user wants people by **role/title** at target accounts, or from a Sales Navigator search, that's list-building Workflow 2 (Named Accounts → People), not this import.

## The key thing to understand: it's async with no status endpoint

`POST /api/v1/people/import-from-post-reactions` returns `201 Created` **immediately** with a `job_id` and `list_id`, but `total_people` and `total_accounts` are always `0` in that response — the real work happens in a background job that collects reactors, creates people, and queues enrichment.

There is **no job-status endpoint** (a `/status` route 404s). The way to track progress is to poll the People endpoint filtered by `list_id` and watch the member count climb until it stops growing. Then a second background pass (waterfall enrich) keeps filling in emails for a few minutes after the count settles — so re-exporting a little later catches more emails.

## Workflow

1. **Confirm intent.** Get the post URL(s) and a sensible list name (default to something like `Post Reactors - <author> - <date>`). If the user has several posts and wants them in one list, plan to create the list on the first import and append the rest via `list_id`.

2. **Submit the import.** `POST /api/v1/people/import-from-post-reactions` with `{name, post_url}`. Capture `list_id` and `job_id` from the response.

3. **Poll the list until it stabilizes.** `GET /api/v1/people` with a `Tiga-Filter` header of `{"list_id":"<id>"}`, reading `total_count`. Poll every ~15s; consider it done when the count is non-zero and unchanged across two reads, with a timeout (~10 min). Don't poll a `/status` URL — it doesn't exist.

4. **Export.** Page through the list (`Tiga-Pagination` header) and write the fields the user cares about to CSV. Reactor rows include `first_name`, `last_name`, `title`, `email_address`, `phone`, `linkedin_url`, `account_name`, `account_domain`. Some reactors come back without an email (enrichment couldn't resolve one) — that's expected; surface the count of how many got emails.

5. **Tell the user enrichment is still settling.** More emails resolve in the background after the count stops growing; offer to re-export the same `list_id` in a few minutes.

The list created here is a normal Tiga people list, so downstream skills compose directly: `outreach` to enroll the reactors in a sequence, `signals` to research/score them, `crm-ops` to sync.

## Endpoint spec — POST /api/v1/people/import-from-post-reactions

Headers: `X-Tiga-Auth: <key>`, `Content-Type: application/json`.

Request body:

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Name of the list to import reactors into. A new list is created unless `list_id` is given. |
| `post_url` | string | yes* | Full LinkedIn post URL. `ugcPost` and `share` URLs are accepted. |
| `post_urn` | string | yes* | The post's URN or numeric id (`7468009810714669056` or `urn:li:activity:7468009810714669056`). Alternative to `post_url`. |
| `list_id` | uuid | no | Existing list to append reactors to. When omitted, a new list is created from `name`. |
| `import_history_id` | uuid | no | Existing import-history record to associate with. A new one is created when omitted. |
| `max_list` | integer | no | Max reactors to import. Defaults to `1500`. |

\* Provide at least one of `post_url` or `post_urn`. Either field also accepts the other format.

Response (`201`):

```json
{
  "job_id": "9975fcfe-9da8-45d8-96cc-0c4ac12bbbba",
  "collection_job_id": "9975fcfe-9da8-45d8-96cc-0c4ac12bbbba",
  "import_history_id": "49f95f65-f6dc-410f-b79c-c98450b373d2",
  "list_id": "1c604039-a180-4bac-9fec-26a5eeffa943",
  "list_name": "Post Reactors",
  "total_accounts": 0,
  "total_people": 0
}
```

Errors: `400` if the body can't be parsed, if `name` is missing (`"list name is required"`), or if no post resolves from `post_url`/`post_urn` (`"post_urn or linkedin post url is required"`).

### Reading the imported reactors

```bash
curl -sS -X GET "$TIGA_BASE/api/v1/people" \
  -H "X-Tiga-Auth: $TIGA_API_KEY" \
  -H 'Tiga-Filter: {"list_id":"<list-id>"}' \
  -H 'Tiga-Pagination: {"page":1,"page_size":100}'
```

`Tiga-Filter` also accepts `search_term`, `sequence_id`, `filter`. `Tiga-Pagination` accepts `page`, `page_size`, `sort_by`, `sort_order`. The response is `{"rows": [...], "total_count": N}`.

## API basics

- **Base URL** is environment-specific. Production is `https://app.tigalabs.com`; users may run against their own host (e.g. `http://localhost:3000` in dev). Honor whatever the user gives you — the script reads it from `TIGA_BASE`.
- **Auth** is the `X-Tiga-Auth: $TIGA_API_KEY` header on every request. The key lives in the user's environment / `.env`; never hardcode it.

## Using the bundled script

```bash
export TIGA_API_KEY=...                 # required
export TIGA_BASE=https://app.tigalabs.com   # or the user's host
scripts/import_post_reactors.sh "<post_url>" ["list name"]
```

It submits the import, polls until the count settles, and writes `reactors_<list_id>.csv`. Useful env knobs: `LIST_ID` (append to an existing list instead of creating one), `MAX_LIST`, `POLL_TIMEOUT`, `POLL_INTERVAL`. The script detects whether the positional arg is a URL or a URN and sends the right field.
