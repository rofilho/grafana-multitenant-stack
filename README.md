# grafana-multitenant-stack

Self-hosted, multi-tenant monitoring stack built with the Grafana LGTM stack.  
Metrics, logs, traces and uptime — fully isolated per client, all in one Docker Compose.

## Stack

| Component | Role |
|---|---|
| **[Mimir](https://grafana.com/oss/mimir/)** | Long-term metrics storage (Prometheus `remote_write` target) |
| **[Loki](https://grafana.com/oss/loki/)** | Log aggregation (Promtail push target) |
| **[Tempo](https://grafana.com/oss/tempo/)** | Distributed tracing (OpenTelemetry) |
| **[Grafana](https://grafana.com/oss/grafana/)** | Visualization — multi-tenant, isolated per client |
| **[Blackbox Exporter](https://github.com/prometheus/blackbox_exporter)** | HTTP/SSL external probes |
| **[Prometheus](https://prometheus.io/)** | Central scraper — internal services + blackbox probes |
| **[Nginx](https://nginx.org/)** | Ingest gateway with Basic Auth + tenant routing |

## Multi-tenancy Model

- Each **client** represents one monitored server/application.
- The client's **username** (used for Basic Auth) is automatically injected as
  `X-Scope-OrgID` by Nginx, becoming the **tenant ID** in Mimir, Loki and Tempo.
- All metrics and logs carry a `client="<name>"` label.
- Each client gets an **isolated Grafana folder**, a **viewer user**, and
  **dedicated datasources** scoped to their tenant.
- Client agents communicate with the central stack through Nginx only — they
  never talk directly to Mimir/Loki/Tempo.

```
                   Client server
  ┌─────────────────────────────────────────┐
  │  Prometheus agent  → remote_write       │
  │  Promtail          → push logs          │
  │  OTEL Collector    → OTLP traces        │
  └─────────────┬───────────────────────────┘
                │ HTTP Basic Auth
                ▼
         ┌─────────────┐        ┌────────────┐
         │    Nginx    │──────▶ │   Mimir    │
         │  (gateway)  │──────▶ │   Loki     │
         └─────────────┘──────▶ │   Tempo    │
                                └────────────┘
                                      │
                                 ┌────▼─────┐
                                 │  Grafana │
                                 └──────────┘
```

## Directory Structure

```
grafana-multitenant-stack/
├── docker-compose.yml          # Central stack definition
├── central-prometheus.yml      # Central Prometheus — add monitored sites here
├── .env.example                # Secrets template — copy to .env and fill in
├── .gitignore
├── nginx/
│   └── nginx.conf              # Gateway: basic auth + X-Scope-OrgID injection
├── mimir/
│   └── mimir.yml               # Mimir monolithic config
├── loki/
│   └── loki.yml                # Loki single-process config
├── tempo/
│   └── tempo.yml               # Tempo single-binary config
├── blackbox/
│   └── blackbox.yml            # Probe modules (http_2xx, ssl, tcp, icmp)
├── grafana/
│   ├── grafana.ini             # Grafana server settings
│   └── provisioning/
│       └── datasources/
│           └── central.yml     # Pre-provisioned "central" admin datasources
├── templates/                  # Used by onboard_client.sh to generate bundles
│   ├── prometheus-agent.yml.tpl
│   ├── promtail.yml.tpl
│   └── otel-collector.yml.tpl
└── scripts/
    ├── setup.sh                # One-time stack initialisation
    ├── onboard_client.sh       # Register client + generate agent bundle
    └── deploy_tenant.sh        # Create Grafana folder/user/datasources
```

## Quick Start

### 1 — Clone and configure

```bash
git clone https://github.com/<you>/grafana-multitenant-stack
cd grafana-multitenant-stack

cp .env.example .env
# Edit .env — set STACK_HOST, GF_ADMIN_PASSWORD, GF_SECRET_KEY at minimum
```

### 2 — Start the stack

```bash
bash scripts/setup.sh
```

This will:
1. Validate prerequisites (`docker`, `htpasswd`).
2. Pull all Docker images.
3. Start all services in the background.

### 3 — Add a monitored client

```bash
# Register the client and generate the agent bundle
bash scripts/onboard_client.sh acme-corp s3cr3t-p4ssw0rd

# Create the isolated Grafana tenant (folder + viewer user + datasources)
bash scripts/deploy_tenant.sh acme-corp
```

`onboard_client.sh` will:
- Add `acme-corp` to `nginx/.htpasswd` (BCrypt) and reload Nginx.
- Render `templates/*.tpl` → `dist/client-acme-corp/` with the correct credentials.
- Package the bundle as `dist/client-acme-corp.tar.gz`.

`deploy_tenant.sh` will:
- Create a Grafana folder named `acme-corp`.
- Create a viewer user (`acme-corp@localhost`) and restrict them to that folder.
- Create datasources `Mimir (acme-corp)`, `Loki (acme-corp)`, `Tempo (acme-corp)`,
  each with `X-Scope-OrgID: acme-corp` injected on every query.

### 4 — Deploy agents on the client server

Copy and extract the bundle:

```bash
scp dist/client-acme-corp.tar.gz user@acme-server:~
ssh user@acme-server
tar xzf client-acme-corp.tar.gz
cd client-acme-corp
```

Install and start agents (example with binaries):

```bash
# Node Exporter (system metrics)
./node_exporter &

# Prometheus in agent mode (remote_write to Mimir)
prometheus --config.file=prometheus-agent.yml --enable-feature=agent &

# Promtail (log shipping to Loki)
promtail -config.file=promtail.yml &

# OpenTelemetry Collector (traces to Tempo)
otelcol --config=otel-collector.yml &
```

### 5 — Add uptime probes for a client site

Edit `central-prometheus.yml` and add targets to the `blackbox-http` or
`blackbox-https-ssl` jobs:

```yaml
  - job_name: blackbox-https-ssl
    ...
    static_configs:
      - targets: ["https://acme-corp.example.com"]
        labels:
          client: acme-corp
```

Then reload Prometheus:

```bash
docker compose restart prometheus
```

## Secrets and Configuration

All secrets are stored in `.env` — **never commit this file**.  
Use `.env.example` as the source of truth for required variables.

| Variable | Description |
|---|---|
| `STACK_HOST` | Public hostname/IP of the central monitoring server |
| `STACK_PORT` | External port exposed by Nginx (default: `80`) |
| `GF_ADMIN_USER` | Grafana admin username |
| `GF_ADMIN_PASSWORD` | Grafana admin password |
| `GF_SECRET_KEY` | Grafana secret key (≥ 32 chars) |

## Conventions

- All secrets come from `.env` — never hardcode credentials.
- Config templates use `{{PLACEHOLDER}}` syntax replaced by `sed` in scripts.
- Client bundles are generated into `dist/client-<name>/` (gitignored).
- Tenant isolation is enforced at the Nginx layer via `X-Scope-OrgID: $remote_user`.

## Updating the Stack

```bash
# Pull new images and recreate containers
docker compose pull
docker compose up -d
```

## Removing a Client

```bash
# 1. Remove from htpasswd
htpasswd -D nginx/.htpasswd acme-corp
docker compose exec nginx nginx -s reload

# 2. Remove Grafana artefacts via the Grafana UI or API
# 3. Optionally delete dist/client-acme-corp/
```
