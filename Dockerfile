# Dockerfile.base

ARG PHP_VERSION=8.4
ARG COMPOSER_VERSION=2.8
ARG APP_ENV
ARG S6_OVERLAY_VERSION=3.1.6.2

# Stage 1: Obtain Composer
FROM composer:${COMPOSER_VERSION} AS vendor

# Stage 2: Build the base image with PHP and system dependencies
FROM ubuntu:22.04 AS base

ARG PHP_VERSION=8.4
ARG APP_ENV
ARG WWWUSER=1000
ARG WWWGROUP=1000
ARG TZ=UTC
ARG S6_OVERLAY_VERSION

# Define PHP ini directory (adjust if needed)
ENV PHP_INI_DIR=/etc/php/${PHP_VERSION}/cli

# S6 Overlay Environment Variables
ENV S6_KEEP_ENV=1 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME=30000 \
    S6_OVERLAY_VERSION=${S6_OVERLAY_VERSION}

ENV DEBIAN_FRONTEND=noninteractive \
    TERM=xterm-color \
    OCTANE_SERVER=swoole \
    TZ=${TZ} \
    USER=root \
    APP_ENV=${APP_ENV} \
    ROOT=/var/www/html \
    COMPOSER_FUND=0 \
    COMPOSER_MAX_PARALLEL_HTTP=24 \
    LOG_CHANNEL=stack

WORKDIR ${ROOT}
SHELL ["/bin/bash", "-eou", "pipefail", "-c"]

# Install packages and S6-overlay in a single layer to reduce image size
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    xz-utils \
    && curl -sSL https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz -o /tmp/s6-overlay-noarch.tar.xz \
    && curl -sSL https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz -o /tmp/s6-overlay-x86_64.tar.xz \
    && tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz \
    && tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz \
    && rm /tmp/s6-overlay-noarch.tar.xz /tmp/s6-overlay-x86_64.tar.xz \
    && ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone \
    && rm -rf /var/lib/apt/lists/*

# Install system packages and PHP extensions in one layer
RUN apt-get update && apt-get install -y --no-install-recommends \
      apt-utils \
      software-properties-common \
      gnupg \
    && add-apt-repository ppa:ondrej/php -y \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
      nginx \
      unzip \
      nodejs \
      npm \
      php${PHP_VERSION}-cli \
      php${PHP_VERSION}-bcmath \
      php${PHP_VERSION}-mbstring \
      php${PHP_VERSION}-sockets \
      php${PHP_VERSION}-opcache \
      php${PHP_VERSION}-pdo-mysql \
      php${PHP_VERSION}-zip \
      php${PHP_VERSION}-intl \
      php${PHP_VERSION}-calendar \
      php${PHP_VERSION}-gd \
      php${PHP_VERSION}-redis \
      php${PHP_VERSION}-igbinary \
      php${PHP_VERSION}-dom \
      php${PHP_VERSION}-swoole \
    && npm install -g terser clean-css-cli \
    # Create directory for error pages and logs
    && mkdir -p /usr/share/nginx/html /var/log/octane \
    # Allow nginx to bind to privileged ports
    && setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx \
    # Configure nginx error logging to stderr
    && sed -i 's/error_log \/var\/log\/nginx\/error.log;/error_log \/dev\/stderr;/' /etc/nginx/nginx.conf \
    && sed -i 's/access_log \/var\/log\/nginx\/access.log;/access_log \/dev\/stdout;/' /etc/nginx/nginx.conf \
    # Remove package lists and other unnecessary files to reduce image size
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && npm cache clean --force \
    && rm -rf /tmp/*

# Copy Composer from vendor stage
COPY --link --chown=${WWWUSER}:${WWWUSER} --from=vendor /usr/bin/composer /usr/bin/composer

# Copy configuration files
COPY --link --chown=${WWWUSER}:${WWWUSER} deployment/php.ini                  ${PHP_INI_DIR}/conf.d/99-octane.ini
COPY --link --chown=${WWWUSER}:${WWWUSER} deployment/start-container            /usr/local/bin/start-container
COPY --link --chown=${WWWUSER}:${WWWUSER} deployment/healthcheck                /usr/local/bin/healthcheck
COPY --link --chown=${WWWUSER}:${WWWUSER} deployment/nginx.conf                 /etc/nginx/sites-enabled/default
COPY --link --chown=${WWWUSER}:${WWWUSER} deployment/s6-overlay/               /etc/

RUN chmod +x /usr/local/bin/start-container /usr/local/bin/healthcheck

EXPOSE 80

ENTRYPOINT ["/init"]
HEALTHCHECK --start-period=300s --interval=30s --timeout=10s --retries=5 CMD healthcheck || exit 1
