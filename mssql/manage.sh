#!/bin/bash

# MSSQL Stack Management Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
ENV_FILE="${SCRIPT_DIR}/.env"

function show_help() {
    echo "MSSQL Stack Management"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start         Start MSSQL stack"
    echo "  stop          Stop MSSQL stack"
    echo "  restart       Restart MSSQL stack"
    echo "  status        Show service status"
    echo "  logs          Show logs for all services"
    echo "  logs <svc>    Show logs for specific service"
    echo "  backup        Trigger manual backup"
    echo "  restore       Restore from backup"
    echo "  query         Execute SQL query"
    echo "  shell         Connect to MSSQL shell"
    echo "  urls          Show service URLs"
    echo "  health        Check service health"
    echo "  cleanup       Clean old backups"
    echo "  stats         Show database statistics"
    echo "  help          Show this help message"
    echo ""
}

function check_external_network() {
    if ! docker network ls | grep -q "quick-compose_external-network"; then
        echo "Creating external network: quick-compose_external-network"
        docker network create quick-compose_external-network
    fi
}

function show_urls() {
    echo ""
    echo "🌐 MSSQL Stack URLs:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🗄️  Database Server:   localhost:1433 (sa/${SA_PASSWORD:-<check .env>})"
    echo "🖥️  CloudBeaver GUI:    http://mssql-gui.localhost (admin/admin123)"
    echo "⚙️  Adminer GUI:        http://mssql-adminer.localhost"
    echo "📁 Backup Directory:   ./mssql-backups/"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

function check_health() {
    echo ""
    echo "🏥 MSSQL Health Check:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Load environment variables
    if [ -f "$ENV_FILE" ]; then
        export $(cat "$ENV_FILE" | grep -v '^#' | xargs)
    fi
    
    # Check MSSQL
    echo -n "Checking MSSQL Server... "
    if docker-compose -f "$COMPOSE_FILE" exec -T mssql /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -Q "SELECT 1" > /dev/null 2>&1; then
        echo "✅ Healthy"
    else
        echo "❌ Unhealthy"
    fi
    
    # Check CloudBeaver
    echo -n "Checking CloudBeaver GUI... "
    if curl -s -f "http://localhost:8978" > /dev/null 2>&1; then
        echo "✅ Healthy"
    else
        echo "❌ Unhealthy"
    fi
    
    # Check Adminer
    echo -n "Checking Adminer... "
    if curl -s -f "http://localhost:8080" > /dev/null 2>&1; then
        echo "✅ Healthy"
    else
        echo "❌ Unhealthy"
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

function manual_backup() {
    echo "🔄 Triggering manual backup..."
    
    # Load environment variables
    if [ -f "$ENV_FILE" ]; then
        export $(cat "$ENV_FILE" | grep -v '^#' | xargs)
    fi
    
    ts="$(date +%Y%m%d_%H%M%S)"
    backup_file="/backups/manual_${MSSQL_DB}_backup_${ts}.bak"
    
    docker-compose -f "$COMPOSE_FILE" exec mssql /opt/mssql-tools/bin/sqlcmd \
        -S localhost -U sa -P "$SA_PASSWORD" \
        -Q "BACKUP DATABASE [$MSSQL_DB] TO DISK = '$backup_file' WITH COMPRESSION, INIT, FORMAT, STATS = 10"
    
    echo "✅ Manual backup completed: $backup_file"
}

function sql_shell() {
    echo "🔗 Connecting to MSSQL shell..."
    
    # Load environment variables
    if [ -f "$ENV_FILE" ]; then
        export $(cat "$ENV_FILE" | grep -v '^#' | xargs)
    fi
    
    docker-compose -f "$COMPOSE_FILE" exec mssql /opt/mssql-tools/bin/sqlcmd \
        -S localhost -U sa -P "$SA_PASSWORD"
}

function execute_query() {
    if [ -z "${2:-}" ]; then
        echo "❌ Please provide a SQL query"
        echo "Example: $0 query \"SELECT @@VERSION\""
        return 1
    fi
    
    # Load environment variables
    if [ -f "$ENV_FILE" ]; then
        export $(cat "$ENV_FILE" | grep -v '^#' | xargs)
    fi
    
    echo "🔍 Executing query: $2"
    docker-compose -f "$COMPOSE_FILE" exec mssql /opt/mssql-tools/bin/sqlcmd \
        -S localhost -U sa -P "$SA_PASSWORD" -Q "$2"
}

function show_stats() {
    echo "📊 Database Statistics:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Load environment variables
    if [ -f "$ENV_FILE" ]; then
        export $(cat "$ENV_FILE" | grep -v '^#' | xargs)
    fi
    
    # Database sizes
    echo "📋 Database Sizes:"
    docker-compose -f "$COMPOSE_FILE" exec mssql /opt/mssql-tools/bin/sqlcmd \
        -S localhost -U sa -P "$SA_PASSWORD" \
        -Q "SELECT name, size*8/1024 as 'Size (MB)' FROM sys.master_files WHERE type_desc = 'ROWS'"
    
    echo ""
    echo "💾 Memory Usage:"
    docker-compose -f "$COMPOSE_FILE" exec mssql /opt/mssql-tools/bin/sqlcmd \
        -S localhost -U sa -P "$SA_PASSWORD" \
        -Q "SELECT object_name, counter_name, cntr_value FROM sys.dm_os_performance_counters WHERE counter_name LIKE '%Memory%' AND cntr_value > 0"
    
    echo ""
    echo "📁 Backup Files:"
    ls -lah "${SCRIPT_DIR}/mssql-backups/"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

function cleanup_backups() {
    echo "🧹 Cleaning up old backups (keeping last 7 days)..."
    find "${SCRIPT_DIR}/mssql-backups" -name "*.bak" -type f -mtime +7 -delete 2>/dev/null || true
    echo "✅ Cleanup completed"
    echo ""
    echo "📁 Remaining backups:"
    ls -lah "${SCRIPT_DIR}/mssql-backups/"
}

case "${1:-}" in
    start)
        echo "🚀 Starting MSSQL Stack..."
        check_external_network
        docker-compose -f "$COMPOSE_FILE" up -d
        echo "✅ All services started!"
        show_urls
        ;;
    
    stop)
        echo "⏹️  Stopping MSSQL Stack..."
        docker-compose -f "$COMPOSE_FILE" stop
        echo "✅ All services stopped!"
        ;;
    
    restart)
        echo "🔄 Restarting MSSQL Stack..."
        check_external_network
        docker-compose -f "$COMPOSE_FILE" restart
        echo "✅ All services restarted!"
        show_urls
        ;;
    
    status)
        echo "📊 Service Status:"
        docker-compose -f "$COMPOSE_FILE" ps
        ;;
    
    logs)
        if [ -n "${2:-}" ]; then
            echo "📋 Showing logs for $2..."
            docker-compose -f "$COMPOSE_FILE" logs -f "$2"
        else
            echo "📋 Showing logs for all services..."
            docker-compose -f "$COMPOSE_FILE" logs -f
        fi
        ;;
    
    backup)
        manual_backup
        ;;
    
    restore)
        echo "🔄 Restore functionality - please implement based on your needs"
        echo "Example restore command is in the README.md"
        ;;
    
    query)
        execute_query "$@"
        ;;
    
    shell)
        sql_shell
        ;;
    
    urls)
        show_urls
        ;;
    
    health)
        check_health
        ;;
    
    cleanup)
        cleanup_backups
        ;;
    
    stats)
        show_stats
        ;;
    
    help|--help|-h)
        show_help
        ;;
    
    *)
        echo "❌ Unknown command: ${1:-}"
        echo ""
        show_help
        exit 1
        ;;
esac
