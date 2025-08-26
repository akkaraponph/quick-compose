#!/bin/sh
set -euo pipefail

apk add --no-cache postgresql17-client gzip

sleep 10

FILE="/backups/${POSTGRES_DB}_backup_$(date +%Y%m%d_%H%M%S).sql.gz"
echo "Starting compressed backup to: $FILE"

export PGPASSWORD="${POSTGRES_PASSWORD}"

pg_dump -h "${POSTGRES_HOST}" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}"   | gzip > "${FILE}"

echo "Backup saved to $FILE"
