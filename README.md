# 📊 Monitoring Stack

<div align="center">
  <img src="https://github.com/user-attachments/assets/bd9396a6-43cc-4ffe-b1f0-3f178b9282e1" width="48%" alt="Server Metrics" valign="top">
  <img src="https://github.com/user-attachments/assets/6cd2ec54-c828-481d-8def-683a095b7773" width="48%" alt="Log Aggregation" valign="top">
  <br>
  <img src="https://github.com/user-attachments/assets/098f4f0a-8ebc-4522-81bf-4a8c386145ef" width="48%" alt="Application Tracing" valign="top">
  <img src="https://github.com/user-attachments/assets/8b46337e-cec0-4c49-8a49-053ddc883c97" width="48%" alt="Uptime Probes" valign="top">
</div>

> 💡 **Executive Summary:** A self-hosted, multi-tenant monitoring platform for Linux servers, Docker containers, and databases. Built with the Grafana LGTM stack (Loki + Grafana + Tempo + Mimir). Add a server → get instant dashboards. No cloud, no SaaS, no per-agent pricing.

## ✨ Features

* 🖥️ **Server Metrics:** CPU, RAM, Disk, Network (Node Exporter).
* 🐳 **Container Monitoring:** Per-container stats (cAdvisor).
* 🗄️ **Database Monitoring:** MySQL, MariaDB, PostgreSQL: queries, connections, transactions.
* 📋 **Log Aggregation:** System logs in Grafana (Loki + Promtail).
* 🌐 **HTTP/SSL Probes:** Uptime and certificate expiry (Blackbox Exporter).
* 👥 **Multi-tenant:** Isolated dashboard per client, they only see their data.
* 🔒 **Secure:** Basic Auth gateway, isolated Grafana folders, viewer-only users.
* 💨 **Lightweight:** 4 GB RAM minimum for the server, ~128MB per client agent.

## 🏗️ Architecture

```text
[Client Server]  →  HTTPS (metrics + logs)  →  [Monitoring Server]
  Prometheus Agent                                Mimir (metrics)
  Promtail (logs)                                 Loki (logs)
  Node/Process/cAdvisor                           Grafana (dashboards)
  DB Exporters (optional)                         Blackbox (probes)

See docs/architecture.md for the full diagram.🚀 Quick Start1. Server Setup (5 minutes)Bashgit clone [https://github.com/rofilho/grafana-multitenant-stack.git](https://github.com/rofilho/grafana-multitenant-stack.git)
cd grafana-multitenant-stack
chmod +x scripts/setup.sh
./scripts/setup.sh
Open Grafana at http://YOUR_SERVER_IP:30052. Add a Client/ServerRun on the monitoring server:Bash./scripts/onboard_client.sh my-client monitoring.yourdomain.com
Copy the generated bundle to the client server:Bashscp -r ./dist/client-my-client/ user@client-server:~/
Run on the client server:Bashcd ~/client-my-client && docker compose up -d
Create the Grafana dashboard:Bash./scripts/deploy_tenant.sh MY-CLIENT
✅ Done! Data flows in within 30 seconds.📋 RequirementsRoleSpecificationsMinimum ResourcesMonitoring ServerUbuntu 22.04+, Docker 24+, Docker Compose v22+ vCPUs, 4+ GB RAM, 20+ GB diskClient ServerDocker 24+, Docker Compose v2~256 MB RAM for all agents combined📖 DocumentationGuideDescriptionServer SetupInstall the central monitoring serverAdding ClientsOnboard a new server to monitorDatabase MonitoringEnable MySQL / PostgreSQL metricsArchitectureHow it all fits together📦 Project StructurePlaintextmonitoring-stack/
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
🤝 ContributingContributions welcome! Open an issue or PR.License: MIT, use it freely, even commercially.

