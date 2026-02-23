#!/usr/bin/env bash
# deploy_tenant.sh — create an isolated Grafana tenant for a client.
#
# What this script does (all via Grafana HTTP API):
#   1. Creates a Grafana folder named after the client.
#   2. Creates a viewer user  <client>@localhost  with a random password.
#   3. Grants the viewer user view-only access to the client's folder.
#   4. Creates per-client datasources (Mimir, Loki, Tempo) scoped to the
#      client's tenant ID (X-Scope-OrgID header).
#
# Prerequisites:
#   - Grafana must be running and reachable.
#   - .env must exist with GF_ADMIN_USER, GF_ADMIN_PASSWORD, STACK_HOST,
#     STACK_PORT set correctly.
#
# Usage:
#   bash scripts/deploy_tenant.sh <client-name>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$ROOT_DIR"

# ── Colours ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[deploy]${NC} $*"; }
warn()  { echo -e "${YELLOW}[deploy]${NC} $*"; }
error() { echo -e "${RED}[deploy]${NC} $*" >&2; exit 1; }

# ── Args ───────────────────────────────────────────────────────────────────────
CLIENT_NAME="${1:-}"
[[ -z "$CLIENT_NAME" ]] && error "Usage: $0 <client-name>"

# ── Load .env ─────────────────────────────────────────────────────────────────
[[ -f .env ]] || error ".env not found. Run scripts/setup.sh first."
# shellcheck disable=SC1091
set -o allexport; source .env; set +o allexport

GF_ADMIN_USER="${GF_ADMIN_USER:-admin}"
GF_ADMIN_PASSWORD="${GF_ADMIN_PASSWORD:-admin}"
STACK_HOST="${STACK_HOST:-localhost}"
STACK_PORT="${STACK_PORT:-80}"

GRAFANA_URL="http://${STACK_HOST}:${STACK_PORT}"
AUTH="${GF_ADMIN_USER}:${GF_ADMIN_PASSWORD}"

# ── Helper — Grafana API call ──────────────────────────────────────────────────
gf_api() {
    local method="$1"
    local path="$2"
    local data="${3:-}"
    local response http_code body

    if [[ -n "$data" ]]; then
        response=$(curl -s -w "\n%{http_code}" \
            -u "$AUTH" \
            -X "$method" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "${GRAFANA_URL}/api${path}")
    else
        response=$(curl -s -w "\n%{http_code}" \
            -u "$AUTH" \
            -X "$method" \
            "${GRAFANA_URL}/api${path}")
    fi

    http_code=$(echo "$response" | tail -1)
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
        # 409 = already exists — treat as OK
        if [[ "$http_code" -ne 409 ]]; then
            error "Grafana API ${method} /api${path} returned HTTP ${http_code}: ${body}"
        fi
    fi

    echo "$body"
}

# ── Wait for Grafana ───────────────────────────────────────────────────────────
info "Waiting for Grafana to be ready..."
for i in $(seq 1 30); do
    if curl -sf -u "$AUTH" "${GRAFANA_URL}/api/health" >/dev/null 2>&1; then
        break
    fi
    [[ "$i" -eq 30 ]] && error "Grafana did not become ready in time."
    sleep 2
done

# ── 1. Create folder ───────────────────────────────────────────────────────────
info "Creating folder '${CLIENT_NAME}'..."
FOLDER_RESPONSE=$(gf_api POST /folders \
    "{\"title\": \"${CLIENT_NAME}\", \"uid\": \"folder-${CLIENT_NAME}\"}")
FOLDER_UID=$(echo "$FOLDER_RESPONSE" | grep -o '"uid":"[^"]*"' | head -1 | cut -d'"' -f4)
# Fallback: folder may already exist
if [[ -z "$FOLDER_UID" ]]; then
    FOLDER_RESPONSE=$(gf_api GET "/folders/folder-${CLIENT_NAME}")
    FOLDER_UID=$(echo "$FOLDER_RESPONSE" | grep -o '"uid":"[^"]*"' | head -1 | cut -d'"' -f4)
fi
info "  Folder UID: ${FOLDER_UID}"

# ── 2. Create viewer user ──────────────────────────────────────────────────────
USER_EMAIL="${CLIENT_NAME}@localhost"
USER_PASSWORD="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)"
info "Creating viewer user '${USER_EMAIL}'..."
USER_RESPONSE=$(gf_api POST /admin/users \
    "{\"name\": \"${CLIENT_NAME}\", \"email\": \"${USER_EMAIL}\", \"login\": \"${CLIENT_NAME}\", \"password\": \"${USER_PASSWORD}\", \"role\": \"Viewer\"}")
USER_ID=$(echo "$USER_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
# Fallback: user may already exist
if [[ -z "$USER_ID" ]]; then
    USER_RESPONSE=$(gf_api GET "/users/lookup?loginOrEmail=${CLIENT_NAME}")
    USER_ID=$(echo "$USER_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
fi
info "  User ID: ${USER_ID}"

# ── 3. Grant user access to the folder ────────────────────────────────────────
info "Granting viewer '${CLIENT_NAME}' access to folder '${FOLDER_UID}'..."
gf_api POST "/folders/${FOLDER_UID}/permissions" \
    "{\"items\": [{\"userId\": ${USER_ID}, \"permission\": 1}]}" >/dev/null

# ── 4. Create datasources scoped to this tenant ────────────────────────────────
# Mimir
info "Creating datasource: Mimir (${CLIENT_NAME})..."
gf_api POST /datasources "$(cat <<JSON
{
  "name":   "Mimir (${CLIENT_NAME})",
  "type":   "prometheus",
  "uid":    "mimir-${CLIENT_NAME}",
  "url":    "http://mimir:9009/prometheus",
  "access": "proxy",
  "jsonData": {
    "httpHeaderName1": "X-Scope-OrgID"
  },
  "secureJsonData": {
    "httpHeaderValue1": "${CLIENT_NAME}"
  }
}
JSON
)" >/dev/null

# Loki
info "Creating datasource: Loki (${CLIENT_NAME})..."
gf_api POST /datasources "$(cat <<JSON
{
  "name":   "Loki (${CLIENT_NAME})",
  "type":   "loki",
  "uid":    "loki-${CLIENT_NAME}",
  "url":    "http://loki:3100",
  "access": "proxy",
  "jsonData": {
    "httpHeaderName1": "X-Scope-OrgID"
  },
  "secureJsonData": {
    "httpHeaderValue1": "${CLIENT_NAME}"
  }
}
JSON
)" >/dev/null

# Tempo
info "Creating datasource: Tempo (${CLIENT_NAME})..."
gf_api POST /datasources "$(cat <<JSON
{
  "name":   "Tempo (${CLIENT_NAME})",
  "type":   "tempo",
  "uid":    "tempo-${CLIENT_NAME}",
  "url":    "http://tempo:3200",
  "access": "proxy",
  "jsonData": {
    "httpHeaderName1": "X-Scope-OrgID",
    "tracesToLogsV2": {
      "datasourceUid": "loki-${CLIENT_NAME}",
      "spanStartTimeShift": "-1m",
      "spanEndTimeShift": "1m"
    }
  },
  "secureJsonData": {
    "httpHeaderValue1": "${CLIENT_NAME}"
  }
}
JSON
)" >/dev/null

# ── Summary ────────────────────────────────────────────────────────────────────
cat <<EOF

${GREEN}[deploy]${NC} Tenant '${CLIENT_NAME}' created successfully.

  Grafana folder : ${GRAFANA_URL}/?orgId=1#/dashboards/f/folder-${CLIENT_NAME}
  Viewer login   : ${CLIENT_NAME} / ${USER_PASSWORD}
  Datasources    : Mimir (${CLIENT_NAME}), Loki (${CLIENT_NAME}), Tempo (${CLIENT_NAME})

${YELLOW}[deploy]${NC} Save the viewer password above — it is not stored anywhere.

EOF
