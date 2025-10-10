# CKAN Production Setup với Harvester

## Tổng quan

Setup này cấu hình CKAN cho môi trường production với đầy đủ harvester support, bao gồm:

- **Supervisor**: Quản lý harvest gather/fetch consumers
- **Cron jobs**: Chạy harvest jobs định kỳ
- **Logging**: Tập trung logs cho monitoring
- **Performance optimization**: uWSGI, Redis caching, connection pooling

## Cấu trúc Files

```
ckan-2.11/
├── Dockerfile                          # Main Dockerfile với production config
├── ckan_harvesting.conf               # Supervisor config cho harvesters
├── setup/
│   ├── start_ckan.sh                  # Development start script
│   ├── start_ckan_production.sh       # Production start script (with Supervisor)
│   ├── ckan_harvester_cron.sh         # Cron jobs cho harvester
│   └── prerun.py                      # Pre-run initialization
└── plugins/
    └── ckanext-harvest/               # Harvest extension

```

## Production Setup

### 1. Build Image

```bash
./build.sh build 2.11 base
```

### 2. Docker Compose Configuration

Thêm vào `docker-compose.yml`:

```yaml
services:
  ckan:
    image: ckan/ckan-base:2.11.3
    environment:
      # Enable harvest plugin
      CKAN__PLUGINS: "datastore envvars harvest ckan_harvester"
      
      # Redis for harvest backend
      CKAN__HARVEST__MQ__TYPE: redis
      CKAN__HARVEST__MQ__HOSTNAME: redis
      CKAN__HARVEST__MQ__PORT: 6379
      CKAN__HARVEST__MQ__REDIS_DB: 0
      
      # Harvest configurations
      CKAN__HARVEST__LOG_LEVEL: info
      CKAN__HARVEST__LOG_TIMEFRAME: 30
      
      # Performance
      UWSGI_WORKERS: 6
      UWSGI_THREADS: 4
      
    # Use production start script
    command: ["/srv/app/start_ckan_production.sh"]
    
    # Mount logs for monitoring
    volumes:
      - ckan_storage:/var/lib/ckan
      - ckan_logs:/var/log/ckan
      
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

volumes:
  ckan_logs:
  ckan_storage:
```

### 3. Khởi động Services

```bash
docker-compose up -d
```

### 4. Khởi tạo Harvest Extension

Chạy lần đầu để tạo database tables:

```bash
docker-compose exec ckan ckan --config=/srv/app/ckan.ini harvester initdb
```

### 5. Kiểm tra Harvester Status

```bash
# Check Supervisor processes
docker-compose exec ckan supervisorctl status

# Expected output:
# ckan_fetch_consumer    RUNNING   pid 123, uptime 0:10:00
# ckan_gather_consumer   RUNNING   pid 124, uptime 0:10:00

# Check cron jobs
docker-compose exec ckan crontab -l

# View logs
docker-compose exec ckan tail -f /var/log/ckan/gather_consumer.log
docker-compose exec ckan tail -f /var/log/ckan/fetch_consumer.log
```

## Tạo Harvest Source

### Qua Web UI

1. Truy cập: `http://localhost:5000/harvest`
2. Click "Add Harvest Source"
3. Điền thông tin:
   - **URL**: URL của CKAN instance muốn harvest
   - **Title**: Tên harvest source
   - **Type**: Chọn "CKAN"
   - **Configuration**: JSON config (xem bên dưới)

### Qua CLI

```bash
docker-compose exec ckan ckan --config=/srv/app/ckan.ini harvester source create \
  "Remote CKAN" \
  "https://demo.ckan.org" \
  ckan_harvester \
  '{"api_version": 2, "default_tags": [{"name": "remote"}]}'
```

### Configuration Example

```json
{
  "api_version": 2,
  "default_tags": [{"name": "harvested"}, {"name": "external"}],
  "default_groups": ["my-group"],
  "user": "harvest",
  "read_only": false,
  "force_all": false,
  "remote_orgs": "create",
  "clean_tags": true
}
```

## Quản lý Harvest Jobs

### Tạo và chạy harvest job

```bash
# List sources
docker-compose exec ckan ckan --config=/srv/app/ckan.ini harvester sources

# Create job for specific source
docker-compose exec ckan ckan --config=/srv/app/ckan.ini harvester job-create <source-id>

# Create jobs for all active sources
docker-compose exec ckan ckan --config=/srv/app/ckan.ini harvester job-all

# List jobs
docker-compose exec ckan ckan --config=/srv/app/ckan.ini harvester jobs

# Manual run (normally handled by cron)
docker-compose exec ckan ckan --config=/srv/app/ckan.ini harvester run
```

### Monitoring

```bash
# View harvest job details
docker-compose exec ckan ckan --config=/srv/app/ckan.ini harvester job-show <job-id>

# Check for errors
docker-compose exec ckan ckan --config=/srv/app/ckan.ini harvester job-show <job-id> | grep -i error

# Reindex harvest source datasets
docker-compose exec ckan ckan --config=/srv/app/ckan.ini harvester reindex <source-id>
```

## Troubleshooting

### Harvest consumers không chạy

```bash
# Check supervisor logs
docker-compose exec ckan tail -f /var/log/supervisor/supervisord.log

# Restart consumers
docker-compose exec ckan supervisorctl restart ckan_harvester:*

# Check Redis connection
docker-compose exec ckan redis-cli -h redis ping
```

### Harvest jobs bị stuck

```bash
# Abort stuck job
docker-compose exec ckan ckan --config=/srv/app/ckan.ini harvester job-abort <source-id>

# Purge all queues
docker-compose exec ckan ckan --config=/srv/app/ckan.ini harvester purge-queues

# Restart everything
docker-compose exec ckan supervisorctl restart all
```

### Database issues

```bash
# Re-initialize harvest tables
docker-compose exec ckan ckan --config=/srv/app/ckan.ini harvester initdb

# Clean old harvest logs (older than 30 days)
docker-compose exec ckan ckan --config=/srv/app/ckan.ini harvester clean-harvest-log
```

## Performance Tuning

### Tăng số workers

```yaml
environment:
  # More workers for heavy harvesting
  UWSGI_WORKERS: 8
  UWSGI_THREADS: 6
```

### Tối ưu Redis

```yaml
redis:
  command: redis-server --maxmemory 2gb --maxmemory-policy allkeys-lru
```

### Harvest timeout

```yaml
environment:
  CKAN__HARVEST__TIMEOUT: 1440  # 24 hours in minutes
```

## Logs và Monitoring

### Log locations

- **Gather consumer**: `/var/log/ckan/gather_consumer.log`
- **Fetch consumer**: `/var/log/ckan/fetch_consumer.log`
- **Harvester run**: `/var/log/ckan/harvester_run.log`
- **Cleanup**: `/var/log/ckan/harvester_cleanup.log`
- **Supervisor**: `/var/log/supervisor/supervisord.log`

### View logs

```bash
# Real-time logs
docker-compose logs -f ckan

# Harvest specific logs
docker-compose exec ckan tail -f /var/log/ckan/*.log

# Export logs for analysis
docker-compose exec ckan cat /var/log/ckan/gather_consumer.log > harvest_logs.txt
```

## Backup và Recovery

### Backup harvest sources

```bash
# Export all sources
docker-compose exec ckan ckan --config=/srv/app/ckan.ini harvester sources > harvest_sources.txt

# Backup harvest database tables
docker-compose exec db pg_dump -U ckan -t harvest_* ckan > harvest_backup.sql
```

### Recovery

```bash
# Restore harvest tables
docker-compose exec -T db psql -U ckan ckan < harvest_backup.sql

# Re-create sources from backup (manual)
# Use Web UI or CLI to recreate sources
```

## Security Best Practices

1. **Đổi default secrets** trong production
2. **Giới hạn quyền** cho harvest user
3. **Enable SSL/TLS** cho remote connections
4. **Monitor logs** thường xuyên
5. **Backup định kỳ** harvest configurations
6. **Rate limiting** cho harvest requests

## Tham khảo

- [CKAN Harvest Documentation](https://github.com/ckan/ckanext-harvest)
- [Supervisor Documentation](http://supervisord.org/)
- [CKAN Production Guide](https://docs.ckan.org/en/latest/maintaining/installing/deployment.html)