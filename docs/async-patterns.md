# Async Polling Pattern

Both the Waterfall Enrich and Find People Agent APIs are asynchronous. Use this pattern for all async operations:

```
1. POST to start job → capture id from response
2. Wait 3-5 seconds
3. GET status endpoint with id
4. If status is still running → wait 5-10 seconds, repeat step 3
5. If terminal status → proceed with results
6. If 420 seconds elapsed without completion → surface timeout error
```

## Terminal States

**Enrich API** (`GET /api/v1/enrich/:id`):
- Terminal: `data_import_status` = `"Person And Account Created"` (or any non-`"Running"` non-empty value)
- Still running: `data_import_status` = `"Running"`

**Find People Agent** (`GET /api/agent/find-people/:id/status`):
- Terminal success: `status` = `"Complete"`
- Terminal error: `status` starts with `"Error"`
- Still running: `status` = `"Running"`

## Batch Polling

When submitting multiple async jobs (e.g., enriching 20 contacts):

1. Submit all jobs first, collecting all IDs
2. Poll all IDs in a single loop rather than waiting for each sequentially
3. Remove completed IDs from the poll set
4. Continue until all IDs reach terminal state or timeout

## Signal Computation Polling

Signal computation on lists is also async. Use the bulk status endpoint:

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
- `3` — N/A (signal not applicable)

Poll until all statuses are non-zero (1, 2, or 3).

## Stable-Count Polling (no status endpoint)

Some background jobs have **no status endpoint at all** — e.g. `POST /api/v1/people/import-from-post-reactions` returns `201` immediately and a `/status` route 404s. For these, poll the observable side effect instead:

1. Poll the relevant collection endpoint (e.g. `GET /api/v1/people` with a `Tiga-Filter: {"list_id":"<id>"}` header), reading `total_count`
2. Poll every ~15 seconds
3. Consider the job done when the count is non-zero and unchanged across two consecutive reads
4. Time out after ~10 minutes
5. Note: secondary background passes (e.g. waterfall enrichment) may keep updating records after the count settles — re-read later for more complete data
