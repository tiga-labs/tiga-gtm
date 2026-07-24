#!/usr/bin/env bash
set -euo pipefail

set -a
source /Users/mike/Documents/Cowork/.env
set +a

BASE="https://villageparkrecords.com"
AUTH="X-Tiga-Auth: $TIGA_API_KEY"
ROOT_STEP="00000000-0000-0000-0000-000000000000"
HUBSPOT_LIST_NAME="Webinar Submissions"
SEQ_NAME="Webinar agent flow"

api() {
  local method=$1 url=$2 body=${3:-}
  if [[ -n "$body" ]]; then
    /usr/bin/curl -sS -X "$method" -H "$AUTH" -H "Content-Type: application/json" -d "$body" "$url"
  else
    /usr/bin/curl -sS -X "$method" -H "$AUTH" "$url"
  fi
}

jget() { /usr/bin/python3 -c "import json,sys; d=json.load(sys.stdin); print(d$1)"; }

# --- Try to delete the prior sequence -------------------------------------
PRIOR=b54f9708-eaf0-4d9d-8ade-667267c0ef02
echo "==> Attempting to delete prior sequence $PRIOR"
DEL_CODE=$(/usr/bin/curl -sS -o /dev/null -w "%{http_code}" -X DELETE -H "$AUTH" "$BASE/api/v1/sequence/$PRIOR")
echo "DELETE returned HTTP $DEL_CODE"
if [[ "$DEL_CODE" != "200" && "$DEL_CODE" != "204" ]]; then
  echo "WARN: public API does not expose sequence deletion. Prior sequence $PRIOR must be removed in the Tiga UI."
fi

# --- Find HubSpot list ID via Tiga's HubSpot OAuth proxy ------------------
echo "==> Resolving HubSpot list '$HUBSPOT_LIST_NAME'"
HS_TOKEN=$(api GET "$BASE/api/v1/current-org/hubspot-oauth-token" | jget '["access_token"]')
HUBSPOT_LIST_ID=$(/usr/bin/curl -sS -X POST -H "Authorization: Bearer $HS_TOKEN" -H "Content-Type: application/json" \
  -d "{\"query\":\"$HUBSPOT_LIST_NAME\",\"count\":50,\"offset\":0}" \
  "https://api.hubapi.com/crm/v3/lists/search" |
  /usr/bin/python3 -c "
import json,sys
target='$HUBSPOT_LIST_NAME'
d=json.load(sys.stdin)
for L in d.get('lists',[]):
    if L.get('name')==target:
        print(L['listId']); break
")
if [[ -z "$HUBSPOT_LIST_ID" ]]; then
  echo "ERROR: could not find HubSpot list named '$HUBSPOT_LIST_NAME'" >&2; exit 1
fi
echo "HUBSPOT_LIST_ID=$HUBSPOT_LIST_ID"

# --- Create sequence ------------------------------------------------------
echo "==> Creating sequence '$SEQ_NAME'"
SEQ_ID=$(api POST "$BASE/api/v1/sequence" "{\"name\":\"$SEQ_NAME\",\"play_type\":\"flow\"}" | jget '["ID"]')
echo "SEQ_ID=$SEQ_ID"

add_step() {
  local prev=$1 action=$2 name=$3
  api POST "$BASE/api/v1/sequence/$SEQ_ID/add-step?stepToAppendToId=$prev" \
    "{\"action\":\"$action\",\"step_name\":\"$name\"}" |
    /usr/bin/python3 -c "
import json,sys
d=json.load(sys.stdin)
sid=d.get('ID') or d.get('id') or d.get('step_id')
if not sid and isinstance(d.get('step'),dict):
    sid=d['step'].get('ID') or d['step'].get('id')
print(sid or '')"
}

STEP1=$(add_step "$ROOT_STEP" SyncFromHubspotFeeder "Import From HubSpot")
echo "STEP1 (HubSpot)=$STEP1"
STEP2=$(add_step "$STEP1" WaterfallEnrich "Waterfall Enrich")
echo "STEP2 (Enrich)=$STEP2"
STEP3=$(add_step "$STEP2" LinkedInResearch "LinkedIn Research (Accounts)")
echo "STEP3 (LinkedIn)=$STEP3"
STEP4=$(add_step "$STEP3" AccountIcpFilter "Account Fit")
echo "STEP4 (ICP)=$STEP4"
STEP5=$(add_step "$STEP4" RunSignal "Territory Signal")
echo "STEP5 (Territory)=$STEP5"
STEP6=$(add_step "$STEP5" AddToSequence "Add to Inbound Followup")
echo "STEP6 (AddToSeq)=$STEP6"

# --- Configure HubSpot step with list selection ---------------------------
echo "==> Configuring HubSpot step with list '$HUBSPOT_LIST_NAME' (id=$HUBSPOT_LIST_ID)"
STEP_BODY=$(HUBSPOT_LIST_ID="$HUBSPOT_LIST_ID" STEP1="$STEP1" SEQ_ID="$SEQ_ID" /usr/bin/python3 -c "
import json, os
print(json.dumps({
  'ID': os.environ['STEP1'],
  'SequenceID': os.environ['SEQ_ID'],
  'Name': 'Import From HubSpot',
  'Action': 'SyncFromHubspotFeeder',
  'config': {
    'sync_from_hubspot': {
      'list_id': os.environ['HUBSPOT_LIST_ID'],
      'object_type_id': '0-1',
      'field_mappings': {
        'person_mappings': {
          'first_name': 'firstname',
          'last_name': 'lastname',
          'email_address': 'email',
          'title': 'jobtitle',
          'phone': 'phone',
          'mobile_phone': 'mobilephone',
          'linkedin_url': 'hs_linkedin_url',
          'city': 'city',
          'state': 'state',
          'country': 'country',
          'account_name': 'company'
        },
        'account_mappings': {}
      }
    }
  }
}))")
api PATCH "$BASE/api/v1/step/$STEP1" "$STEP_BODY"; echo

# --- Configure Waterfall Enrich step --------------------------------------
echo "==> Configuring Waterfall Enrich step (continue_if_found, email + linkedin required)"
ENRICH_BODY=$(/usr/bin/python3 -c "
import json
print(json.dumps({
  'config': {
    'waterfall_enrich': {
      'settings': {
        'providers': [
          {'name':'Findymail','type':'findymail'},
          {'name':'Hunter.io','type':'hunter'},
          {'name':'Prospeo','type':'prospeo'},
          {'name':'Datagma','type':'datagma'},
          {'name':'Dropcontact','type':'dropcontact'}
        ],
        'is_linkedin_url_required': True,
        'is_email_address_required': True,
        'is_phone_number_required': False,
        'should_validate_with_zero_bounce': False
      },
      'flow_behavior': 'continue_if_found'
    }
  }
}))")
api PATCH "$BASE/api/v1/step/$STEP2" "$ENRICH_BODY"; echo

# --- Configure LinkedIn Research step (account-level) ---------------------
echo "==> Configuring LinkedIn Research step (research_account=true)"
LI_BODY='{"config":{"linked_in_research":{"research_person":false,"research_account":true}}}'
api PATCH "$BASE/api/v1/step/$STEP3" "$LI_BODY"; echo

# --- Configure Account Fit (ICP filter) -----------------------------------
# Edit ICP_COMPANY_SIZES / ICP_INDUSTRIES / ICP_REVENUES below to fit your ICP.
ICP_COMPANY_SIZES='["51-200","201-500","501-1,000","1001-5,000"]'
ICP_INDUSTRIES='["Software","Healthcare"]'
ICP_REVENUES='[]'
echo "==> Configuring Account Fit (sizes=$ICP_COMPANY_SIZES industries=$ICP_INDUSTRIES)"
ICP_BODY=$(ICP_COMPANY_SIZES="$ICP_COMPANY_SIZES" ICP_INDUSTRIES="$ICP_INDUSTRIES" ICP_REVENUES="$ICP_REVENUES" /usr/bin/python3 -c "
import json, os
print(json.dumps({
  'config': {
    'account_icp_filter': {
      'company_sizes': json.loads(os.environ['ICP_COMPANY_SIZES']),
      'revenues': json.loads(os.environ['ICP_REVENUES']),
      'industries': json.loads(os.environ['ICP_INDUSTRIES']),
      'allow_related_industries': False,
      'flow_behavior': 'continue_if_match'
    }
  }
}))")
api PATCH "$BASE/api/v1/step/$STEP4" "$ICP_BODY"; echo

# --- Configure Territory Signal step --------------------------------------
TERRITORY_SIGNAL_ID="a2e774a1-75aa-4e97-9e1e-65dde4e0adc1"
echo "==> Configuring Territory Signal step (signal_id=$TERRITORY_SIGNAL_ID)"
SIGNAL_BODY=$(TERRITORY_SIGNAL_ID="$TERRITORY_SIGNAL_ID" /usr/bin/python3 -c "
import json, os
print(json.dumps({
  'config': {
    'run_signal': {
      'signal_id': os.environ['TERRITORY_SIGNAL_ID'],
      'is_account_insight': True,
      'should_flow_if_signal_found': True,
      'flow_behavior': 'continue_if_found'
    }
  }
}))")
api PATCH "$BASE/api/v1/step/$STEP5" "$SIGNAL_BODY"; echo

# --- Ensure 'inbound followup' sequence exists ----------------------------
FOLLOWUP_NAME="inbound followup"
echo "==> Looking up sequence '$FOLLOWUP_NAME'"
FOLLOWUP_ID=$(api GET "$BASE/api/v1/sequences" | /usr/bin/python3 -c "
import json, sys
target = '$FOLLOWUP_NAME'.lower()
for s in json.load(sys.stdin):
    if s.get('Name','').lower() == target:
        print(s['ID']); break
")
if [[ -z "$FOLLOWUP_ID" ]]; then
  echo "    not found, creating"
  FOLLOWUP_ID=$(api POST "$BASE/api/v1/sequence" "{\"name\":\"$FOLLOWUP_NAME\",\"play_type\":\"sequence\",\"business_goal\":\"meeting\"}" | jget '["ID"]')
  EMAIL_BODY=$(/usr/bin/python3 -c "
import json
print(json.dumps({
  'action': 'SequenceEmail',
  'step_name': 'Sales intro',
  'email_subject': 'Thanks for joining our webinar',
  'email_body': 'Hi {{.FirstName}},\n\nThanks for attending our recent webinar! I wanted to introduce myself — I work with {{.AccountName}}-sized teams to help them get the most out of our platform.\n\nWould you be open to a quick 15-minute chat this week?\n\nBest,'
}))")
  /usr/bin/curl -sS -X POST -H "$AUTH" -H "Content-Type: application/json" -d "$EMAIL_BODY" "$BASE/api/v1/sequence/$FOLLOWUP_ID/add-step?stepToAppendToId=$ROOT_STEP" >/dev/null
fi
echo "FOLLOWUP_ID=$FOLLOWUP_ID"

# --- Configure AddToSequence step ----------------------------------------
echo "==> Configuring Add to Sequence step (target=$FOLLOWUP_ID)"
OWNER_USER_ID="c07224b3-f7b9-4eb0-9b8d-8e158cc49658"
OWNER_USER_NAME="Mike Ball"
ADD_BODY=$(FOLLOWUP_ID="$FOLLOWUP_ID" FOLLOWUP_NAME="$FOLLOWUP_NAME" \
  OWNER_USER_ID="$OWNER_USER_ID" OWNER_USER_NAME="$OWNER_USER_NAME" /usr/bin/python3 -c "
import json, os
print(json.dumps({
  'Name': 'Add To Sequence: Inbound Followup',
  'config': {
    'add_to_sequence': {
      'mode': 'by_person_owner',
      'sequence_id': None,
      'sequence_name': '',
      'step_id': None,
      'step_name': '',
      'owner_to_sequence_mappings': [
        {
          'user_id': os.environ['OWNER_USER_ID'],
          'user_name': os.environ['OWNER_USER_NAME'],
          'sequence_id': os.environ['FOLLOWUP_ID'],
          'sequence_name': os.environ['FOLLOWUP_NAME'],
          'step_id': None,
          'step_name': None
        }
      ]
    }
  }
}))")
api PATCH "$BASE/api/v1/step/$STEP6" "$ADD_BODY"; echo

# --- Verification ---------------------------------------------------------
echo
echo "==> Verification: sequence description"
api GET "$BASE/api/v1/sequence/$SEQ_ID/description"
echo
echo "==> Verification: metrics"
api GET "$BASE/api/v1/sequence/$SEQ_ID/metrics" | /usr/bin/python3 -c "
import json,sys
d=json.load(sys.stdin)
for s in sorted(d['activity'], key=lambda x: x['step_name']):
    print(f\"  - {s['step_name']:35s} {s['step_type']}\")"
echo
echo "Done. Sequence ID: $SEQ_ID"
