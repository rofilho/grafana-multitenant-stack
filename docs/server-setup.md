# Server Setup Guide

## Requirements

| Resource | Minimum | Recommended |
|---|---|---|
| CPU | 2 cores | 4 cores |
| RAM | 4 GB | 8 GB |
| Disk | 20 GB | 50+ GB |
| OS | Ubuntu 22.04+ | Ubuntu 22.04+ |
| Docker | 24+ | latest |
| Docker Compose | v2 | v2 |

## Step 1 — Install Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker
```

## Step 2 — Clone the Repository

```bash
git clone https://github.com/YOUR_USER/monitoring-stack.git
cd monitoring-stack
```

## Step 3 — Run Setup

```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

The setup script will:
- Ask for your domain, Grafana password, and ingest password
- Create the `.env` file
- Create required directories
- Generate gateway credentials
- Start all containers

## Step 4 — Configure Sites to Monitor (Optional)

Edit `central-prometheus.yml` and add the websites/services you want to monitor:

```yaml
static_configs:
  - targets:
      - https://your-client-site.com
    labels:
      client: "your-client"
```

Then reload:
```bash
docker compose restart central_prom
```

## Step 5 — Access Grafana

Open your browser: `http://YOUR_SERVER_IP:3005`

Login with:
- **User:** admin
- **Password:** the one you set during setup

## Expose to the Internet (Optional)

To expose Grafana via HTTPS with a domain, use a reverse proxy like [Traefik](https://traefik.io/) or [Caddy](https://caddyserver.com/):

```bash
# Example with Caddy (auto HTTPS)
caddy reverse-proxy --from monitoring.yourdomain.com --to localhost:3005
```

## Useful Commands

```bash
# View all running containers
docker compose ps

# View logs
docker compose logs -f grafana

# Restart a service
docker compose restart mimir

# Stop everything
docker compose down

# Update (pull new images)
docker compose pull && docker compose up -d
```
