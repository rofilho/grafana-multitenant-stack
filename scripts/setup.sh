#!/usr/bin/env bash
# setup.sh — one-time initialisation of the central monitoring stack.
#
# What this script does:
#   1. Validates prerequisites (docker, docker compose, htpasswd).
#   2. Copies .env.example → .env if .env does not exist yet.
#   3. Creates an empty nginx/.htpasswd file.
#   4. Pulls all Docker images.
#   5. Starts the stack.
#
# Usage: bash scripts/setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$ROOT_DIR"

# ── Colours ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[setup]${NC} $*"; }
warn()  { echo -e "${YELLOW}[setup]${NC} $*"; }
error() { echo -e "${RED}[setup]${NC} $*" >&2; exit 1; }

# ── Prerequisites ──────────────────────────────────────────────────────────────
info "Checking prerequisites..."
command -v docker      >/dev/null 2>&1 || error "docker is not installed."
command -v htpasswd    >/dev/null 2>&1 || error "htpasswd is not installed (apt install apache2-utils)."
docker compose version >/dev/null 2>&1 || error "docker compose plugin is not installed."

# ── .env ───────────────────────────────────────────────────────────────────────
if [[ ! -f .env ]]; then
    cp .env.example .env
    warn ".env created from .env.example — edit it before continuing."
    warn "Set at least: STACK_HOST, GF_ADMIN_PASSWORD, GF_SECRET_KEY"
    exit 0
fi

# ── nginx/.htpasswd ────────────────────────────────────────────────────────────
if [[ ! -f nginx/.htpasswd ]]; then
    info "Creating empty nginx/.htpasswd..."
    touch nginx/.htpasswd
fi

# ── Pull images ────────────────────────────────────────────────────────────────
info "Pulling Docker images..."
docker compose pull

# ── Start stack ────────────────────────────────────────────────────────────────
info "Starting the monitoring stack..."
docker compose up -d

# shellcheck disable=SC1091
set -o allexport; source .env; set +o allexport
info "Stack is up. Access Grafana at http://${STACK_HOST}:${STACK_PORT:-80}"
info "Run 'scripts/onboard_client.sh <name> <password>' to add a client."
