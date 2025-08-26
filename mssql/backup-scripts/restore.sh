#!/bin/bash

# Database restore script
# Usage: ./restore.sh <backup_file> [database_name]

set -euo pipefail

BACKUP_FILE="$1"
DB_NAME="${2:-restored_db}"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Backup file not found: $BACKUP_FILE"
    exit 1
fi

# Load environment variables
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

echo "🔄 Restoring database '$DB_NAME' from backup: $BACKUP_FILE"

# Copy backup file to container
CONTAINER_BACKUP_PATH="/tmp/$(basename "$BACKUP_FILE")"
docker cp "$BACKUP_FILE" mssql:"$CONTAINER_BACKUP_PATH"

# Restore database
docker-compose exec mssql /opt/mssql-tools/bin/sqlcmd \
    -S localhost -U sa -P "$SA_PASSWORD" \
    -Q "RESTORE DATABASE [$DB_NAME] FROM DISK='$CONTAINER_BACKUP_PATH' WITH REPLACE, STATS = 10"

# Clean up temporary file
docker-compose exec mssql rm -f "$CONTAINER_BACKUP_PATH"

echo "✅ Database '$DB_NAME' restored successfully!"
