# Nginx Configuration for Quick Compose Stack

This nginx configuration provides reverse proxy access to all services in the Quick Compose stack, including the complete Loki monitoring stack.

## Services Available

### Base Services
- **a.localhost** - Static site A
- **b.localhost** - Static site B

### Loki Stack Services
- **grafana.localhost** - Grafana Dashboard (Port 3000)
- **loki.localhost** - Loki Log Aggregation (Port 3100)
- **prometheus.localhost** - Prometheus Metrics (Port 9090)
- **alertmanager.localhost** - AlertManager (Port 9093)
- **cadvisor.localhost** - cAdvisor Container Metrics (Port 8080)

## Setup Instructions

### 1. Configure DNS (Hosts File)

**Windows:**
```cmd
# Open as Administrator
notepad C:\Windows\System32\drivers\etc\hosts

# Add these lines:
127.0.0.1   a.localhost
127.0.0.1   b.localhost
127.0.0.1   grafana.localhost
127.0.0.1   loki.localhost
127.0.0.1   prometheus.localhost
127.0.0.1   alertmanager.localhost
127.0.0.1   cadvisor.localhost

# Flush DNS cache
ipconfig /flushdns
```

**Linux/Mac:**
```bash
# Edit hosts file
sudo nano /etc/hosts

# Add the same entries as above

# Flush DNS (Linux)
sudo systemctl restart systemd-resolved

# Flush DNS (Mac)
sudo dscacheutil -flushcache
```

### 2. Start Services

First, ensure the external network exists and start the Loki stack:
```bash
# Create external network if it doesn't exist
docker network create quick-compose_external-network

# Start Loki stack
cd ../loki
./manage.sh start

# Start nginx
cd ../nginx
docker-compose up -d
```

## Configuration Files

### Site Configurations
- `sites-available/grafana.conf` - Grafana proxy with WebSocket support
- `sites-available/loki.conf` - Loki with special handling for log ingestion
- `sites-available/prometheus.conf` - Prometheus with API endpoint handling
- `sites-available/alertmanager.conf` - AlertManager configuration
- `sites-available/cadvisor.conf` - cAdvisor container metrics

### Key Features
- **Health Check Endpoints** - All services have `/health` or `/-/healthy` endpoints
- **Static Asset Caching** - CSS, JS, and image files cached for 1 hour
- **WebSocket Support** - Enabled for Grafana live updates
- **Large File Support** - Increased client_max_body_size for log ingestion
- **Detailed Logging** - Separate access/error logs for each service

## Network Configuration

The nginx service connects to two networks:
- `quick-compose` - Legacy network for existing services
- `external-network` - Shared network with Loki stack services

## Troubleshooting

### Check Service Status
```bash
# Check nginx status
docker-compose ps

# Check nginx logs
docker-compose logs nginx

# Test nginx configuration
docker-compose exec nginx nginx -t
```

### DNS Issues
```bash
# Test DNS resolution
nslookup grafana.localhost
ping grafana.localhost

# Windows: Flush DNS
ipconfig /flushdns

# Restart browser after DNS changes
```

### Service Connectivity
```bash
# Test backend connectivity from nginx container
docker-compose exec nginx wget -qO- http://grafana:3000/api/health
docker-compose exec nginx wget -qO- http://loki:3100/ready
docker-compose exec nginx wget -qO- http://prometheus:9090/-/healthy
```

### Common Issues

1. **502 Bad Gateway**
   - Ensure Loki stack is running: `cd ../loki && ./manage.sh status`
   - Check network connectivity between nginx and backend services
   - Verify service names in nginx configs match container names

2. **DNS Not Resolving**
   - Verify hosts file entries are correct
   - Flush DNS cache
   - Restart browser
   - Check for typos in domain names

3. **WebSocket Issues (Grafana)**
   - Ensure `proxy_http_version 1.1` is set
   - Verify `Upgrade` and `Connection` headers are configured
   - Check browser console for WebSocket errors

## Service URLs

Once everything is running:

- **🏠 Main Sites:**
  - http://a.localhost
  - http://b.localhost

- **📊 Monitoring Stack:**
  - http://grafana.localhost (admin/admin123)
  - http://prometheus.localhost
  - http://loki.localhost
  - http://alertmanager.localhost
  - http://cadvisor.localhost

## Security Notes

- All services are accessible without authentication through nginx
- Grafana has default credentials (admin/admin123)
- Consider adding basic auth for production environments
- Monitor access logs for security issues

## Performance Optimization

- Static assets are cached for 1 hour
- Gzip compression is enabled globally
- Connection keepalive is set to 65 seconds
- Worker processes auto-scale based on CPU cores

## Monitoring

Each service logs separately:
- `/var/log/nginx/grafana_access.log`
- `/var/log/nginx/loki_access.log`
- `/var/log/nginx/prometheus_access.log`
- `/var/log/nginx/alertmanager_access.log`
- `/var/log/nginx/cadvisor_access.log`

Access these logs with:
```bash
docker-compose exec nginx tail -f /var/log/nginx/grafana_access.log
```
