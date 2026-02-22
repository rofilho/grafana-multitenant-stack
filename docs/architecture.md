# Architecture Overview

## System Overview

```
┌─────────────────────────────────────────────────────┐
│                  CLIENT SERVERS                      │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │  Docker Agent Bundle (per client)            │   │
│  │  ┌─────────────┐  ┌────────────────────────┐ │   │
│  │  │ Prometheus  │  │      Promtail          │ │   │
│  │  │   Agent     │  │  (Log Collector)       │ │   │
│  │  │             │  │                        │ │   │
│  │  │ Scrapes:    │  │ Reads: /var/log/*      │ │   │
│  │  │ - Node Exp  │  │                        │ │   │
│  │  │ - Process   │  └──────────┬─────────────┘ │   │
│  │  │ - cAdvisor  │             │ push logs      │   │
│  │  │ - DB Export │             │                │   │
│  │  └──────┬──────┘             │                │   │
│  │         │ push metrics       │                │   │
│  └─────────┼────────────────────┼────────────────┘   │
│            │                    │                     │
└────────────┼────────────────────┼─────────────────────┘
             │ HTTPS remote_write │ HTTPS push
             ▼                    ▼
┌─────────────────────────────────────────────────────┐
│              CENTRAL MONITORING SERVER               │
│                                                      │
│  ┌──────────┐   ┌────────────────────────────────┐  │
│  │  Nginx   │   │  Blackbox Exporter             │  │
│  │ Gateway  │──▶│  (HTTP/SSL probes)              │  │
│  │ + Auth   │   └────────────────┬───────────────┘  │
│  └────┬─────┘                    │                   │
│       │                          │                   │
│   ┌───▼──────┐   ┌──────────┐   │   ┌────────────┐  │
│   │  Mimir   │   │   Loki   │   │   │   Tempo    │  │
│   │(Metrics) │   │  (Logs)  │   │   │ (Tracing)  │  │
│   └───┬──────┘   └────┬─────┘   │   └─────┬──────┘  │
│       │               │         │         │          │
│   ┌───▼───────────────▼─────────▼─────────▼──────┐  │
│   │              Grafana                          │  │
│   │  - Multi-tenant (isolated per client)        │  │
│   │  - Dashboard: CPU, RAM, Disk, Network        │  │
│   │  - Auto-detects: Containers, Databases        │  │
│   │  - Logs explorer                             │  │
│   └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

## Data Flow

| Flow | Protocol | Authentication |
|---|---|---|
| Client → Mimir (metrics) | HTTPS remote_write | Basic Auth (Nginx gateway) |
| Client → Loki (logs) | HTTPS push | Basic Auth (Nginx gateway) |
| Blackbox → Sites | HTTPS GET | None (public probes) |
| User → Grafana | HTTPS | Grafana login |

## Multi-tenant Isolation

Each client is isolated using:
1. **Metric label:** `client="client-name"` on all metrics/logs
2. **Grafana folder:** Each client has its own folder with permissions
3. **Grafana user:** Each client gets a read-only Viewer user
4. **Dashboard:** One dashboard per client, pre-filtered to their data
