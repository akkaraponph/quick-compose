#!/bin/bash
set -euo pipefail

echo "=== MSSQL Backup Script Starting ==="
echo "Host: $MSSQL_HOST"
echo "Database: $MSSQL_DB"
echo "Time Zone: ${TZ:-UTC}"
echo "======================================="

# Wait for SQL Server to be ready
echo "Waiting for SQL Server to be ready..."
sleep 30

# Function to check if SQL Server is ready
check_sql_ready() {
    /opt/mssql-tools/bin/sqlcmd -S "$MSSQL_HOST" -U sa -P "$SA_PASSWORD" -Q "SELECT 1" > /dev/null 2>&1
    return $?
}

# Wait up to 5 minutes for SQL Server to be ready
max_attempts=60
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if check_sql_ready; then
        echo "SQL Server is ready!"
        break
    else
        echo "Waiting for SQL Server... (attempt $((attempt + 1))/$max_attempts)"
        sleep 5
        attempt=$((attempt + 1))
    fi
done

if [ $attempt -eq $max_attempts ]; then
    echo "ERROR: SQL Server did not become ready after $max_attempts attempts"
    exit 1
fi

# Create backups directory if it doesn't exist
mkdir -p /backups

# Function to perform backup
perform_backup() {
    local db_name="$1"
    local ts="$(date +%Y%m%d_%H%M%S)"
    local backup_file="/backups/${db_name}_backup_${ts}.bak"
    
    echo "Starting backup of database '$db_name' at $(date)"
    
    if /opt/mssql-tools/bin/sqlcmd \
        -S "$MSSQL_HOST" -U sa -P "$SA_PASSWORD" \
        -Q "BACKUP DATABASE [$db_name] TO DISK = '$backup_file' WITH COMPRESSION, INIT, FORMAT, STATS = 10"; then
        
        echo "✅ Backup completed successfully at $(date)"
        echo "📁 Backup file: $backup_file"
        
        # Get backup file size
        if [ -f "$backup_file" ]; then
            local size=$(du -h "$backup_file" | cut -f1)
            echo "📊 Backup size: $size"
        fi
    else
        echo "❌ Backup failed at $(date)"
        return 1
    fi
}

# Function to clean old backups (keep last 7 days)
cleanup_old_backups() {
    echo "🧹 Cleaning up old backups (keeping last 7 days)..."
    find /backups -name "*.bak" -type f -mtime +7 -delete 2>/dev/null || true
    echo "✅ Cleanup completed"
}

# Get list of user databases to backup
get_user_databases() {
    /opt/mssql-tools/bin/sqlcmd -S "$MSSQL_HOST" -U sa -P "$SA_PASSWORD" \
        -h -1 -W \
        -Q "SELECT name FROM sys.databases WHERE database_id > 4 AND state = 0" 2>/dev/null | grep -v "^$" || echo ""
}

echo "🚀 Starting backup loop..."

# Run forever; each loop performs a compressed full backup
while true; do
    echo ""
    echo "================================================"
    echo "🔄 Backup cycle started at $(date)"
    echo "================================================"
    
    # Always backup the master database
    perform_backup "$MSSQL_DB"
    
    # Get and backup user databases
    user_dbs=$(get_user_databases)
    if [ -n "$user_dbs" ]; then
        echo "📋 Found user databases to backup:"
        echo "$user_dbs"
        echo ""
        
        while IFS= read -r db_name; do
            if [ -n "$db_name" ] && [ "$db_name" != "$MSSQL_DB" ]; then
                perform_backup "$db_name"
            fi
        done <<< "$user_dbs"
    else
        echo "ℹ️  No user databases found, only master database backed up"
    fi
    
    # Cleanup old backups
    cleanup_old_backups
    
    echo ""
    echo "💤 Backup cycle completed. Sleeping for 1 hour..."
    echo "📅 Next backup scheduled for $(date -d '+1 hour')"
    echo "================================================"
    
    # Sleep 1 hour between backups
    sleep 3600
done
