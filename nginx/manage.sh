#!/bin/bash

# Nginx Management Script for Quick Compose Stack

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yaml"

function show_help() {
    echo "Nginx Management for Quick Compose Stack"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start       Start nginx service"
    echo "  stop        Stop nginx service"
    echo "  restart     Restart nginx service"
    echo "  status      Show nginx status"
    echo "  logs        Show nginx logs"
    echo "  test        Test nginx configuration"
    echo "  reload      Reload nginx configuration"
    echo "  sites       List available sites"
    echo "  enable      Enable all available sites"
    echo "  urls        Show service URLs"
    echo "  setup-dns   Show DNS setup instructions"
    echo "  help        Show this help message"
    echo ""
}

function check_networks() {
    echo "🔍 Checking networks..."
    
    if ! docker network ls | grep -q "quick-compose_external-network"; then
        echo "⚠️  Creating external network: quick-compose_external-network"
        docker network create quick-compose_external-network
    else
        echo "✅ External network exists"
    fi
    
    if ! docker network ls | grep -q "^.*quick-compose$"; then
        echo "⚠️  Creating quick-compose network"
        docker network create quick-compose
    else
        echo "✅ Quick-compose network exists"
    fi
}

function show_urls() {
    echo ""
    echo "🌐 Available URLs:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🏠 Base Sites:"
    echo "   http://a.localhost"
    echo "   http://b.localhost"
    echo ""
    echo "📊 Loki Monitoring Stack:"
    echo "   http://grafana.localhost       (admin/admin123)"
    echo "   http://prometheus.localhost"
    echo "   http://loki.localhost"
    echo "   http://alertmanager.localhost"
    echo "   http://cadvisor.localhost"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

function setup_dns() {
    echo ""
    echo "🔧 DNS Setup Instructions:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📝 Add these entries to your hosts file:"
    echo ""
    cat "$SCRIPT_DIR/hosts-file-entries.txt" | grep "127.0.0.1"
    echo ""
    echo "📍 Hosts file locations:"
    echo "   Windows: C:\\Windows\\System32\\drivers\\etc\\hosts"
    echo "   Linux/Mac: /etc/hosts"
    echo ""
    echo "🔄 After editing, flush DNS cache:"
    echo "   Windows: ipconfig /flushdns"
    echo "   Linux: sudo systemctl restart systemd-resolved"
    echo "   Mac: sudo dscacheutil -flushcache"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

function list_sites() {
    echo ""
    echo "📂 Available Sites:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    for conf in "$SCRIPT_DIR/sites-available"/*.conf; do
        if [ -f "$conf" ]; then
            basename=$(basename "$conf" .conf)
            if [ -L "$SCRIPT_DIR/sites-enabled/$(basename "$conf")" ] || [ -f "$SCRIPT_DIR/sites-enabled/$(basename "$conf")" ]; then
                echo "✅ $basename.localhost (enabled)"
            else
                echo "❌ $basename.localhost (disabled)"
            fi
        fi
    done
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

function test_connectivity() {
    echo ""
    echo "🔍 Testing backend connectivity..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    services=("grafana:3000/api/health" "loki:3100/ready" "prometheus:9090/-/healthy" "alertmanager:9093/-/healthy" "cadvisor:8080/metrics")
    
    for service_check in "${services[@]}"; do
        IFS=':' read -r service endpoint <<< "$service_check"
        echo -n "Testing $service... "
        if docker-compose exec -T nginx wget -qO- --timeout=5 "http://$service_check" >/dev/null 2>&1; then
            echo "✅ OK"
        else
            echo "❌ Failed"
        fi
    done
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

case "${1:-}" in
    start)
        echo "🚀 Starting nginx service..."
        check_networks
        docker-compose -f "$COMPOSE_FILE" up -d
        echo "✅ Nginx started!"
        show_urls
        ;;
    
    stop)
        echo "⏹️  Stopping nginx service..."
        docker-compose -f "$COMPOSE_FILE" stop
        echo "✅ Nginx stopped!"
        ;;
    
    restart)
        echo "🔄 Restarting nginx service..."
        check_networks
        docker-compose -f "$COMPOSE_FILE" restart
        echo "✅ Nginx restarted!"
        show_urls
        ;;
    
    status)
        echo "📊 Nginx Status:"
        docker-compose -f "$COMPOSE_FILE" ps
        ;;
    
    logs)
        echo "📋 Showing nginx logs..."
        docker-compose -f "$COMPOSE_FILE" logs -f nginx
        ;;
    
    test)
        echo "🔍 Testing nginx configuration..."
        docker-compose -f "$COMPOSE_FILE" exec nginx nginx -t
        echo "✅ Configuration test complete!"
        ;;
    
    reload)
        echo "🔄 Reloading nginx configuration..."
        docker-compose -f "$COMPOSE_FILE" exec nginx nginx -s reload
        echo "✅ Configuration reloaded!"
        ;;
    
    sites)
        list_sites
        ;;
    
    enable)
        echo "🔧 Enabling all sites..."
        docker-compose -f "$COMPOSE_FILE" exec nginx /docker-entrypoint.d/99-enable-sites.sh
        echo "✅ All sites enabled!"
        ;;
    
    urls)
        show_urls
        ;;
    
    setup-dns)
        setup_dns
        ;;
    
    connectivity)
        test_connectivity
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
