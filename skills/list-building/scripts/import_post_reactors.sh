#!/usr/bin/env bash
#
# import_post_reactors.sh — Extract the people who reacted to a LinkedIn post
# into a Tiga list, poll until they're imported + enriched, and dump to CSV.
#
# This is the canonical reference implementation for the import-post-reactions
# skill. Copy and adapt it; the flow is:
#
#   POST /api/v1/people/import-from-post-reactions   (async — returns job_id + list_id)
#   GET  /api/v1/people  (filtered by list_id)       (poll — no job-status endpoint exists)
#
# The import endpoint returns immediately with total_people/total_accounts = 0;
# a background job fetches the reactors, de-dupes them, creates the people, and
# queues a waterfall-enrich job to fill in emails. So the only way to know it's
# done is to watch the list's member count until it stops growing.
#
# Usage:
#   ./import_post_reactors.sh <post_url_or_urn> [list_name]
#
# Environment:
#   TIGA_API_KEY   Tiga API key                       (required)
#   TIGA_BASE      API base URL                        (default: https://app.tigalabs.com)
#   LIST_ID        Append to an existing list instead  (optional; skips list creation)
#   MAX_LIST       Max reactors to import              (default: 1500)
#   POLL_TIMEOUT   Seconds to wait for the job         (default: 600)
#   POLL_INTERVAL  Seconds between polls               (default: 15)
#
# Examples:
#   TIGA_API_KEY=xxxx ./import_post_reactors.sh \
#     "https://www.linkedin.com/posts/andreyee_agents-...-activity-7466133283324579840-HWnp"
#
#   # Append a second post's reactors into the same list:
#   TIGA_API_KEY=xxxx LIST_ID=9a5f...e84e ./import_post_reactors.sh 7468009810714669056

set -euo pipefail

TIGA_BASE="${TIGA_BASE:-https://app.tigalabs.com}"
MAX_LIST="${MAX_LIST:-1500}"
POLL_TIMEOUT="${POLL_TIMEOUT:-600}"
POLL_INTERVAL="${POLL_INTERVAL:-15}"

POST="${1:-}"
LIST_NAME="${2:-Post Reactors - $(date +%Y-%m-%d)}"

err() { echo "Error: $*" >&2; exit 1; }

[ -n "${TIGA_API_KEY:-}" ] || err "TIGA_API_KEY is not set"
[ -n "$POST" ] || err "usage: $0 <post_url_or_urn> [list_name]"
command -v jq >/dev/null 2>&1 || err "jq is required (brew install jq)"

auth=(-H "X-Tiga-Auth: $TIGA_API_KEY")

# Either field accepts a full URL or a URN, but route to post_url when it looks
# like a URL and post_urn otherwise (numeric id or urn:li:activity:...).
if [[ "$POST" == http* ]]; then
  post_field="post_url"
else
  post_field="post_urn"
fi

# Build the request body — include list_id only when appending to an existing list.
body=$(jq -n \
  --arg name "$LIST_NAME" \
  --arg post "$POST" \
  --arg field "$post_field" \
  --argjson max "$MAX_LIST" \
  --arg list_id "${LIST_ID:-}" \
  '{name: $name, max_list: $max} + {($field): $post}
   + (if $list_id == "" then {} else {list_id: $list_id} end)')

# --- 1. Submit the import job -------------------------------------------------
echo "Submitting import for: $POST" >&2
submit=$(curl -sS -X POST "$TIGA_BASE/api/v1/people/import-from-post-reactions" \
  "${auth[@]}" -H "Content-Type: application/json" -d "$body")

list_id=$(echo "$submit" | jq -r '.list_id // empty')
job_id=$(echo "$submit"  | jq -r '.job_id // empty')
[ -n "$list_id" ] || err "no list_id in response: $submit"

echo "  list_id: $list_id" >&2
echo "  job_id:  $job_id" >&2

# When appending to an existing list, capture the starting count so we wait for
# *new* reactors rather than mistaking the pre-existing members for completion.
baseline=0
if [ -n "${LIST_ID:-}" ]; then
  baseline=$(curl -sS -X GET "$TIGA_BASE/api/v1/people" "${auth[@]}" \
              -H "Tiga-Filter: {\"list_id\":\"$list_id\"}" \
              -H 'Tiga-Pagination: {"page":1,"page_size":1}' | jq -r '.total_count // 0')
  echo "  starting from $baseline existing members" >&2
fi

# --- 2. Poll the list until the reactor count stabilizes ----------------------
# There is no job-status endpoint (it 404s); polling the list is the documented
# way. Wait until the count grows past the baseline and then holds steady across
# two reads, or until the timeout.
echo "Polling for reactors (timeout ${POLL_TIMEOUT}s)..." >&2
deadline=$(( $(date +%s) + POLL_TIMEOUT ))
prev=-1
count=0
while [ "$(date +%s)" -lt "$deadline" ]; do
  count=$(curl -sS -X GET "$TIGA_BASE/api/v1/people" "${auth[@]}" \
            -H "Tiga-Filter: {\"list_id\":\"$list_id\"}" \
            -H 'Tiga-Pagination: {"page":1,"page_size":1}' | jq -r '.total_count // 0')
  echo "  ...$count members in list" >&2
  if [ "$count" -gt "$baseline" ] && [ "$count" -eq "$prev" ]; then
    break
  fi
  prev="$count"
  sleep "$POLL_INTERVAL"
done

[ "$count" -gt "$baseline" ] || err "no new reactors before timeout (job may still be running; list_id=$list_id)"

# --- 3. Page through the list and write CSV -----------------------------------
# @csv quotes/escapes fields, so titles containing commas stay in one column.
out="reactors_${list_id}.csv"
echo "Writing $count members to $out" >&2
echo "first_name,last_name,title,email_address,phone,linkedin_url,account_name,account_domain" > "$out"

page=1
while :; do
  rows=$(curl -sS -X GET "$TIGA_BASE/api/v1/people" "${auth[@]}" \
           -H "Tiga-Filter: {\"list_id\":\"$list_id\"}" \
           -H "Tiga-Pagination: {\"page\":$page,\"page_size\":100}")
  n=$(echo "$rows" | jq '.rows | length')
  [ "$n" -gt 0 ] || break
  echo "$rows" | jq -r '.rows[] | [
      .first_name, .last_name, .title, .email_address,
      .phone, .linkedin_url, (.account_name // ""), (.account_domain // "")
    ] | @csv' >> "$out"
  [ "$n" -lt 100 ] && break
  page=$((page + 1))
done

echo "Done. $out ($(( $(wc -l < "$out") - 1 )) rows)" >&2
echo >&2
echo "Note: waterfall enrichment runs in the background, so more emails may" >&2
echo "resolve over the next few minutes. Re-run the export against list_id" >&2
echo "$list_id later to capture them." >&2
