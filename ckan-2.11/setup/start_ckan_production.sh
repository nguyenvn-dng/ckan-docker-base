#!/bin/bash

# CKAN Production Start Script with Harvester Support
# This script starts CKAN with Supervisor for harvester background processes

if [[ $CKAN__PLUGINS == *"datapusher"* ]]; then
    # Add ckan.datapusher.api_token to the CKAN config file (updated with corrected value later)
    echo "Setting a temporary value for ckan.datapusher.api_token"
    ckan config-tool $CKAN_INI ckan.datapusher.api_token=xxx
fi

# Set up the Secret key used by Beaker and Flask
# This can be overriden using a CKAN___BEAKER__SESSION__SECRET env var
if grep -qE "SECRET_KEY ?= ?$" ckan.ini
then
    echo "Setting SECRET_KEY in ini file"
    ckan config-tool $CKAN_INI "SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_urlsafe())')"
    ckan config-tool $CKAN_INI "WTF_CSRF_SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_urlsafe())')"
    JWT_SECRET=$(python3 -c 'import secrets; print("string:" + secrets.token_urlsafe())')
    ckan config-tool $CKAN_INI "api_token.jwt.encode.secret=${JWT_SECRET}"
    ckan config-tool $CKAN_INI "api_token.jwt.decode.secret=${JWT_SECRET}"
fi

# Run the prerun script to init CKAN and create the default admin user
python3 prerun.py

# Run any startup scripts provided by images extending this one
if [[ -d "/docker-entrypoint.d" ]]
then
    for f in /docker-entrypoint.d/*; do
        case "$f" in
            *.sh)     echo "$0: Running init file $f"; . "$f" ;;
            *.py)     echo "$0: Running init file $f"; python3 "$f"; echo ;;
            *)        echo "$0: Ignoring $f (not an sh or py file)" ;;
        esac
    done
fi

# Setup cron for harvester if harvest plugin is enabled
if [[ $CKAN__PLUGINS == *"harvest"* ]]; then
    echo "Harvest plugin detected - setting up background services"
    
    # Note: This script should run as root to start cron and supervisor
    # The supervisord config will ensure harvest consumers run as 'ckan' user
    
    # Export environment variables to a file for cron jobs to source
    echo "Exporting environment variables for cron..."
    cat > /etc/ckan_env <<EOF
# CKAN environment variables
# Using CKAN envvars plugin format (triple underscore for root options)
export CKAN_SQLALCHEMY_URL="$CKAN_SQLALCHEMY_URL"
export CKAN_DATASTORE_WRITE_URL="$CKAN_DATASTORE_WRITE_URL"
export CKAN_DATASTORE_READ_URL="$CKAN_DATASTORE_READ_URL"
export CKAN_SOLR_URL="$CKAN_SOLR_URL"
export CKAN_REDIS_URL="$CKAN_REDIS_URL"
export CKAN__PLUGINS="$CKAN__PLUGINS"
export CKAN__HARVEST__MQ__TYPE="$CKAN__HARVEST__MQ__TYPE"
export CKAN__HARVEST__MQ__HOSTNAME="$CKAN__HARVEST__MQ__HOSTNAME"
export CKAN__HARVEST__MQ__PORT="$CKAN__HARVEST__MQ__PORT"
export CKAN__HARVEST__MQ__REDIS_DB="$CKAN__HARVEST__MQ__REDIS_DB"
EOF
    chmod +r /etc/ckan_env
    
    # Add cron jobs to crontab for ckan user
    echo "Setting up cron jobs for ckan user..."
    
    # Clear any existing crontab and install fresh to avoid duplicates
    # Don't append - always replace with fresh content
    crontab -u ckan -r 2>/dev/null || true
    crontab -u ckan ${APP_DIR}/ckan_harvester_cron.sh
    
    # Start cron service (requires root)
    echo "Starting cron service..."
    service cron start
    
    echo "Starting Supervisor for harvest consumers..."
    # Start Supervisor (will run as configured in supervisord.conf)
    supervisord -c /etc/supervisor/supervisord.conf
    sleep 5
    
    # Check supervisor status
    echo "Checking supervisor status..."
    supervisorctl status || true
    
    echo "Harvest background services started"
fi

# Define optimized UWSGI options
DEFAULT_UWSGI_OPTS="--socket /tmp/uwsgi.sock \
                    --wsgi-file /srv/app/wsgi.py \
                    --module wsgi:application \
                    --http [::]:5000 \
                    --master --enable-threads \
                    --lazy-apps \
                    --processes ${UWSGI_WORKERS:-6} \
                    --threads ${UWSGI_THREADS:-4} \
                    --buffer-size ${UWSGI_BUFFER_SIZE:-65536} \
                    --listen ${UWSGI_LISTEN:-2048} \
                    --max-requests ${UWSGI_MAX_REQUESTS:-2000} \
                    --max-worker-lifetime ${UWSGI_MAX_WORKER_LIFETIME:-7200} \
                    --cheaper-algo busyness \
                    --cheaper ${UWSGI_CHEAPER:-3} \
                    --cheaper-initial ${UWSGI_CHEAPER_INITIAL:-3} \
                    --cheaper-overload ${UWSGI_CHEAPER_OVERLOAD:-20} \
                    --cheaper-step 1 \
                    --cheaper-busyness-multiplier 20 \
                    --cheaper-busyness-min 10 \
                    --cheaper-busyness-max 70 \
                    --cheaper-busyness-penalty 2 \
                    --vacuum \
                    --die-on-term \
                    --need-app \
                    --disable-logging \
                    --log-4xx \
                    --log-5xx \
                    --harakiri ${UWSGI_HARAKIRI:-300}"

# Use UWSGI_OPTS from environment if set, otherwise use defaults
UWSGI_OPTS="${UWSGI_OPTS:-$DEFAULT_UWSGI_OPTS}"

# Append EXTRA_UWSGI_OPTS if set
if [ -n "$EXTRA_UWSGI_OPTS" ]
then
    UWSGI_OPTS="$UWSGI_OPTS $EXTRA_UWSGI_OPTS"
fi

echo "Starting uWSGI with options: $UWSGI_OPTS"

# Start uWSGI
uwsgi $UWSGI_OPTS