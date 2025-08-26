#!/bin/bash

# Loki Stack Management Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yaml"

function show_help() {
    echo "Loki Stack Management"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start       Start all services"
    echo "  stop        Stop all services"
    echo "  restart     Restart all services"
    echo "  status      Show service status"
    echo "  logs        Show logs for all services"
    echo "  logs <svc>  Show logs for specific service"
    echo "  pull        Pull latest images"
    echo "  down        Stop and remove all containers"
    echo "  urls        Show service URLs"
    echo "  health      Check service health"
    echo "  help        Show this help message"
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
    echo "🌐 Service URLs:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Grafana:         http://localhost:3000   (admin/admin123)"
    echo "📈 Prometheus:      http://localhost:9090"
    echo "📝 Loki:            http://localhost:3100"
    echo "🚨 AlertManager:    http://localhost:9093"
    echo "📦 cAdvisor:        http://localhost:8080"
    echo "🖥️  Node Exporter:   http://localhost:9100"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

function check_health() {
    echo ""
    echo "🏥 Health Check:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    services=("loki:3100/ready" "grafana:3000/api/health" "prometheus:9090/-/healthy" "alertmanager:9093/-/healthy")
    
    for service_check in "${services[@]}"; do
        IFS=':' read -r service endpoint <<< "$service_check"
        echo -n "Checking $service... "
        if curl -s -f "http://localhost:$endpoint" > /dev/null 2>&1; then
            echo "✅ Healthy"
        else
            echo "❌ Unhealthy"
        fi
    done
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

case "${1:-}" in
    start)
        echo "🚀 Starting Loki Stack..."
        check_external_network
        docker-compose -f "$COMPOSE_FILE" up -d
        echo "✅ All services started!"
        show_urls
        ;;
    
    stop)
        echo "⏹️  Stopping Loki Stack..."
        docker-compose -f "$COMPOSE_FILE" stop
        echo "✅ All services stopped!"
        ;;
    
    restart)
        echo "🔄 Restarting Loki Stack..."
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
    
    pull)
        echo "📥 Pulling latest images..."
        docker-compose -f "$COMPOSE_FILE" pull
        echo "✅ Images updated!"
        ;;
    
    down)
        echo "🧹 Stopping and removing all containers..."
        docker-compose -f "$COMPOSE_FILE" down
        echo "✅ All containers removed!"
        ;;
    
    urls)
        show_urls
        ;;
    
    health)
        check_health
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
