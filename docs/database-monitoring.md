# Database Monitoring

Enable deep monitoring of MySQL/MariaDB or PostgreSQL databases.  
When active, the dashboard shows: query performance, connections, transaction rates, slow queries.

---

## MySQL / MariaDB

### Step 1 — Create monitor user (on the client's DB)

Connect to MySQL and run:

```sql
CREATE USER 'monitor'@'localhost' IDENTIFIED BY 'your-strong-password';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'monitor'@'localhost';
FLUSH PRIVILEGES;
```

### Step 2 — Add mysql-exporter to client's docker-compose.yml

Add this service to the client's `docker-compose.yml`:

```yaml
  mysql-exporter:
    image: prom/mysqld-exporter:v0.15.1
    container_name: mysql-exporter
    environment:
      - DATA_SOURCE_NAME=monitor:your-strong-password@(localhost:3306)/
    network_mode: host
    restart: always
```

### Step 3 — Add scrape job to client's prometheus.yml

Add to the `scrape_configs` section:

```yaml
  - job_name: 'mysql_exporter'
    static_configs:
      - targets: ['localhost:9104']
```

Then restart: `docker compose up -d --force-recreate`

---

## PostgreSQL

### Step 1 — Create monitor user (on the client's DB)

```sql
CREATE USER monitor WITH PASSWORD 'your-strong-password';
GRANT pg_monitor TO monitor;
```

### Step 2 — Add postgres-exporter to client's docker-compose.yml

```yaml
  postgres-exporter:
    image: prometheuscommunity/postgres-exporter:latest
    container_name: postgres-exporter
    environment:
      - DATA_SOURCE_NAME=postgresql://monitor:your-strong-password@localhost:5432/postgres?sslmode=disable
    network_mode: host
    restart: always
```

### Step 3 — Add scrape job to client's prometheus.yml

```yaml
  - job_name: 'postgres_exporter'
    static_configs:
      - targets: ['localhost:9187']
```

Then restart: `docker compose up -d --force-recreate`

---

## Verify It's Working

On the monitoring server, check if metrics arrived:

```bash
# MySQL
curl -s -G --data-urlencode "query=mysql_up{client='your-client'}" \
  http://localhost:9009/prometheus/api/v1/query | jq .

# PostgreSQL
curl -s -G --data-urlencode "query=pg_up{client='your-client'}" \
  http://localhost:9009/prometheus/api/v1/query | jq .
```

Expected: `"value": [timestamp, "1"]` means UP ✅

---

## Security Notes

- The `monitor` user has **read-only** access to statistics — it cannot read your data
- Passwords are stored only in the client's `docker-compose.yml` (not in Grafana)
- Use a unique strong password per client
