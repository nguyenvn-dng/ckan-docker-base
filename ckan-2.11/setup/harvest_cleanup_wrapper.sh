#!/bin/bash
# Harvest Cleanup Wrapper Script
# Sources environment variables from /etc/ckan_env

# Change to app directory
cd /srv/app

# Source CKAN environment variables
if [ -f /etc/ckan_env ]; then
    source /etc/ckan_env
fi

# Run the cleanup command
/usr/local/bin/ckan -c /srv/app/ckan.ini harvester clean-harvest-log
