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

**Response shape:**
```json
{
  "is_running_signals_for_list": true,
  "is_running_signals_for_page": false,
  "signal_status_map": {
    "<account-id>": {
      "<signal-id>": {
        "custom_column_id": "<signal-id>",
        "label": "Signal Label",
        "value": "The computed result text",
        "status": 1,
        "dependencies_missing": [],
        "has_running_job": false,
        "has_pending_job": false
      }
    }
  },
  "signal_status_progress": {
    "total_complete": 42,
    "total_members": 250,
    "percentage_completed": 17
  }
}
```

**Key:** The status map is nested as `signal_status_map[account_id][signal_id]`, NOT `signal_status_map[signal_id][account_id]`.

**Status values (in each signal entry):**
- `0` — Not computed yet
- `1` — Done (success) — `value` field contains the result
- `2` — Failed
- `3` — N/A (signal not applicable, e.g. missing merge field dependency)

**Important: status 3 = missing dependencies.** If `dependencies_missing` includes a field like `"AccountWebsite"`, the signal will NOT compute. Ensure the required merge field is populated on the account (e.g., set `website` via `PUT /api/v1/account/:id`) before running signals. Status 3 is terminal — re-running `run-all-signal` will NOT retry N/A signals; you must create a new signal.

**Signal computation rate:** Approximately 1-2 signals complete per 10-second interval. For 250 accounts × 4 signals = 1000 pairs, expect 60-90 minutes. Set poll timeout accordingly.

Poll until all statuses are non-zero (1, 2, or 3).

## Reusing Signals

Signals persist across runs. Use `GET /api/v1/signals` (returns a JSON array) to find existing signals by label before creating duplicates. However, **cached signal results (status 1 or 3) are not re-computed** when you call `run-all-signal` again. If you need fresh results (e.g., after fixing a missing dependency), delete the old signal via `DELETE /api/v1/signal/:id` and create a new one.
