#!/bin/bash

# CKAN Smart Start Script
# Automatically detects if harvest plugin is enabled and uses appropriate start script

echo "=== CKAN Smart Start ==="
echo "Current user: $(whoami)"

# Check if harvest plugin is enabled
if [[ $CKAN__PLUGINS == *"harvest"* ]]; then
    echo "✓ Harvest plugin detected"
    echo "→ Starting CKAN in PRODUCTION mode with Supervisor support"
    echo "  (Running as root for supervisor/cron, workers will run as ckan user)"
    echo ""
    
    # Production mode runs as root for supervisor/cron
    # Supervisor config ensures harvest consumers run as 'ckan' user
    exec /srv/app/start_ckan_production.sh
else
    echo "✓ Standard CKAN configuration"
    echo "→ Starting CKAN without harvest support"
    echo "  (Switching to ckan user)"
    echo ""
    
    # Standard mode should run as ckan user
    # If we're root, switch to ckan user
    if [ "$(whoami)" = "root" ]; then
        exec su - ckan -c "/srv/app/start_ckan.sh"
    else
        exec /srv/app/start_ckan.sh
    fi
fi