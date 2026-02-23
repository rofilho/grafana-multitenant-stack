#!/usr/bin/env bash
# onboard_client.sh — register a new client and generate its agent bundle.
#
# What this script does:
#   1. Adds the client's Basic Auth credentials to nginx/.htpasswd.
#   2. Reloads Nginx so the new credentials take effect immediately.
#   3. Renders templates/ → dist/client-<name>/ using the client's settings.
#   4. Packages the bundle as dist/client-<name>.tar.gz.
#
# Usage:
#   bash scripts/onboard_client.sh <client-name> <password>
#
# Arguments:
#   client-name   Alphanumeric identifier for the client (becomes the tenant ID).
#   password      Password for the client's Basic Auth + ingest credentials.
#
# The generated bundle contains:
#   - prometheus-agent.yml  — Prometheus in agent mode (remote_write to Mimir)
#   - promtail.yml          — Promtail config (push logs to Loki)
#   - otel-collector.yml    — OpenTelemetry Collector (traces to Tempo)
#
# Deploy the bundle on the client server:
#   tar xzf client-<name>.tar.gz
#   # Install and start each agent with the provided config.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$ROOT_DIR"

# ── Colours ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[onboard]${NC} $*"; }
warn()  { echo -e "${YELLOW}[onboard]${NC} $*"; }
error() { echo -e "${RED}[onboard]${NC} $*" >&2; exit 1; }

# ── Args ───────────────────────────────────────────────────────────────────────
CLIENT_NAME="${1:-}"
CLIENT_PASSWORD="${2:-}"

[[ -z "$CLIENT_NAME"     ]] && error "Usage: $0 <client-name> <password>"
[[ -z "$CLIENT_PASSWORD" ]] && error "Usage: $0 <client-name> <password>"

# Validate client name (alphanumeric + hyphens, no spaces)
if ! [[ "$CLIENT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    error "Client name must contain only letters, digits, hyphens, or underscores."
fi

# ── Load .env ─────────────────────────────────────────────────────────────────
[[ -f .env ]] || error ".env not found. Run scripts/setup.sh first."
# shellcheck disable=SC1091
set -o allexport; source .env; set +o allexport

STACK_HOST="${STACK_HOST:-localhost}"
STACK_PORT="${STACK_PORT:-80}"

# ── Prerequisites ──────────────────────────────────────────────────────────────
command -v htpasswd >/dev/null 2>&1 || error "htpasswd is not installed (apt install apache2-utils)."

# ── Nginx htpasswd ─────────────────────────────────────────────────────────────
HTPASSWD_FILE="nginx/.htpasswd"
[[ -f "$HTPASSWD_FILE" ]] || touch "$HTPASSWD_FILE"

if grep -q "^${CLIENT_NAME}:" "$HTPASSWD_FILE" 2>/dev/null; then
    warn "Client '${CLIENT_NAME}' already exists in htpasswd. Updating password."
    htpasswd -b "$HTPASSWD_FILE" "$CLIENT_NAME" "$CLIENT_PASSWORD"
else
    info "Adding '${CLIENT_NAME}' to nginx/.htpasswd..."
    htpasswd -b "$HTPASSWD_FILE" "$CLIENT_NAME" "$CLIENT_PASSWORD"
fi

# Reload Nginx to pick up the new credentials
if docker compose ps --services --filter "status=running" 2>/dev/null | grep -q "^nginx$"; then
    info "Reloading Nginx..."
    docker compose exec nginx nginx -s reload
else
    warn "Nginx container is not running; start the stack with 'docker compose up -d'."
fi

# ── Generate agent bundle ──────────────────────────────────────────────────────
DIST_DIR="dist/client-${CLIENT_NAME}"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

info "Rendering templates into ${DIST_DIR}/..."

for tpl in templates/*.tpl; do
    # Strip .tpl extension; e.g. templates/promtail.yml.tpl → promtail.yml
    filename="$(basename "${tpl%.tpl}")"
    sed \
        -e "s|{{CLIENT_NAME}}|${CLIENT_NAME}|g" \
        -e "s|{{CLIENT_PASSWORD}}|${CLIENT_PASSWORD}|g" \
        -e "s|{{STACK_HOST}}|${STACK_HOST}|g" \
        -e "s|{{STACK_PORT}}|${STACK_PORT}|g" \
        "$tpl" > "${DIST_DIR}/${filename}"
    info "  created ${DIST_DIR}/${filename}"
done

# ── Package ────────────────────────────────────────────────────────────────────
TARBALL="dist/client-${CLIENT_NAME}.tar.gz"
tar -czf "$TARBALL" -C dist "client-${CLIENT_NAME}"
info "Bundle ready: ${TARBALL}"

# ── Next steps ─────────────────────────────────────────────────────────────────
cat <<EOF

${GREEN}[onboard]${NC} Client '${CLIENT_NAME}' onboarded successfully.

Next steps:
  1. Deploy the agent bundle on the client server:
       scp ${TARBALL} user@client-server:~
       ssh user@client-server 'tar xzf client-${CLIENT_NAME}.tar.gz'

  2. Create the Grafana tenant (folder + user + datasources):
       bash scripts/deploy_tenant.sh ${CLIENT_NAME}

  3. Install and start agents on the client (example with systemd):
       # Node Exporter  → https://prometheus.io/download/#node_exporter
       # Prometheus     → prometheus --config.file=prometheus-agent.yml --enable-feature=agent
       # Promtail       → promtail -config.file=promtail.yml
       # OTEL Collector → otelcol --config=otel-collector.yml

EOF
