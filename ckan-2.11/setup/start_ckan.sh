#!/bin/bash

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

# Define optimized UWSGI options
DEFAULT_UWSGI_OPTS="--socket /tmp/uwsgi.sock \
                    --wsgi-file /srv/app/wsgi.py \
                    --module wsgi:application \
                    --http [::]:5000 \
                    --master --enable-threads \
                    --lazy-apps \
                    --processes ${UWSGI_WORKERS:-4} \
                    --threads 2 \
                    --buffer-size ${UWSGI_BUFFER_SIZE:-32768} \
                    --listen ${UWSGI_LISTEN:-1000} \
                    --max-requests ${UWSGI_MAX_REQUESTS:-1000} \
                    --max-worker-lifetime ${UWSGI_MAX_WORKER_LIFETIME:-3600} \
                    --cheaper-algo busyness \
                    --cheaper ${UWSGI_CHEAPER:-2} \
                    --cheaper-initial ${UWSGI_CHEAPER_INITIAL:-2} \
                    --cheaper-overload ${UWSGI_CHEAPER_OVERLOAD:-30} \
                    --cheaper-step 1 \
                    --cheaper-busyness-multiplier 20 \
                    --cheaper-busyness-min 10 \
                    --cheaper-busyness-max 70 \
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

if [ $? -eq 0 ]
then
    # Start uwsgi
    uwsgi $UWSGI_OPTS
else
  echo "[prerun] failed...not starting CKAN."
fi
