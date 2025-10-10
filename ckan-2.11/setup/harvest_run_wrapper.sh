#!/bin/bash
# Harvest Run Wrapper Script
# Sources environment variables from /etc/ckan_env

# Debug logging
echo "=== Harvest Wrapper Debug ===" >&2
echo "PWD: $(pwd)" >&2
echo "USER: $(whoami)" >&2

# Change to app directory
cd /srv/app

# Source CKAN environment variables
if [ -f /etc/ckan_env ]; then
    echo "Sourcing /etc/ckan_env" >&2
    source /etc/ckan_env
    echo "CKAN_SQLALCHEMY_URL: ${CKAN_SQLALCHEMY_URL:0:50}..." >&2
else
    echo "ERROR: /etc/ckan_env not found!" >&2
fi

# Run the harvest command
/usr/local/bin/ckan -c /srv/app/ckan.ini harvester run
