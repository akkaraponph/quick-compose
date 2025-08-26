# README — SQL Server 2022 (Linux) on Docker with Hourly Backups + Memory/RAM Optimization

This guide sets up Microsoft SQL Server 2022 on Linux via Docker Compose with a sidecar container that performs **hourly backups** using `sqlcmd`. It also covers **RAM usage control** and best practices to **reduce memory consumption**.

---

## 1) Project structure

```
mssql-stack/
├─ docker-compose.yml
├─ .env
├─ mssql-data/                 # SQL Server data directory (created by Docker)
├─ mssql-backups/              # .bak files will be stored here
├─ mssql-conf/                 # optional: custom mssql.conf to cap RAM
└─ backup-scripts/
   └─ backup.sh
```

Create folders:
```bash
mkdir -p mssql-data mssql-backups mssql-conf backup-scripts
```

---

## 2) Environment variables

**.env**
```dotenv
# SQL Server settings
ACCEPT_EULA=Y
SA_PASSWORD=&P8ehx_eWwgi[pNDpC@q
MSSQL_HOST=mssql
MSSQL_DB=master

# Optional: time zone for logs inside containers
TZ=Asia/Bangkok
```

> 🔐 A strong random SA password has been generated for you above. You can replace it anytime.

---

## 3) docker-compose.yml

This compose file runs SQL Server 2022 and a backup sidecar that performs an **hourly BACKUP DATABASE ... WITH COMPRESSION**. It also includes **resource limits** examples.

```yaml
version: '3.8'

networks:
  app:

services:
  mssql:
    image: mcr.microsoft.com/mssql/server:2022-latest
    container_name: mssql
    environment:
      - ACCEPT_EULA=${ACCEPT_EULA}
      - SA_PASSWORD=${SA_PASSWORD}
      - TZ=${TZ}
    ports:
      - "1433:1433"
    volumes:
      - ./mssql-data:/var/opt/mssql
      # OPTIONAL: cap SQL Server max memory by mounting mssql.conf
      # - ./mssql-conf/mssql.conf:/var/opt/mssql/mssql.conf:ro
    restart: unless-stopped
    networks:
      - app

    # ---- Optional container resource limits (non‑Swarm) ----
    # Docker Compose (classic) accepts 'mem_limit' and 'cpus' fields.
    # These help keep the container's OS-level memory usage in check.
    # Uncomment if desired:
    # mem_limit: 4g
    # cpus: "2.0"

    # ---- Swarm-only alternative ----
    # deploy:
    #   resources:
    #     limits:
    #       memory: 4G
    #       cpus: "2.0"

  mssql-backup:
    image: mcr.microsoft.com/mssql-tools
    container_name: mssql_backup
    depends_on:
      - mssql
    environment:
      - SA_PASSWORD=${SA_PASSWORD}
      - MSSQL_HOST=${MSSQL_HOST}
      - MSSQL_DB=${MSSQL_DB}
      - TZ=${TZ}
    volumes:
      - ./mssql-backups:/backups
      - ./backup-scripts:/scripts
    entrypoint: ["/bin/bash", "/scripts/backup.sh"]
    restart: unless-stopped
    networks:
      - app

volumes:
  # Note: not used when paths are bind-mounted. Declared for clarity.
  mssql_data:
```

> **Note:** If you prefer a one-shot backup run, change `restart: unless-stopped` on `mssql-backup` to `"no"` and run `docker compose run --rm mssql-backup` when needed.

---

## 4) Backup script

**backup-scripts/backup.sh**
```bash
#!/bin/bash
set -euo pipefail

# Wait for SQL Server to be ready
sleep 20

# Run forever; each loop performs a compressed full backup
while true; do
  ts="$(date +%Y%m%d_%H%M%S)"
  echo "Starting backup at $(date)"
  /opt/mssql-tools/bin/sqlcmd \
    -S "$MSSQL_HOST" -U sa -P "$SA_PASSWORD" \
    -Q "BACKUP DATABASE [$MSSQL_DB] TO DISK = '/backups/${MSSQL_DB}_backup_${ts}.bak' WITH COMPRESSION, INIT"
  echo "Backup completed at $(date)"

  # Sleep 1 hour between backups
  sleep 3600
done
```

Make it executable:
```bash
chmod +x backup-scripts/backup.sh
```

Backups will appear in `mssql-backups/` as:
```
{DBNAME}_backup_YYYYMMDD_HHMMSS.bak
```

> 💡 Use `WITH COMPRESSION` to reduce backup size and IO. The backup file remains `.bak` but is compressed internally by SQL Server.

---

## 5) (Optional) Cap SQL Server RAM usage from inside SQL Server

SQL Server on Linux supports a config file `/var/opt/mssql/mssql.conf`. To **limit the buffer pool** and reduce host RAM usage, create:

**mssql-conf/mssql.conf**
```ini
[memory]
# Limit SQL Server max memory (in MB)
memorylimitmb = 4096
```

Then **uncomment the mssql.conf bind mount** in `docker-compose.yml`:
```yaml
- ./mssql-conf/mssql.conf:/var/opt/mssql/mssql.conf:ro
```

Restart the container to apply:
```bash
docker compose up -d
```

> ✅ This approach is preferred over ad-hoc commands because it survives restarts and keeps config versioned.

---

## 6) Start the stack

```bash
docker compose up -d
```

Check logs:
```bash
docker compose logs -f mssql
docker compose logs -f mssql-backup
```

---

## 7) Restore a backup

From your host (with `sqlcmd` available) or using the tools image:

```bash
# Example: restore backup into the same container, replacing DB
BACKUP=./mssql-backups/master_backup_YYYYMMDD_HHMMSS.bak

docker run --rm -it --network $(basename "$PWD")_default   -v "$PWD/mssql-backups":/restore   mcr.microsoft.com/mssql-tools   /bin/bash -lc "     /opt/mssql-tools/bin/sqlcmd -S mssql -U sa -P '$SA_PASSWORD' -Q "
    ALTER DATABASE [$MSSQL_DB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    RESTORE DATABASE [$MSSQL_DB] FROM DISK='/restore/$(basename "$BACKUP")' WITH REPLACE;
    ALTER DATABASE [$MSSQL_DB] SET MULTI_USER;" "
```

> If restoring a different DB name, change `[$MSSQL_DB]` accordingly.

---

## 8) Strategies to reduce RAM usage

1. **Limit container memory (host level)**  
   Use `mem_limit` (Compose classic) or `deploy.resources.limits.memory` (Swarm). Example: 4 GB.

2. **Limit SQL Server max memory (engine level)**  
   Use `mssql.conf` with `memorylimitmb = <MB>` as shown above. Start conservative (e.g., 2048–4096 MB).

3. **Right-size tempdb**  
   Large tempdb consumes memory and disk. For smaller environments, reduce initial size and files:
   ```sql
   USE master;
   ALTER DATABASE tempdb MODIFY FILE (NAME = tempdev, SIZE = 256MB);
   ALTER DATABASE tempdb MODIFY FILE (NAME = templog, SIZE = 256MB);
   ```
   (Run via `sqlcmd` once; tempdb recreates each start with these settings persisted.)

4. **Disable features you don’t use**  
   - Reduce unnecessary agents/services (if using separate tooling).
   - Keep indexes lean; rebuild/defrag during low load with resource governor (if applicable).

5. **Backup with COMPRESSION**  
   Already enabled in the script—reduces IO and buffer pressure during backups.

6. **Monitor usage**  
   - Container: `docker stats`  
   - SQL memory:  
     ```sql
     SELECT object_name, counter_name, cntr_value
     FROM sys.dm_os_performance_counters
     WHERE counter_name LIKE '%Memory%';
     ```

---

## 9) Health checks & readiness (optional)

Add a simple healthcheck to `mssql` service:
```yaml
healthcheck:
  test: ["CMD-SHELL", "/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P ${SA_PASSWORD} -Q 'SELECT 1' || exit 1"]
  interval: 15s
  timeout: 5s
  retries: 10
```

Then, in `mssql-backup`, set `depends_on` with condition if you use Compose v2.20+:
```yaml
depends_on:
  mssql:
    condition: service_healthy
```

---

## 10) Quick start

```bash
# 1) Create folders
mkdir -p mssql-data mssql-backups mssql-conf backup-scripts

# 2) Create .env (copy from section 2; keep the generated SA password)
# 3) Create docker-compose.yml (section 3)
# 4) Create backup-scripts/backup.sh (section 4) and make it executable
chmod +x backup-scripts/backup.sh

# 5) (Optional) Add mssql-conf/mssql.conf to cap SQL memory (section 5)

# 6) Launch
docker compose up -d

# 7) Verify backups appear hourly in ./mssql-backups
```

---

## 11) Troubleshooting

- **Login failed for user 'sa'**: confirm `SA_PASSWORD` in `.env` and that it satisfies complexity (at least 8 chars, upper, lower, digit, symbol).
- **Permission denied writing backups**: ensure host folder permissions allow write:
  ```bash
  chmod -R u+rw ./mssql-backups
  ```
- **High RAM usage**:
  - Apply `mssql.conf` memory cap (section 5).
  - Consider lowering `mem_limit` or Swarm limits.
  - Reduce tempdb sizes and background jobs.
- **Container restarts repeatedly**: check `docker compose logs mssql` for errors (e.g., bad config in `mssql.conf`).

---

Happy querying! 🚀
