# 📊 Monitoring Stack

A **self-hosted, multi-tenant monitoring platform** for Linux servers, Docker containers, and databases. Built with the Grafana LGTM stack (Loki + Grafana + Tempo + Mimir).

**Add a server → get instant dashboards.** No cloud, no SaaS, no per-agent pricing.

---

## ✨ Features

| | |
|---|---|
| 🖥️ **Server Metrics** | CPU, RAM, Disk, Network (Node Exporter) |
| 🐳 **Container Monitoring** | Per-container stats (cAdvisor) |
| 🗄️ **Database Monitoring** | MySQL, MariaDB, PostgreSQL — queries, connections, transactions |
| 📋 **Log Aggregation** | System logs in Grafana (Loki + Promtail) |
| 🌐 **HTTP/SSL Probes** | Uptime and certificate expiry (Blackbox Exporter) |
| 👥 **Multi-tenant** | Isolated dashboard per client — they only see their data |
| 🔒 **Secure** | Basic Auth gateway, isolated Grafana folders, viewer-only users |
| 💨 **Lightweight** | 4 GB RAM minimum for the server, ~128MB per client agent |

---

## 🏗️ Architecture

```
[Client Server]  →  HTTPS (metrics + logs)  →  [Monitoring Server]
  Prometheus Agent                                Mimir (metrics)
  Promtail (logs)                                 Loki (logs)
  Node/Process/cAdvisor                           Grafana (dashboards)
  DB Exporters (optional)                         Blackbox (probes)
```

See [docs/architecture.md](docs/architecture.md) for the full diagram.

---

## 🚀 Quick Start

### 1. Server Setup (5 minutes)

```bash
git clone https://github.com/YOUR_USER/monitoring-stack.git
cd monitoring-stack
chmod +x scripts/setup.sh
./scripts/setup.sh
```

Open Grafana at `http://YOUR_SERVER_IP:3005`

### 2. Add a Client/Server

Run on the **monitoring server**:
```bash
./scripts/onboard_client.sh my-client monitoring.yourdomain.com
```

Copy the generated bundle to the client server:
```bash
scp -r ./dist/client-my-client/ user@client-server:~/
```

Run on the **client server**:
```bash
cd ~/client-my-client && docker compose up -d
```

Create the Grafana dashboard:
```bash
./scripts/deploy_tenant.sh MY-CLIENT
```

✅ Done! Data flows in within 30 seconds.

---

## 📋 Requirements

**Monitoring Server:**
- Ubuntu 22.04+, Docker 24+, Docker Compose v2
- 2+ vCPUs, 4+ GB RAM, 20+ GB disk

**Client Server (per client):**
- Docker 24+, Docker Compose v2
- ~256 MB RAM for all agents combined

---

## 📖 Documentation

| Guide | Description |
|---|---|
| [Server Setup](docs/server-setup.md) | Install the central monitoring server |
| [Adding Clients](docs/client-setup.md) | Onboard a new server to monitor |
| [Database Monitoring](docs/database-monitoring.md) | Enable MySQL / PostgreSQL metrics |
| [Architecture](docs/architecture.md) | How it all fits together |

---

## 📦 Project Structure

```
monitoring-stack/
├── docker-compose.yml          ← Central stack (Grafana + Mimir + Loki + Tempo)
├── central-prometheus.yml      ← HTTP probes config (add your sites here)
├── blackbox.yml                ← Probe modules
├── configs/                    ← Service configs (Loki, Mimir, Tempo, Grafana)
├── dashboards/                 ← Grafana dashboard JSON
├── templates/                  ← Templates for generating client bundles
├── scripts/
│   ├── setup.sh                ← Interactive first-time setup
│   ├── onboard_client.sh       ← Generate config bundle for a client
│   └── deploy_tenant.sh        ← Create isolated Grafana dashboard
└── docs/                       ← Full documentation
```

---

## 🤝 Contributing

Contributions welcome! Open an issue or PR.

---

## 📄 License

MIT — use it freely, even commercially.
