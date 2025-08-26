# MSSQL Stack Implementation - Complete Setup

This implementation provides a complete Microsoft SQL Server 2022 stack based on the specifications in `README_MSSQL.md`, with additional enhancements for production use.

## 🏗️ **Complete Stack Components:**

### **Core Services:**
- **MSSQL Server 2022** - Main database server with memory optimization
- **Automated Backup** - Hourly compressed backups with cleanup
- **CloudBeaver** - Modern web-based database GUI
- **Adminer** - Lightweight database administration tool

### **Enhanced Features:**
- **Nginx Integration** - Domain-based access to GUI tools
- **Health Checks** - Comprehensive service monitoring
- **Memory Optimization** - RAM usage control and configuration
- **Network Integration** - External network connectivity
- **Management Scripts** - Easy administration tools

## 📁 **Directory Structure:**
```
mssql/
├── docker-compose.yml           # Main stack configuration
├── .env                         # Environment variables
├── manage.sh                    # Management script
├── README-IMPLEMENTATION.md     # This file
├── README_MSSQL.md             # Original specifications
├── mssql-data/                 # SQL Server data files
├── mssql-backups/              # Backup storage
├── mssql-conf/
│   └── mssql.conf              # SQL Server configuration
├── cloudbeaver-data/           # CloudBeaver workspace
├── backup-scripts/
│   ├── backup.sh               # Automated backup script
│   └── restore.sh              # Database restore utility
└── sql-scripts/
    └── init-database.sql       # Database initialization
```

## 🔧 **Configuration Details:**

### **Environment Variables (.env):**
```env
ACCEPT_EULA=Y                    # Accept SQL Server EULA
SA_PASSWORD=&P8ehx_eWwgi[pNDpC@q # Strong SA password
MSSQL_HOST=mssql                 # Database hostname
MSSQL_DB=master                  # Default database
TZ=Asia/Bangkok                  # Timezone
```

### **Memory Optimization:**
- **Container Limit**: 4GB RAM, 2 CPUs
- **SQL Server Limit**: 4096MB buffer pool
- **Health Checks**: 30-second intervals
- **Startup Grace**: 60-second start period

### **Backup Configuration:**
- **Frequency**: Hourly automated backups
- **Compression**: Enabled for space efficiency
- **Retention**: 7 days automatic cleanup
- **Format**: `{DB}_backup_YYYYMMDD_HHMMSS.bak`

## 🚀 **Quick Start:**

### 1. **Start the Stack:**
```bash
cd mssql
./manage.sh start
```

### 2. **Access Services:**
- **Database**: `localhost:1433` (sa/&P8ehx_eWwgi[pNDpC@q)
- **CloudBeaver**: http://mssql-gui.localhost (admin/admin123)
- **Adminer**: http://mssql-adminer.localhost

### 3. **Initialize Sample Database:**
```bash
./manage.sh query "$(cat sql-scripts/init-database.sql)"
```

## 🛠️ **Management Commands:**

### **Basic Operations:**
```bash
./manage.sh start         # Start all services
./manage.sh stop          # Stop all services
./manage.sh restart       # Restart all services
./manage.sh status        # Show service status
./manage.sh health        # Health check all services
```

### **Database Operations:**
```bash
./manage.sh shell         # Connect to SQL shell
./manage.sh backup        # Manual backup
./manage.sh stats         # Database statistics
./manage.sh query "SQL"   # Execute SQL query
```

### **Maintenance:**
```bash
./manage.sh logs          # View all logs
./manage.sh cleanup       # Clean old backups
./manage.sh urls          # Show service URLs
```

## 🌐 **Nginx Integration:**

The stack includes nginx configurations for web access:

### **Domain Mappings:**
- `mssql-gui.localhost` → CloudBeaver (Port 8978)
- `mssql-adminer.localhost` → Adminer (Port 8080)

### **Configuration Features:**
- **Large File Support** - 100MB uploads for database imports
- **Long Timeouts** - 10-minute timeouts for complex queries
- **Static Caching** - 1-hour cache for UI assets
- **Security Headers** - XSS protection and frame options
- **Separate Logging** - Individual logs per service

### **Setup DNS:**
Add to your hosts file (`C:\Windows\System32\drivers\etc\hosts`):
```
127.0.0.1   mssql-gui.localhost
127.0.0.1   mssql-adminer.localhost
```

## 🔒 **Security Configuration:**

### **Default Credentials:**
- **SQL Server SA**: `&P8ehx_eWwgi[pNDpC@q`
- **CloudBeaver**: admin/admin123
- **Adminer**: No default login (uses SA credentials)

### **Security Features:**
- Strong password complexity
- Container network isolation
- Health check monitoring
- Resource limits
- Backup encryption support

### **Production Recommendations:**
1. Change default passwords
2. Enable SSL/TLS encryption
3. Configure firewall rules
4. Set up proper authentication
5. Implement backup encryption

## 📊 **Monitoring & Health:**

### **Health Checks:**
- SQL Server connectivity every 30 seconds
- GUI service availability monitoring
- Backup process verification
- Resource usage tracking

### **Logging:**
- Container logs via Docker
- SQL Server error logs
- Backup operation logs
- Nginx access/error logs

### **Metrics:**
```bash
# Database statistics
./manage.sh stats

# Container resource usage
docker stats mssql mssql_gui mssql_adminer

# Backup status
ls -la mssql-backups/
```

## 🔄 **Backup & Recovery:**

### **Automated Backups:**
- **Schedule**: Every hour
- **Compression**: Enabled
- **Cleanup**: 7-day retention
- **Coverage**: All databases

### **Manual Operations:**
```bash
# Manual backup
./manage.sh backup

# Restore database
./backup-scripts/restore.sh backup_file.bak [database_name]

# List backups
ls -la mssql-backups/
```

### **Backup Features:**
- Progress reporting (STATS = 10)
- Compression for space efficiency
- Automatic cleanup of old files
- User database discovery
- Error handling and logging

## 🎯 **Sample Database:**

The `init-database.sql` script creates:

### **SampleApp Database:**
- **Users table** - User management with identity and constraints
- **ActivityLog table** - Audit trail with foreign keys and indexes
- **Sample data** - Pre-populated with test records

### **Maintenance Procedures:**
- `sp_GetDatabaseInfo` - Database size and usage statistics
- `sp_GetTableSizes` - Table-level space analysis

### **Usage Examples:**
```sql
-- Check database info
EXEC sp_GetDatabaseInfo;

-- View table sizes
EXEC sp_GetTableSizes;

-- Query sample data
SELECT * FROM Users;
SELECT COUNT(*) FROM ActivityLog;
```

## ⚡ **Performance Optimization:**

### **Memory Settings:**
- SQL Server max memory: 4096MB
- Container memory limit: 4GB
- TempDB optimization ready
- Buffer pool efficiency

### **I/O Optimization:**
- Compressed backups for faster I/O
- Optimized file growth settings
- Index recommendations included
- Query performance monitoring

### **Resource Monitoring:**
```bash
# Check memory usage
./manage.sh query "SELECT object_name, counter_name, cntr_value FROM sys.dm_os_performance_counters WHERE counter_name LIKE '%Memory%'"

# Database sizes
./manage.sh query "EXEC sp_GetDatabaseInfo"

# Container resources
docker stats mssql
```

## 🔧 **Troubleshooting:**

### **Common Issues:**

1. **Login Failed:**
   - Verify SA password in `.env`
   - Check password complexity requirements
   - Ensure container is fully started

2. **GUI Access Issues:**
   - Verify nginx is running
   - Check hosts file entries
   - Flush DNS cache

3. **Backup Failures:**
   - Check disk space in `mssql-backups/`
   - Verify container permissions
   - Review backup logs

4. **Memory Issues:**
   - Monitor with `docker stats`
   - Adjust memory limits in `docker-compose.yml`
   - Modify `memorylimitmb` in `mssql.conf`

### **Diagnostic Commands:**
```bash
# Check all services
./manage.sh health

# View logs
./manage.sh logs mssql
./manage.sh logs mssql-backup

# Test connectivity
./manage.sh query "SELECT @@VERSION"

# Check backups
ls -la mssql-backups/
```

## 🔗 **Integration:**

### **Network Connectivity:**
- Connects to `external-network` for nginx integration
- Internal `app` network for service communication
- Port 1433 exposed for direct database access

### **Volume Persistence:**
- Database files: `./mssql-data/`
- Backup files: `./mssql-backups/`
- Configuration: `./mssql-conf/`
- GUI workspace: `./cloudbeaver-data/`

### **External Tools:**
- SQL Server Management Studio (SSMS)
- Azure Data Studio
- DBeaver Community
- Command-line tools (sqlcmd)

## 📚 **Additional Resources:**

### **Documentation:**
- Original specs: `README_MSSQL.md`
- Nginx configs: `../nginx/sites-available/mssql-*.conf`
- Management help: `./manage.sh help`

### **Useful SQL Queries:**
```sql
-- Check server info
SELECT @@VERSION, @@SERVERNAME;

-- Memory usage
SELECT object_name, counter_name, cntr_value 
FROM sys.dm_os_performance_counters 
WHERE counter_name LIKE '%Memory%';

-- Database sizes
SELECT name, size*8/1024 as 'Size (MB)' 
FROM sys.master_files;

-- Active connections
SELECT DB_NAME(database_id), COUNT(*) 
FROM sys.dm_exec_sessions 
WHERE is_user_process = 1 
GROUP BY database_id;
```

The stack is now ready for development and production use with comprehensive monitoring, backup, and management capabilities! 🚀
