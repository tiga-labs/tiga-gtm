#!/usr/bin/env bash
#
# engaged_people.sh — Pull the people behind sequence engagement metrics
# ("everyone who opened an email from a sequence I own") into a CSV, and
# optionally materialize them into a Tiga person list.
#
# This is the canonical reference implementation for the sequence-runner skill's
# engagement workflow. Copy and adapt it; the flow is:
#
#   GET  /api/v1/engagement/people   (paged via Tiga-Pagination)
#   POST /api/v1/lists               (only when LIST_NAME is set)
#   POST /api/v1/lists/:id/add-members
#
# By default the query scopes to sequences owned by the API key's user;
# set OWNER_ID to a user UUID or "all" for other scopes, or SEQUENCE_ID
# to target one sequence.
#
# Usage:
#   ./engaged_people.sh <metric[,metric...]> [output.csv]
#
#   metric: open | click | reply | bounce | send | li-reply | call
#           (comma-separated = OR semantics: open,click,reply)
#
# Environment:
#   TIGA_API_KEY   Tiga API key                                  (required)
#   TIGA_BASE      API base URL                    (default: https://app.tigalabs.com)
#   OWNER_ID       Sequence owner scope: uuid | me | all         (default: me)
#   SEQUENCE_ID    Scope to a single sequence                    (optional)
#   START_DATE     YYYY-MM-DD or full timestamp                  (optional)
#   END_DATE       Same formats; date-only = through end of day  (optional)
#   PAGE_SIZE      Rows per page, max 1000                       (default: 100)
#   LIST_NAME      Create a Tiga person list with the results    (optional)
#
# Examples:
#   TIGA_API_KEY=xxxx ./engaged_people.sh open
#   TIGA_API_KEY=xxxx START_DATE=2026-07-01 ./engaged_people.sh open,click,reply engaged.csv
#   TIGA_API_KEY=xxxx OWNER_ID=all LIST_NAME="July openers" ./engaged_people.sh open

set -euo pipefail

TIGA_BASE="${TIGA_BASE:-https://app.tigalabs.com}"
OWNER_ID="${OWNER_ID:-}"
SEQUENCE_ID="${SEQUENCE_ID:-}"
START_DATE="${START_DATE:-}"
END_DATE="${END_DATE:-}"
PAGE_SIZE="${PAGE_SIZE:-100}"
LIST_NAME="${LIST_NAME:-}"

METRIC="${1:-}"
OUT="${2:-engaged_people.csv}"

err() { echo "Error: $*" >&2; exit 1; }

[ -n "${TIGA_API_KEY:-}" ] || err "TIGA_API_KEY is not set"
[ -n "$METRIC" ] || err "usage: $0 <metric[,metric...]> [output.csv]"
command -v jq >/dev/null 2>&1 || err "jq is required (brew install jq)"

auth=(-H "X-Tiga-Auth: $TIGA_API_KEY")

# Build the query string from whichever filters are set.
query="metric=$METRIC"
[ -n "$OWNER_ID" ]    && query="$query&owner_id=$OWNER_ID"
[ -n "$SEQUENCE_ID" ] && query="$query&sequence_id=$SEQUENCE_ID"
[ -n "$START_DATE" ]  && query="$query&startDate=$START_DATE"
[ -n "$END_DATE" ]    && query="$query&endDate=$END_DATE"

# --- 1. Page through the results and write CSV --------------------------------
# @csv quotes/escapes fields, so titles containing commas stay in one column.
echo "Querying engagement: $query" >&2
echo "person_id,first_last,email,title,account_name,send,open,click,reply,bounce,li_reply,call,last_matched_at" > "$OUT"

page=1
total=0
person_ids=()
while :; do
  resp=$(curl -sS -X GET "$TIGA_BASE/api/v1/engagement/people?$query" "${auth[@]}" \
           -H "Tiga-Pagination: {\"page\":$page,\"page_size\":$PAGE_SIZE}")

  # Surface API errors (they come back as plain text, not JSON)
  echo "$resp" | jq -e '.rows' >/dev/null 2>&1 || err "API error: $resp"

  n=$(echo "$resp" | jq '.rows | length')
  total=$(echo "$resp" | jq -r '.total_count')
  [ "$n" -gt 0 ] || break

  echo "$resp" | jq -r '.rows[] | [
      .person_id, .person_name, .person_email, .title, (.account_name // ""),
      .email_send_count, .email_open_count, .email_click_count,
      .email_reply_count, .email_bounce_count, .li_reply_count, .call_count,
      .last_matched_at
    ] | @csv' >> "$OUT"

  while IFS= read -r id; do person_ids+=("$id"); done \
    < <(echo "$resp" | jq -r '.rows[].person_id')

  echo "  ...page $page: $n rows (of $total total)" >&2
  [ "$n" -lt "$PAGE_SIZE" ] && break
  page=$((page + 1))
done

echo "Done. $OUT ($(( $(wc -l < "$OUT") - 1 )) rows)" >&2

# --- 2. Optionally materialize into a Tiga person list ------------------------
if [ -n "$LIST_NAME" ] && [ "${#person_ids[@]}" -gt 0 ]; then
  echo "Creating list: $LIST_NAME" >&2
  create=$(jq -n --arg name "$LIST_NAME" '{list: {name: $name, object_type: "person"}}' |
    curl -sS -X POST "$TIGA_BASE/api/v1/lists" "${auth[@]}" \
      -H "Content-Type: application/json" -d @-)
  list_id=$(echo "$create" | jq -r '.id // .ID // empty')
  [ -n "$list_id" ] || err "no list id in response: $create"
  echo "  list_id: $list_id" >&2

  # add-members in batches of 100 (object_ids, NOT member_ids)
  batch_start=0
  while [ "$batch_start" -lt "${#person_ids[@]}" ]; do
    printf '%s\n' "${person_ids[@]:$batch_start:100}" |
      jq -R . | jq -s '{object_ids: .}' |
      curl -sS -X POST "$TIGA_BASE/api/v1/lists/$list_id/add-members" "${auth[@]}" \
        -H "Content-Type: application/json" -d @- >/dev/null
    batch_start=$((batch_start + 100))
    echo "  ...added $((batch_start < ${#person_ids[@]} ? batch_start : ${#person_ids[@]})) / ${#person_ids[@]}" >&2
  done

  # Verify membership landed before declaring success
  verify=$(curl -sS -X GET "$TIGA_BASE/api/v1/people" "${auth[@]}" \
             -H "Tiga-Filter: {\"list_id\":\"$list_id\"}" \
             -H 'Tiga-Pagination: {"page":1,"page_size":1}' | jq -r '.total_count // 0')
  [ "$verify" -gt 0 ] || err "list $list_id verified empty after add-members"
  echo "List ready: $LIST_NAME ($verify members, list_id=$list_id)" >&2
fi
