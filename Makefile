# CKAN Docker Compose Makefile

.PHONY: help build up down restart logs setup clean backup restore

# Default target
help:
	@echo "Available commands:"
	@echo "  build    - Build CKAN image"
	@echo "  up       - Start all services"
	@echo "  down     - Stop all services"
	@echo "  restart  - Restart all services"
	@echo "  logs     - Show logs for all services"
	@echo "  setup    - Initialize CKAN (run once)"
	@echo "  clean    - Stop and remove all containers and volumes"
	@echo "  backup   - Backup database"
	@echo "  restore  - Restore database from backup"
	@echo "  status   - Show service status"

# Build CKAN image
build:
	@echo "Building CKAN base image..."
	./build.sh build 2.11 base

# Start services
up:
	@echo "Starting CKAN services..."
	docker-compose up -d
	@echo "Services started. Run 'make setup' if this is first time."
	@echo "CKAN will be available at http://localhost:5000"

# Stop services
down:
	@echo "Stopping CKAN services..."
	docker-compose down

# Restart services
restart:
	@echo "Restarting CKAN services..."
	docker-compose restart

# Show logs
logs:
	docker-compose logs -f

# Show logs for specific service
logs-ckan:
	docker-compose logs -f ckan

logs-db:
	docker-compose logs -f db

logs-solr:
	docker-compose logs -f solr

# Setup CKAN (first time only)
setup:
	@echo "Setting up CKAN..."
	@echo "Waiting for services to be ready..."
	@sleep 15
	@echo "Initializing CKAN database..."
	docker-compose exec ckan ckan db init
	@echo "Creating datastore database..."
	docker-compose exec db psql -U ckan -d ckan -c "CREATE DATABASE datastore;"
	docker-compose exec db psql -U ckan -d ckan -c "CREATE USER datastore_ro WITH PASSWORD 'datastore';"
	@echo "Setting datastore permissions..."
	docker-compose exec ckan ckan datastore set-permissions
	@echo "Creating admin user (admin/admin123)..."
	docker-compose exec ckan ckan user add admin email=admin@example.com password=admin123
	docker-compose exec ckan ckan sysadmin add admin
	@echo "Setup completed! Access CKAN at http://localhost:5000"
	@echo "Admin credentials: admin/admin123"

# Show service status
status:
	docker-compose ps

# Clean everything (WARNING: This will delete all data)
clean:
	@echo "WARNING: This will remove all containers and volumes!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose down -v; \
		docker system prune -f; \
		echo "Cleanup completed."; \
	else \
		echo "Cleanup cancelled."; \
	fi

# Backup database
backup:
	@echo "Creating database backup..."
	docker-compose exec db pg_dump -U ckan ckan > ckan_backup_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "Backup created: ckan_backup_$(shell date +%Y%m%d_%H%M%S).sql"

# Restore database (provide BACKUP_FILE=filename)
restore:
	@if [ -z "$(BACKUP_FILE)" ]; then \
		echo "Usage: make restore BACKUP_FILE=backup_filename.sql"; \
		exit 1; \
	fi
	@echo "Restoring database from $(BACKUP_FILE)..."
	docker-compose exec -T db psql -U ckan ckan < $(BACKUP_FILE)
	@echo "Database restored from $(BACKUP_FILE)"

# Rebuild search index
reindex:
	@echo "Rebuilding search index..."
	docker-compose exec ckan ckan search-index rebuild
	@echo "Search index rebuilt"

# Enter CKAN container shell
shell:
	docker-compose exec ckan bash

# Enter database shell
db-shell:
	docker-compose exec db psql -U ckan ckan

# Show CKAN config
config:
	docker-compose exec ckan ckan config-tool