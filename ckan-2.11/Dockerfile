ARG ENV=base
ARG PYTHON_VERSION

FROM python:${PYTHON_VERSION}-slim-bookworm AS python


# ┌─────────────────────────────────────────────────────────────┐
# │                                                             │
# │ Base image (Production env)                                 │
# │ ---------------------------                                 │
# │ This is always built                                        │
# │                                                             │
# └─────────────────────────────────────────────────────────────┘


FROM python AS base

# Tag passed through via the Makefile
ARG CKAN_REF=${CKAN_REF}
# Make it available to child images
ENV CKAN_REF=${CKAN_REF}

# Internals, you probably don't need to change these
ENV TZ=UTC
ENV APP_DIR=/srv/app
ENV SRC_DIR=${APP_DIR}/src
ENV CKAN_INI=${APP_DIR}/ckan.ini
ENV PIP_SRC=${SRC_DIR}
ENV CKAN_STORAGE_PATH=/var/lib/ckan

# Customize these in the environment (.env) file if needed
ENV CKAN_SITE_URL=http://localhost:5000
ENV CKAN__PLUGINS="image_view text_view datatables_view datastore envvars"

# UWSGI options
ENV UWSGI_HARAKIRI=50

WORKDIR ${APP_DIR}

# Set up timezone
RUN echo ${TZ} > /etc/timezone

# Set LC_ALL=en_US.UTF-8 will ensure that all locale-dependent operations in the current environment
# will use English language and United States cultural conventions with UTF-8 character encoding
ENV LC_ALL=en_US.UTF-8

# Set the locale
RUN apt-get update
RUN apt-get install --no-install-recommends -y locales
RUN sed -i "/$LC_ALL/s/^# //g" /etc/locale.gen
RUN dpkg-reconfigure --frontend=noninteractive locales
RUN update-locale LANG=${LC_ALL}

# Install system libraries
RUN apt-get install --no-install-recommends -y procps supervisor cron \
        apt-utils \
        git \
        libpq-dev \
        g++ \
        linux-headers-generic \
        libtool \
        patch \
        wget

# Create log directory for CKAN
RUN mkdir -p /var/log/ckan && \
    chmod 755 /var/log/ckan

# Create the src directory
RUN mkdir -p ${SRC_DIR}

# Copy local CKAN source code
COPY ckan ${SRC_DIR}/ckan

COPY ckan_harvesting.conf /etc/supervisor/conf.d/ckan_harvesting.conf

# Install uwsgi, the CKAN application, the dependency packages for CKAN plus some confiquration
RUN pip3 install -U pip && \
    pip3 install -U "setuptools>=70.0.0" && \
    pip3 install uwsgi && \
    cd ${SRC_DIR}/ckan && \
    pip3 install -e . && \
    pip3 install --no-binary markdown -r requirements.txt && \
    # Install performance dependencies
    pip3 install redis dogpile.cache && \
    # Install CKAN envvars to support loading config from environment variables
    pip3 install -e git+https://github.com/okfn/ckanext-envvars.git@v0.0.6#egg=ckanext-envvars && \
    # Create and update CKAN config
    ckan generate config ${CKAN_INI} && \
    ckan config-tool ${CKAN_INI} "SECRET_KEY = " && \
    ckan config-tool ${CKAN_INI} "ckan.plugins = ${CKAN__PLUGINS}"

# Create ckan and ckan-sys users and the ckan-sys group plus set up the storage path
RUN groupadd -g 502 ckan-sys && \
    useradd -rm -d /srv/app -s /bin/bash -g ckan-sys -u 502 ckan-sys && \
    useradd -rm -d /srv/app -s /bin/bash -g ckan-sys -u 503 ckan

COPY setup/prerun.py ${APP_DIR}
COPY setup/start_ckan.sh ${APP_DIR}
COPY setup/start_ckan_production.sh ${APP_DIR}
COPY setup/start_ckan_smart.sh ${APP_DIR}
COPY setup/ckan_harvester_cron.sh ${APP_DIR}
COPY setup/harvest_run_wrapper.sh ${APP_DIR}
COPY setup/harvest_cleanup_wrapper.sh ${APP_DIR}
COPY ckan/wsgi.py ${APP_DIR}
RUN chmod 644 ${APP_DIR}/wsgi.py && \
    sed -i 's/\r$//' ${APP_DIR}/start_ckan.sh && \
    sed -i 's/\r$//' ${APP_DIR}/start_ckan_production.sh && \
    sed -i 's/\r$//' ${APP_DIR}/start_ckan_smart.sh && \
    sed -i 's/\r$//' ${APP_DIR}/ckan_harvester_cron.sh && \
    sed -i 's/\r$//' ${APP_DIR}/harvest_run_wrapper.sh && \
    sed -i 's/\r$//' ${APP_DIR}/harvest_cleanup_wrapper.sh && \
    chmod +x ${APP_DIR}/start_ckan.sh && \
    chmod +x ${APP_DIR}/start_ckan_production.sh && \
    chmod +x ${APP_DIR}/start_ckan_smart.sh && \
    chmod +x ${APP_DIR}/ckan_harvester_cron.sh && \
    chmod +x ${APP_DIR}/harvest_run_wrapper.sh && \
    chmod +x ${APP_DIR}/harvest_cleanup_wrapper.sh

# Copy tất cả plugin custom
COPY plugins ${SRC_DIR}/plugins

# Install tất cả plugin (nếu có requirements.txt thì cài thêm)
RUN set -ex \
    && cd ${SRC_DIR} \
    && for d in plugins/*; do \
        if [ -d "$d" ]; then \
            echo "Installing plugin: $d"; \
            if [ -f "$d/setup.py" ]; then \
                pip3 install -e "$d"; \
            fi; \
            if [ -f "$d/requirements.txt" ]; then \
                pip3 install -r "$d/requirements.txt"; \
            fi; \
        fi; \
    done

# Create entrypoint directory for children image scripts
RUN mkdir -p /docker-entrypoint.d && chmod 755 /docker-entrypoint.d

# Set the ownership of the app directory, usr/local and the entrypoint directory to the ckan-sys user
RUN chown -R ckan-sys:ckan-sys ${APP_DIR} && \
    chown -R ckan-sys:ckan-sys /docker-entrypoint.d && \
    chown -R ckan-sys:ckan-sys /usr/local

# Set the ownership of the CKAN config file, src and the storage path to the ckan user
RUN chown ckan:ckan-sys ${APP_DIR}/ckan.ini && \
    chown -R ckan:ckan-sys ${APP_DIR}/src && \
    mkdir -p ${CKAN_STORAGE_PATH} && \
    chown -R ckan:ckan-sys ${CKAN_STORAGE_PATH} && \
    mkdir -p /tmp/sessions/data /tmp/sessions/lock && \
    chown -R ckan:ckan-sys /tmp/sessions && \
    chown -R ckan:ckan-sys /var/log/ckan

# Note: Starting as root to allow Supervisor and Cron to start if harvest plugin is enabled
# The smart start script will handle user switching appropriately
# Standard mode will run as ckan user
# Production mode (with harvest) needs root for supervisor/cron, but runs workers as ckan user
USER root

EXPOSE 5000

# Smart start script - automatically detects harvest plugin and uses appropriate start mode
CMD ["/srv/app/start_ckan_smart.sh"]

# Alternative commands you can use in docker-compose.yml:
# For standard mode: command: ["su", "-", "ckan", "-c", "/srv/app/start_ckan.sh"]
# For production mode with harvest: command: ["/srv/app/start_ckan_production.sh"]


# ┌─────────────────────────────────────────────────────────────┐
# │                                                             │
# │ Dev image (Development env)                                 │
# │ ---------------------------                                 │
# │ This is only built when ENV=dev                             │
# │                                                             │
# └─────────────────────────────────────────────────────────────┘


FROM base AS dev

ENV SRC_EXTENSIONS_DIR=${APP_DIR}/src_extensions

USER root

RUN cd ${SRC_DIR}/ckan && \
pip3 install -r dev-requirements.txt

COPY --chown=ckan-sys:ckan-sys setup/unsafe.cert setup/unsafe.key setup/start_ckan_development.sh setup/install_src.sh ${APP_DIR}

# Update local directories, /srv/app as writable home dir
RUN mkdir -p ${SRC_EXTENSIONS_DIR} /var/lib/ckan && \
    chown -R ckan-sys:ckan-sys ${SRC_EXTENSIONS_DIR} && \
    chown -R ckan:ckan-sys /var/lib/ckan/ && \
    chown ckan:ckan-sys /srv/app/ && \
    chmod 775 ${SRC_EXTENSIONS_DIR} && \
    sed -i 's/\r$//' ${APP_DIR}/start_ckan_development.sh && \
    sed -i 's/\r$//' ${APP_DIR}/install_src.sh && \
    chmod +x ${APP_DIR}/start_ckan_development.sh && \
    chmod +x ${APP_DIR}/install_src.sh

USER ckan

CMD ["/srv/app/start_ckan_development.sh"]


# ──────────────────────────────────────────────────────────────


FROM ${ENV} AS final
