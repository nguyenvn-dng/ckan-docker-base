#!/bin/bash

# CKAN Setup Script
# This script initializes the CKAN database and creates the default admin user

echo "=== CKAN Setup Script ==="

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 10

# Initialize CKAN database
echo "Initializing CKAN database..."
docker-compose exec ckan ckan db init

# Create datastore database and set permissions
echo "Setting up datastore..."
docker-compose exec db psql -U ckan -d ckan -c "CREATE DATABASE datastore;"
docker-compose exec db psql -U ckan -d ckan -c "CREATE USER datastore_ro WITH PASSWORD 'datastore';"
docker-compose exec ckan ckan datastore set-permissions

# Create sysadmin user
echo "Creating sysadmin user..."
echo "Please enter details for the admin user:"
read -p "Admin username: " admin_username
read -p "Admin email: " admin_email
read -s -p "Admin password: " admin_password
echo

docker-compose exec ckan ckan user add $admin_username email=$admin_email password=$admin_password
docker-compose exec ckan ckan sysadmin add $admin_username

echo "=== Setup completed! ==="
echo "You can now access CKAN at http://localhost:5000"
echo "Admin username: $admin_username"