# Dockerfile.base

ARG PHP_VERSION=8.4
ARG COMPOSER_VERSION=2.8
ARG APP_ENV

# Stage 1: Obtain Composer
FROM composer:${COMPOSER_VERSION} AS vendor

# Stage 2: Build the base image with PHP and system dependencies
FROM ubuntu:22.04 AS base

ARG PHP_VERSION=8.4
ARG APP_ENV
ARG WWWUSER=1000
ARG WWWGROUP=1000
ARG TZ=UTC

# Define PHP ini directory (adjust if needed)
ENV PHP_INI_DIR=/etc/php/${PHP_VERSION}/cli

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

# Set timezone
RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone

# Install system packages and PHP extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
      apt-utils \
      software-properties-common \
      curl \
      wget \
      vim \
      git \
      ncdu \
      procps \
      ca-certificates \
      supervisor \
      nginx \
      unzip \
      nodejs \
      python3 \
      python3-pip \
      python-is-python3 \
      gnupg \
      npm

RUN add-apt-repository ppa:ondrej/php -y && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
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
      php${PHP_VERSION}-swoole && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN npm install -g terser clean-css-cli

# Allow nginx to bind to privileged ports
RUN setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx

# Copy Composer from vendor stage
COPY --link --chown=${WWWUSER}:${WWWUSER} --from=vendor /usr/bin/composer /usr/bin/composer

# Copy configuration files
COPY --link --chown=${WWWUSER}:${WWWUSER} deployment/supervisord.conf            /etc/supervisor/
COPY --link --chown=${WWWUSER}:${WWWUSER} deployment/supervisord.*.conf           /etc/supervisor/conf.d/
COPY --link --chown=${WWWUSER}:${WWWUSER} deployment/php.ini                  ${PHP_INI_DIR}/conf.d/99-octane.ini
COPY --link --chown=${WWWUSER}:${WWWUSER} deployment/start-container            /usr/local/bin/start-container
COPY --link --chown=${WWWUSER}:${WWWUSER} deployment/healthcheck                /usr/local/bin/healthcheck
COPY --link --chown=${WWWUSER}:${WWWUSER} deployment/nginx.conf                 /etc/nginx/sites-enabled/default

COPY --link --chown=${WWWUSER}:${WWWUSER} deployment/minify.sh ./minify.sh

RUN chmod +x /usr/local/bin/start-container /usr/local/bin/healthcheck

EXPOSE 80

ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
HEALTHCHECK --start-period=300s --interval=30s --timeout=10s --retries=5 CMD healthcheck || exit 1
