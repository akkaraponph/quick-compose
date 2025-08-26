# README — Deploy PostgreSQL 17 + one-shot/scheduled backups (Docker Compose)

This guide walks you through a clean setup to run PostgreSQL 17 and create timestamped compressed backups using a small Alpine sidecar.

---

## 1) Project layout

```
your-project/
├─ docker-compose.yml
├─ .env
├─ pgdata/              # (created automatically by Docker)
├─ pg-backups/          # backup files will appear here
└─ backup-scripts/
   └─ backup.sh
```

---

## 2) Secure your credentials (.env)

**Never** hard-code passwords in versioned files. Put them in an `.env` file (Compose reads this automatically):

**.env**
```dotenv
# Postgres
POSTGRES_DB=db_name
POSTGRES_USER=user_name
POSTGRES_PASSWORD=*Z({7oV0Mp*jF9&@$mAh

# Backup sidecar talks to the 'db' container via Docker network
POSTGRES_HOST=db

# (Optional) Timezone for cron examples later
TZ=Asia/Bangkok
```

---

## 3) Docker Compose file

```yaml
version: '3.8'

services:
  db:
    image: postgres:17
    restart: always
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      TZ: ${TZ}
    volumes:
      - ./pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  pg-backup:
    image: alpine:3.20
    container_name: pg_backup
    depends_on:
      - db
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_HOST: ${POSTGRES_HOST}
      TZ: ${TZ}
    volumes:
      - ./pg-backups:/backups
      - ./backup-scripts:/scripts
    entrypoint: [ "/bin/sh", "/scripts/backup.sh" ]
    restart: "no"
```

---

## 4) Backup script

**backup-scripts/backup.sh**
```sh
#!/bin/sh
set -euo pipefail

apk add --no-cache postgresql17-client gzip

sleep 10

FILE="/backups/${POSTGRES_DB}_backup_$(date +%Y%m%d_%H%M%S).sql.gz"
echo "Starting compressed backup to: $FILE"

export PGPASSWORD="${POSTGRES_PASSWORD}"

pg_dump -h "${POSTGRES_HOST}" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}"   | gzip > "${FILE}"

echo "Backup saved to $FILE"
```

---

Follow the rest of the steps from section 5 onwards as explained in the full guide.
