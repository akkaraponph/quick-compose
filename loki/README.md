# Loki Stack for Grafana Monitoring

This directory contains a complete observability stack using Grafana Loki for log aggregation, Prometheus for metrics, and Grafana for visualization.

## Components

- **Loki**: Log aggregation system
- **Promtail**: Log collection agent
- **Grafana**: Visualization and dashboards
- **Prometheus**: Metrics collection and storage
- **Node Exporter**: System metrics collector
- **cAdvisor**: Container metrics collector
- **AlertManager**: Alert management

## Quick Start

1. **Start the stack:**
   ```bash
   cd loki
   docker-compose up -d
   ```

2. **Access the services:**
   - Grafana: http://localhost:3000 (admin/admin123)
   - Prometheus: http://localhost:9090
   - Loki: http://localhost:3100
   - AlertManager: http://localhost:9093
   - cAdvisor: http://localhost:8080

3. **Check service status:**
   ```bash
   docker-compose ps
   ```

## Service Details

### Grafana (Port 3000)
- **Username**: admin
- **Password**: admin123
- Pre-configured with Loki and Prometheus datasources
- Includes sample dashboards for logs and system metrics

### Loki (Port 3100)
- Configured for local filesystem storage
- Receives logs from Promtail
- API endpoint: http://localhost:3100/loki/api/v1/push

### Promtail
- Collects logs from:
  - Docker containers (`/var/lib/docker/containers`)
  - System logs (`/var/log/syslog`)
  - Nginx logs (`/var/log/nginx/*.log`)

### Prometheus (Port 9090)
- Scrapes metrics from all services
- Configured with 15-second scrape interval
- Includes alerting rules integration

## Configuration Files

```
config/
├── loki-config.yaml              # Loki configuration
├── promtail-config.yaml          # Promtail log collection config
├── prometheus/
│   └── prometheus.yml            # Prometheus scrape config
├── alertmanager/
│   └── alertmanager.yml          # Alert routing config
└── grafana/
    ├── provisioning/
    │   ├── datasources/
    │   │   └── datasources.yml   # Auto-configured datasources
    │   └── dashboards/
    │       └── dashboards.yml    # Dashboard provisioning
    └── dashboards/
        ├── loki-logs-dashboard.json      # Log visualization
        └── system-metrics-dashboard.json # System metrics
```

## Using the Stack

### Viewing Logs in Grafana

1. Open Grafana at http://localhost:3000
2. Navigate to "Explore" or use the "Loki Logs Dashboard"
3. Use LogQL queries like:
   ```
   {job="containerlogs"}
   {job="containerlogs", container_name="nginx"}
   {job="syslog"} |= "error"
   ```

### Viewing Metrics

1. Use the "System Metrics Dashboard" for system monitoring
2. Create custom dashboards using Prometheus metrics
3. Example queries:
   ```
   up                                    # Service availability
   container_memory_usage_bytes         # Container memory usage
   rate(container_cpu_usage_seconds_total[5m])  # Container CPU rate
   ```

### Setting Up Alerts

1. Edit `config/alertmanager/alertmanager.yml` for notification settings
2. Configure email, Slack, or webhook notifications
3. Add alert rules to Prometheus configuration

## Networking

The stack uses two networks:
- `loki-network`: Internal communication between services
- `external-network`: External access (connects to your existing network)

## Data Persistence

Persistent volumes:
- `loki-data`: Loki logs and indexes
- `grafana-data`: Grafana configuration and dashboards
- `prometheus-data`: Prometheus metrics database

## Customization

### Adding More Log Sources

Edit `config/promtail-config.yaml` to add new log sources:

```yaml
scrape_configs:
  - job_name: myapp
    static_configs:
      - targets:
          - localhost
        labels:
          job: myapp
          __path__: /var/log/myapp/*.log
```

### Adding Prometheus Targets

Edit `config/prometheus/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'myapp'
    static_configs:
      - targets: ['myapp:8080']
```

### Custom Dashboards

1. Create dashboards in Grafana UI
2. Export JSON and save to `config/grafana/dashboards/`
3. Restart Grafana to load new dashboards

## Troubleshooting

### Check Service Health
```bash
# Check all services
docker-compose ps

# View logs
docker-compose logs loki
docker-compose logs promtail
docker-compose logs grafana

# Check Loki health
curl http://localhost:3100/ready

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets
```

### Common Issues

1. **Promtail not collecting logs**:
   - Check volume mounts for log directories
   - Verify promtail configuration syntax

2. **No data in Grafana**:
   - Verify datasource configuration
   - Check Loki/Prometheus connectivity
   - Confirm data is being collected

3. **High disk usage**:
   - Configure log retention in Loki config
   - Set up log rotation for source systems

## Security Notes

- Change default Grafana password in production
- Configure proper authentication for external access
- Use secrets management for sensitive configuration
- Restrict network access to monitoring ports

## Scaling

For production environments:
- Use external storage (S3, GCS) for Loki
- Deploy multiple Loki replicas
- Set up Grafana clustering
- Use external databases for Grafana

## Backup

Important data to backup:
- Grafana configuration: `grafana-data` volume
- Prometheus data: `prometheus-data` volume  
- Loki indexes: `loki-data` volume
- Configuration files in `config/` directory

## Integration with Other Services

This stack can be integrated with your other Docker Compose services by:
1. Adding them to the same external network
2. Configuring log forwarding to this Loki instance
3. Adding metrics endpoints to Prometheus configuration
