#!/bin/bash
# ============================================================
# monitoring-stack — Onboard a New Client
# Generates a config bundle for the client's server
#
# Usage:   ./scripts/onboard_client.sh <CLIENT_NAME> <SERVER_HOST> [https|http]
# Example: ./scripts/onboard_client.sh acme-corp monitoring.yourdomain.com https
# ============================================================
set -e

CLIENT_NAME=$1
SERVER_HOST=$2
PROTOCOL=${3:-"https"}

if [ -z "$CLIENT_NAME" ] || [ -z "$SERVER_HOST" ]; then
  echo "Usage: $0 <client_name> <server_host> [https|http]"
  echo "Example: $0 acme-corp monitoring.yourdomain.com https"
  exit 1
fi

# Load credentials from .env
if [ -f ".env" ]; then
  source .env
fi

if [ -z "$INGEST_USER" ] || [ -z "$INGEST_PASSWORD" ]; then
  echo "❌ INGEST_USER and INGEST_PASSWORD must be set in .env"
  exit 1
fi

CLIENT_LOWER=$(echo "$CLIENT_NAME" | tr '[:upper:]' '[:lower:]')
OUTPUT_DIR="./dist/client-${CLIENT_LOWER}"
TEMPLATE_DIR="./templates"

mkdir -p "$OUTPUT_DIR"

echo "🔧 Creating client bundle for: $CLIENT_NAME"

# 1. Generate prometheus.yml
MIMIR_URL="${PROTOCOL}://${INGEST_USER}:${INGEST_PASSWORD}@${SERVER_HOST}/api/v1/push"
sed -e "s|{{CLIENT_NAME}}|${CLIENT_LOWER}|g" \
    -e "s|{{MIMIR_URL}}|${MIMIR_URL}|g" \
    "${TEMPLATE_DIR}/prometheus.yml" > "${OUTPUT_DIR}/prometheus.yml"

# 2. Generate promtail.yaml
LOKI_URL="${PROTOCOL}://${INGEST_USER}:${INGEST_PASSWORD}@${SERVER_HOST}/loki/api/v1/push"
sed -e "s|{{CLIENT_NAME}}|${CLIENT_LOWER}|g" \
    -e "s|{{LOKI_URL}}|${LOKI_URL}|g" \
    "${TEMPLATE_DIR}/promtail.yaml" > "${OUTPUT_DIR}/promtail.yaml"

# 3. Copy docker-compose and process-exporter config
cp "${TEMPLATE_DIR}/docker-compose.yml" "${OUTPUT_DIR}/docker-compose.yml"

if [ -f "client-agent/process-exporter.yml" ]; then
  cp "client-agent/process-exporter.yml" "${OUTPUT_DIR}/process-exporter.yml"
fi

echo ""
echo "================================================"
echo "✅ Client bundle ready: ${OUTPUT_DIR}/"
echo "================================================"
echo "Next steps:"
echo "  1. Copy folder to client server: scp -r ${OUTPUT_DIR} user@client-server:~/"
echo "  2. On the client server:  cd client-${CLIENT_LOWER} && docker compose up -d"
echo "================================================"
