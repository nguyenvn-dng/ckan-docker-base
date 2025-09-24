# CKAN Docker Compose Setup

Đây là cấu hình Docker Compose để chạy CKAN với tất cả các service cần thiết.

## Yêu cầu

- Docker
- Docker Compose
- Ít nhất 4GB RAM

## Cấu trúc

```
docker-compose.yml     # Cấu hình các services
.env                   # Biến môi trường
setup-ckan.sh         # Script setup CKAN
```

## Services bao gồm:

- **CKAN**: Ứng dụng chính (port 5000)
- **PostgreSQL**: Database (port 5432)
- **Solr**: Search engine (port 8983)
- **Redis**: Cache (port 6379)
- **DataPusher**: Xử lý CSV data (port 8800)

## Cách sử dụng

### 1. Khởi động các services

```bash
# Khởi động tất cả services
docker-compose up -d

# Kiểm tra trạng thái
docker-compose ps
```

### 2. Setup CKAN (chạy một lần duy nhất)

```bash
# Chạy script setup
chmod +x setup-ckan.sh
./setup-ckan.sh
```

Hoặc setup thủ công:

```bash
# Initialize database
docker-compose exec ckan ckan db init

# Create datastore database
docker-compose exec db psql -U ckan -d ckan -c "CREATE DATABASE datastore;"
docker-compose exec db psql -U ckan -d ckan -c "CREATE USER datastore_ro WITH PASSWORD 'datastore';"

# Set datastore permissions
docker-compose exec ckan ckan datastore set-permissions

# Create admin user
docker-compose exec ckan ckan user add admin email=admin@example.com password=admin123
docker-compose exec ckan ckan sysadmin add admin
```

### 3. Truy cập CKAN

Mở trình duyệt và truy cập: http://localhost:5000

- **Admin user**: admin
- **Password**: admin123 (hoặc password bạn đã đặt)

## Cấu hình

### Thay đổi cấu hình

Chỉnh sửa file `.env` để thay đổi các biến môi trường:

```bash
# Database
POSTGRES_PASSWORD=your-secure-password

# Security (QUAN TRỌNG: Thay đổi trong production)
CKAN___BEAKER__SESSION__SECRET=your-unique-secret-key
CKAN__API_TOKEN__JWT__ENCODE__SECRET=your-jwt-secret
```

### Thêm plugins

Chỉnh sửa biến `CKAN__PLUGINS` trong file `.env`:

```bash
CKAN__PLUGINS=image_view text_view datatables_view datastore envvars datapusher
```

### Cấu hình email (tùy chọn)

Bỏ comment và cấu hình SMTP trong file `.env`:

```bash
CKAN_SMTP_SERVER=smtp.gmail.com
CKAN_SMTP_USER=your-email@gmail.com
CKAN_SMTP_PASSWORD=your-app-password
```

## Quản lý

### Xem logs

```bash
# Tất cả services
docker-compose logs -f

# Chỉ CKAN
docker-compose logs -f ckan

# Chỉ database
docker-compose logs -f db
```

### Restart services

```bash
# Restart tất cả
docker-compose restart

# Restart chỉ CKAN
docker-compose restart ckan
```

### Dừng services

```bash
# Dừng tất cả services
docker-compose down

# Dừng và xóa volumes (CẢNH BÁO: Sẽ mất dữ liệu)
docker-compose down -v
```

### Backup database

```bash
# Backup
docker-compose exec db pg_dump -U ckan ckan > ckan_backup.sql

# Restore
docker-compose exec -T db psql -U ckan ckan < ckan_backup.sql
```

## Troubleshooting

### CKAN không khởi động được

1. Kiểm tra logs: `docker-compose logs ckan`
2. Đảm bảo database đã được khởi tạo
3. Kiểm tra các biến môi trường trong `.env`

### Database connection error

1. Kiểm tra PostgreSQL đã khởi động: `docker-compose ps`
2. Kiểm tra logs database: `docker-compose logs db`
3. Verify connection string trong `.env`

### Solr search không hoạt động

1. Kiểm tra Solr: http://localhost:8983/solr
2. Rebuild search index: `docker-compose exec ckan ckan search-index rebuild`

## Development

Để chạy trong development mode:

```bash
# Build dev image
./build.sh build 2.11 dev

# Sử dụng dev image trong docker-compose.yml
# Thay đổi: image: ckan-docker-base/ckan-2.11:dev
```

## Production

Để chạy trong production:

1. Thay đổi tất cả passwords và secrets trong `.env`
2. Sử dụng external database nếu cần
3. Setup reverse proxy (nginx)
4. Enable SSL/HTTPS
5. Setup backup strategy
6. Monitor logs và performance