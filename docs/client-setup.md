# Adding a Client

## Overview

Each "client" is a server you want to monitor. The process:
1. You run `onboard_client.sh` on the **monitoring server** → generates a config bundle
2. Copy the bundle to the **client's server**
3. On the client server, run `docker compose up -d`

That's it. Data starts flowing automatically.

## Step 1 — Run Onboard Script (on monitoring server)

```bash
./scripts/onboard_client.sh <CLIENT_NAME> <MONITORING_SERVER_HOST>

# Examples:
./scripts/onboard_client.sh acme-corp monitoring.yourdomain.com
./scripts/onboard_client.sh my-startup 192.168.1.100 http
```

This creates `./dist/client-<name>/` with:
- `docker-compose.yml` — agent containers
- `prometheus.yml` — pre-configured to push to YOUR server
- `promtail.yaml` — pre-configured to push logs to YOUR server
- `process-exporter.yml` — process monitoring config

## Step 2 — Copy Bundle to Client Server

```bash
scp -r ./dist/client-acme-corp/ user@client-server-ip:~/monitoring/
```

## Step 3 — Start Agent on Client Server

SSH into the client server and run:

```bash
cd ~/monitoring/client-acme-corp
docker compose up -d
```

## Step 4 — Create Dashboard in Grafana

Back on your monitoring server:

```bash
./scripts/deploy_tenant.sh ACME-CORP
```

This creates:
- An isolated Grafana folder for the client
- A viewer user with individual login
- A personalized dashboard scoped to that client's data

## What the Client Agent Collects

| Collector | Data |
|---|---|
| Node Exporter | CPU, RAM, Disk, Network |
| Process Exporter | Top processes by CPU/RAM |
| cAdvisor | Docker container stats |
| Promtail | System logs (`/var/log/*`) |
| mysql-exporter (optional) | MySQL/MariaDB performance |
| postgres-exporter (optional) | PostgreSQL performance |

## Enabling Database Monitoring

See [database-monitoring.md](./database-monitoring.md) for step-by-step instructions.

## Requirements on Client Server

- Docker 24+
- Docker Compose v2
- Ports accessible: none (all outbound from client)
- OS: Ubuntu 20.04+ (or any Linux with Docker)
