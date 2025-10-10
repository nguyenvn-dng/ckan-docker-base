#!/bin/bash

# CKAN Production Quick Start Script
# This script helps setup CKAN with harvester in production mode

echo "=================================="
echo "CKAN Production Setup with Harvester"
echo "=================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker first."
    exit 1
fi

print_info "Docker is running ✓"

# Step 1: Build image
print_info "Step 1: Building CKAN image..."
./build.sh build 2.11 base

if [ $? -ne 0 ]; then
    print_error "Failed to build image"
    exit 1
fi

print_info "Image built successfully ✓"
echo ""

# Step 2: Start services
print_info "Step 2: Starting CKAN services..."
docker-compose up -d

if [ $? -ne 0 ]; then
    print_error "Failed to start services"
    exit 1
fi

print_info "Services started ✓"
echo ""

# Step 3: Wait for CKAN to be ready
print_info "Step 3: Waiting for CKAN to be ready (this may take a minute)..."
sleep 15

# Check if CKAN is responding
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if curl -f http://localhost:5000/api/3/action/status_show > /dev/null 2>&1; then
        print_info "CKAN is ready ✓"
        break
    fi
    attempt=$((attempt + 1))
    echo -n "."
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    print_error "CKAN failed to start within timeout"
    print_info "Check logs: docker-compose logs ckan"
    exit 1
fi

echo ""
echo ""

# Step 4: Initialize harvest extension
print_info "Step 4: Initializing harvest extension..."
docker-compose exec -T ckan ckan --config=/srv/app/ckan.ini harvester initdb

if [ $? -ne 0 ]; then
    print_warn "Harvest initdb may have already been run or encountered an error"
else
    print_info "Harvest extension initialized ✓"
fi

echo ""

# Step 5: Check supervisor status
print_info "Step 5: Checking harvest consumers..."
docker-compose exec ckan supervisorctl status

echo ""

# Step 6: Show status
print_info "=================================="
print_info "Setup Complete!"
print_info "=================================="
echo ""
print_info "CKAN is now running at: http://localhost:5000"
print_info "Harvest admin page: http://localhost:5000/harvest"
echo ""
print_info "Useful commands:"
echo "  - View logs: docker-compose logs -f ckan"
echo "  - Check harvest consumers: docker-compose exec ckan supervisorctl status"
echo "  - List harvest sources: docker-compose exec ckan ckan -c /srv/app/ckan.ini harvester sources"
echo "  - Create harvest job: docker-compose exec ckan ckan -c /srv/app/ckan.ini harvester job-create <source-id>"
echo ""
print_info "For detailed documentation, see: PRODUCTION_SETUP.md"
echo ""

# Optional: Create a test harvest source
read -p "Do you want to create a test harvest source? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    print_info "Creating test harvest source..."
    docker-compose exec -T ckan ckan --config=/srv/app/ckan.ini harvester source create \
        "Demo CKAN" \
        "https://demo.ckan.org" \
        ckan_harvester \
        '{"api_version": 2, "default_tags": [{"name": "demo"}], "user": "default"}' \
        true

    if [ $? -eq 0 ]; then
        print_info "Test harvest source created ✓"
        print_info "You can view it at: http://localhost:5000/harvest"
    else
        print_warn "Failed to create test source. You can create it manually through the web UI."
    fi
fi

echo ""
print_info "Done! 🎉"