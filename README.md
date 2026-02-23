📊 Monitoring StackA self-hosted, multi-tenant monitoring platform for Linux servers, Docker containers, and databases. Built with the Grafana LGTM stack (Loki + Grafana + Tempo + Mimir).🖥️ Dashboards OverviewInfrastructure & MetricsLogs & SecurityApplication TracingUptime & SSL ProbesAdd a server → get instant dashboards. No cloud, no SaaS, no per-agent pricing.✨ Features🖥️ Server Metrics: CPU, RAM, Disk, Network (Node Exporter)🐳 Container Monitoring: Per-container stats (cAdvisor)🗄️ Database Monitoring: MySQL, MariaDB, PostgreSQL — queries, connections, transactions📋 Log Aggregation: System logs in Grafana (Loki + Promtail)🌐 HTTP/SSL Probes: Uptime and certificate expiry (Blackbox Exporter)👥 Multi-tenant: Isolated dashboard per client — they only see their data🔒 Secure: Basic Auth gateway, isolated Grafana folders, viewer-only users💨 Lightweight: 4 GB RAM minimum for the server, ~128MB per client agent🏗️ ArchitecturePlaintext[Client Server]  →  HTTPS (metrics + logs)  →  [Monitoring Server]
  Prometheus Agent                                Mimir (metrics)
  Promtail (logs)                                 Loki (logs)
  Node/Process/cAdvisor                           Grafana (dashboards)
  DB Exporters (optional)                         Blackbox (probes)
📖 See docs/architecture.md for the full diagram.🚀 Quick Start1. Server Setup (5 minutes)Bashgit clone https://github.com/rofilho/grafana-multitenant-stack.git
cd grafana-multitenant-stack
chmod +x scripts/setup.sh
./scripts/setup.sh
Open Grafana at http://YOUR_SERVER_IP:30052. Add a Client/ServerRun on the monitoring server:Bash./scripts/onboard_client.sh my-client monitoring.yourdomain.com
Copy the generated bundle to the client server:Bashscp -r ./dist/client-my-client/ user@client-server:~/
Run on the client server:Bashcd ~/client-my-client && docker compose up -d
Finalize in Grafana:Bash./scripts/deploy_tenant.sh MY-CLIENT
📋 RequirementsRoleSpecificationsMonitoring ServerUbuntu 22.04+, Docker 24+, 2+ vCPUs, 4+ GB RAMClient ServerDocker 24+, ~256 MB RAM for all agents📦 Project StructurePlaintextmonitoring-stack/
├── docker-compose.yml          ← Central stack (Grafana + Mimir + Loki + Tempo)
├── central-prometheus.yml      ← HTTP probes config
├── configs/                    ← Service configs (Loki, Mimir, Tempo, Grafana)
├── scripts/
│   ├── setup.sh                ← Interactive setup
│   ├── onboard_client.sh       ← Generate client bundle
│   └── deploy_tenant.sh        ← Create isolated dashboard
└── docs/                       ← Full documentation
🤝 Contributing & LicenseContributions welcome! Open an issue or PR.License: MIT — use it freely, even commercially.
