#!/bin/bash
# ============================================================
# monitoring-stack — Script de Setup Interativo
# Uso: ./scripts/setup.sh
# ============================================================
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_ok()  { echo -e "${GREEN}✅ $1${NC}"; }
print_warn(){ echo -e "${YELLOW}⚠️  $1${NC}"; }
print_err() { echo -e "${RED}❌ $1${NC}"; }

echo ""
echo "=================================================="
echo "  🚀 Monitoring Stack — Interactive Setup"
echo "=================================================="
echo ""

# 1. Check dependencies
echo "Checking dependencies..."
command -v docker >/dev/null 2>&1 || { print_err "Docker not found. Install it first: https://docs.docker.com/engine/install/"; exit 1; }
docker compose version >/dev/null 2>&1 || { print_err "Docker Compose v2 not found. Update Docker Desktop or install the plugin."; exit 1; }
print_ok "Docker and Docker Compose found"

# 2. Setup .env
if [ -f ".env" ]; then
  print_warn ".env already exists. Skipping (delete it manually to re-run setup)."
else
  echo ""
  echo "--- Configure your environment ---"
  read -p "Grafana admin password: " GRAFANA_PASS
  read -p "Your domain (or press ENTER for 'localhost'): " GRAFANA_DOMAIN
  GRAFANA_DOMAIN="${GRAFANA_DOMAIN:-localhost}"
  read -p "Ingest password (client agents will use this): " INGEST_PASS

  cp .env.example .env
  sed -i "s|GRAFANA_ADMIN_PASSWORD=.*|GRAFANA_ADMIN_PASSWORD=${GRAFANA_PASS}|" .env
  sed -i "s|GRAFANA_DOMAIN=.*|GRAFANA_DOMAIN=${GRAFANA_DOMAIN}|" .env
  sed -i "s|INGEST_PASSWORD=.*|INGEST_PASSWORD=${INGEST_PASS}|" .env
  print_ok ".env created successfully"
fi

source .env

# 3. Create directories
echo ""
echo "Creating data directories..."
mkdir -p data/{grafana,loki,mimir,tempo,uptime}
mkdir -p keys/
print_ok "Directories created"

# 4. Create credentials for gateway
if [ ! -f "gateway/.htpasswd" ]; then
  echo ""
  echo "Creating ingest gateway credentials..."
  mkdir -p gateway
  command -v htpasswd >/dev/null 2>&1 || apt-get install -y apache2-utils -q >/dev/null 2>&1
  htpasswd -bc gateway/.htpasswd "${INGEST_USER:-ingest}" "${INGEST_PASSWORD}"
  print_ok "Gateway credentials created"
fi

# 5. Start services
echo ""
echo "Starting monitoring stack..."
docker compose up -d

# 6. Wait for health
echo ""
echo "Waiting for services to start (30s)..."
sleep 30
GRAFANA_STATUS=$(docker inspect --format='{{.State.Health.Status}}' grafana 2>/dev/null || echo "unknown")
MIMIR_STATUS=$(docker inspect --format='{{.State.Health.Status}}' mimir 2>/dev/null || echo "unknown")
LOKI_STATUS=$(docker inspect --format='{{.State.Health.Status}}' loki 2>/dev/null || echo "unknown")

echo ""
echo "=== Service Status ==="
echo "  Grafana: $GRAFANA_STATUS"
echo "  Mimir:   $MIMIR_STATUS"
echo "  Loki:    $LOKI_STATUS"

echo ""
echo "=========================================="
print_ok "Setup Complete!"
echo ""
echo "  🌐 Grafana:  http://${GRAFANA_DOMAIN}:3005"
echo "  👤 Login:    admin / [your password]"
echo ""
echo "  Next step: Add your first client!"
echo "  Run: ./scripts/onboard_client.sh <CLIENT_NAME> <SERVER_IP_OR_DOMAIN>"
echo "=========================================="
