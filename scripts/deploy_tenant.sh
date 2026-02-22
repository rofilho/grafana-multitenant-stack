#!/bin/bash
# ============================================================
# monitoring-stack — Deploy/Update a Tenant Dashboard in Grafana
# Creates isolated folder, viewer user and dashboard per client
#
# Usage:   ./scripts/deploy_tenant.sh <CLIENT_NAME>
# Example: ./scripts/deploy_tenant.sh ACME
# ============================================================
set -e

CLIENT_NAME=$1
if [ -z "$CLIENT_NAME" ]; then
  echo "Usage: $0 <CLIENT_NAME>"
  exit 1
fi

# Load config
if [ -f ".env" ]; then
  source .env
fi

CLIENT_UPPER=$(echo "$CLIENT_NAME" | tr '[:lower:]' '[:upper:]')
CLIENT_LOWER=$(echo "$CLIENT_NAME" | tr '[:upper:]' '[:lower:]')
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3005}"
AUTH="admin:${GRAFANA_ADMIN_PASSWORD}"
TEMPLATE_JSON="./dashboards/client_overview.json"
FOLDER_UID="client-${CLIENT_LOWER}"
DASH_UID="dashboard-${CLIENT_LOWER}"
USER_PASS="${CLIENT_LOWER}@monitor2024"

echo "🚀 Deploying tenant: $CLIENT_UPPER"

# 1. Create Team
TEAM_ID=$(curl -s -u "$AUTH" "${GRAFANA_URL}/api/teams/search?name=${CLIENT_UPPER}" | jq '.teams[0].id')
if [ "$TEAM_ID" == "null" ]; then
  TEAM_ID=$(curl -s -u "$AUTH" -H "Content-Type: application/json" -X POST "${GRAFANA_URL}/api/teams" \
    -d "{\"name\":\"${CLIENT_UPPER}\"}" | jq .teamId)
fi
echo "  ✅ Team ID: $TEAM_ID"

# 2. Create isolated folder
curl -s -u "$AUTH" -H "Content-Type: application/json" -X POST "${GRAFANA_URL}/api/folders" \
  -d "{\"uid\":\"${FOLDER_UID}\",\"title\":\"Client: ${CLIENT_UPPER}\"}" > /dev/null

PERMISSIONS="{\"items\": [{\"role\":\"Admin\",\"permission\":4}, {\"teamId\":${TEAM_ID},\"permission\":1}]}"
curl -s -u "$AUTH" -H "Content-Type: application/json" -X POST \
  "${GRAFANA_URL}/api/folders/${FOLDER_UID}/permissions" -d "$PERMISSIONS" > /dev/null
echo "  ✅ Isolated folder created"

# 3. Create viewer user
curl -s -u "$AUTH" -H "Content-Type: application/json" -X POST "${GRAFANA_URL}/api/admin/users" \
  -d "{\"name\":\"${CLIENT_UPPER} Viewer\",\"login\":\"${CLIENT_LOWER}\",\"password\":\"${USER_PASS}\"}" > /dev/null
USER_ID=$(curl -s -u "$AUTH" "${GRAFANA_URL}/api/users/lookup?loginOrEmail=${CLIENT_LOWER}" | jq .id)
curl -s -u "$AUTH" -H "Content-Type: application/json" -X POST "${GRAFANA_URL}/api/teams/${TEAM_ID}/members" \
  -d "{\"userId\":${USER_ID}}" > /dev/null
curl -s -u "$AUTH" -H "Content-Type: application/json" -X PATCH "${GRAFANA_URL}/api/org/users/${USER_ID}" \
  -d '{"role":"Viewer"}' > /dev/null
echo "  ✅ Viewer user: $CLIENT_LOWER / $USER_PASS"

# 4. Deploy dashboard
MODIFIED_JSON=$(cat "$TEMPLATE_JSON" | jq --arg client "$CLIENT_UPPER" --arg client_value "$CLIENT_LOWER" \
  --arg uid "$DASH_UID" '
  .title = "Dashboard " + $client |
  .uid = $uid |
  .id = null |
  .templating.list = [
    { "name": "client", "type": "constant", "query": $client_value,
      "current": {"text": $client_value, "value": $client_value},
      "options": [{"selected": true, "text": $client_value, "value": $client_value}], "hide": 2 }
  ] |
  walk(if type == "object" and has("expr") then
    .expr |= (gsub("\\$client"; $client_value))
  else . end)
')
PAYLOAD=$(jq -n --argjson dashboard "$MODIFIED_JSON" --arg folderUid "$FOLDER_UID" \
  '{dashboard: $dashboard, folderUid: $folderUid, overwrite: true}')
curl -s -u "$AUTH" -H "Content-Type: application/json" -X POST "${GRAFANA_URL}/api/dashboards/db" \
  -d "$PAYLOAD" > /dev/null
echo "  ✅ Dashboard deployed"

echo ""
echo "============================================"
echo "  ✅ Tenant $CLIENT_UPPER ready!"
echo "  📊 Dashboard: ${GRAFANA_URL}/d/${DASH_UID}"
echo "  🔐 Login: ${CLIENT_LOWER} / ${USER_PASS}"
echo "============================================"
