ARG MODE=$MODE
ARG PHP_VERSION_SET
ARG MAGENTO_VERSION
ARG WORKDIR_SERVER
ARG NGINX_VERSION
ARG OPENSEARCH_VERSION
ARG REDIS_PECL_VERSION
ARG APCU_PECL_VERSION
ARG FIXUID_VERSION
ARG WEBUSER
ARG WEBGROUP

FROM php:${PHP_VERSION_SET:-8.1.29-fpm-alpine3.19} AS builder
LABEL maintainer="Osiozekhai Aliu"
ARG MODE
ARG WORKDIR_SERVER
ARG MAGENTO_VERSION
RUN apk update
RUN apk add --no-cache redis
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin/ --filename=composer \
    && chmod +x -R /usr/local/bin/
RUN if [ "$MODE" = "latest" ]; then \
    cd $WORKDIR_SERVER \
    && composer create-project --remove-vcs --ignore-platform-reqs \
        --repository-url=https://mirror.mage-os.org/ magento/project-community-edition:$MAGENTO_VERSION . \
    && composer req --ignore-platform-reqs \
        magepal/magento2-gmailsmtpapp yireo/magento2-webp2 dominicwatts/cachewarmer; \
fi


FROM php:${PHP_VERSION_SET:-8.1.29-fpm-alpine3.19} 
ARG MODE
ARG WORKDIR_SERVER
ARG WEBUSER=www-data
ARG WEBGROUP=$WEBUSER
RUN apk update && apk upgrade
# Install build dependencies
RUN apk add --no-cache --virtual .build-deps \
    $PHPIZE_DEPS \
    libc-dev \
    libxslt-dev \
    freetype-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libzip-dev \
    libwebp-dev \
    zlib-dev \
    gettext-dev \
    g++ \
    curl-dev \
    icu-dev \
    linux-headers

# Install runtime dependencies
RUN apk add --no-cache \
    wget \
    ca-certificates \
    gnupg \
    openssl \
    supervisor \
    pwgen \
    gettext \
    openjdk11 \
    su-exec \
    pcre2-dev \
    bash \
    sudo \
    shadow \
    mariadb \
    mariadb-client \
    libxslt \
    freetype \
    libjpeg-turbo \
    libpng \
    libzip \
    libwebp \
    icu-dev \
    icu-libs

# Configure and install PHP extensions
RUN docker-php-ext-configure hash --with-mhash \
    && docker-php-ext-configure gd --with-webp --with-jpeg --with-freetype \
    && docker-php-ext-install -j$(nproc) \
        gd \
        bcmath \
        intl \
        gettext \
        pdo_mysql \
        soap \
        sockets \
        xsl \
        zip \
        opcache

# Install PECL extensions
ARG REDIS_PECL_VERSION
ARG APCU_PECL_VERSION
RUN pecl channel-update pecl.php.net \
    && pecl install -o -f redis-${REDIS_PECL_VERSION} apcu-${APCU_PECL_VERSION} \
    && docker-php-ext-enable redis apcu \
    && docker-php-source delete

# Cleanup
ARG FIXUID_VERSION
RUN apk del --no-cache .build-deps \
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/* \
    && addgroup -S opensearch \
    && adduser -S --no-create-home opensearch -G opensearch \
    && addgroup -S redis \
    && adduser -S --no-create-home redis -G redis \
    && addgroup -S nginx \
    && adduser -S --no-create-home nginx -G nginx \
    && echo "JAVA_HOME=/usr/lib/jvm/java-11-openjdk/bin/java" | tee -a /etc/profile \
    && curl -SsL https://github.com/boxboat/fixuid/releases/download/v${FIXUID_VERSION}/fixuid-${FIXUID_VERSION}-linux-amd64.tar.gz | tar -C /usr/local/bin -xzf -  \
    && chmod 4755 /usr/local/bin/fixuid \
    && mkdir -p /etc/fixuid \
    && usermod -p "" $WEBUSER \
    && printf "user: $WEBUSER\ngroup: $WEBGROUP\n" >> /etc/fixuid/config.yml \
    && echo "$WEBUSER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && echo "Defaults  lecture=\"never\"" >> /etc/sudoers \
    && source /etc/profile

RUN if [ "$MODE" = "dev" ]; then \
    apk add --no-cache autoconf g++ make linux-headers yarn \
    && pecl channel-update pecl.php.net \
    && pecl install -o -f xdebug \
    && docker-php-ext-enable xdebug \
    && rm -rf /tmp/pear \
    && apk del --purge autoconf g++ make linux-headers \
    && rm -rf /tmp/*; \
fi

COPY --from=builder --chown=$WEBUSER:$WEBUSER $WORKDIR_SERVER $WORKDIR_SERVER
COPY --from=builder --chown=redis:redis /etc/sentinel.conf /etc/sentinel.conf
COPY --from=builder --chown=redis:redis /var/log/redis /var/log/redis
COPY --from=builder --chown=redis:redis /var/lib/redis /var/lib/redis
COPY --from=builder --chown=redis:redis /run/redis /run/redis
COPY --from=builder --chown=redis:redis /usr/bin/redis-server /usr/bin/redis-server
COPY --from=builder /usr/local/bin/composer /usr/local/bin/composer
# Note: These versions should match OPENSEARCH_VERSION and NGINX_VERSION in .env
# Docker doesn't support variable substitution in COPY --from statements
COPY --from=opensearchproject/opensearch:1.3.6 --chown=opensearch:opensearch /usr/share/opensearch /usr/share/opensearch

COPY --from=nginx:1.27.4-alpine-slim  --chown=nginx:nginx /usr/sbin/nginx /usr/sbin/nginx
COPY --from=nginx:1.27.4-alpine-slim  --chown=nginx:nginx /usr/share/nginx /usr/share/nginx
COPY --from=nginx:1.27.4-alpine-slim  --chown=nginx:nginx /usr/share/licenses/nginx /usr/share/licenses/nginx
COPY --from=nginx:1.27.4-alpine-slim  --chown=nginx:nginx /usr/lib/nginx /usr/lib/nginx
COPY --from=nginx:1.27.4-alpine-slim  --chown=nginx:nginx /etc/init.d/nginx /etc/init.d/nginx
COPY --from=nginx:1.27.4-alpine-slim  --chown=nginx:nginx /etc/logrotate.d/nginx /etc/logrotate.d/nginx
COPY --from=nginx:1.27.4-alpine-slim  --chown=nginx:nginx /etc/nginx /etc/nginx
COPY --from=nginx:1.27.4-alpine-slim  --chown=nginx:nginx /var/cache/nginx /var/cache/nginx
COPY --from=nginx:1.27.4-alpine-slim  --chown=nginx:nginx /var/log/nginx /var/log/nginx
COPY .docker/config/nginx/nginx.conf /etc/nginx/nginx.conf
COPY .docker/config/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY .docker/config/nginx/ssl /etc/nginx/ssl

RUN if [ "$MODE" = "dev" ]; then \
    rm -rf /usr/sbin/nginx /usr/share/nginx /usr/share/licenses/nginx /usr/lib/nginx /etc/init.d/nginx; \
    rm -rf /etc/logrotate.d/nginx /etc/nginx /var/cache/nginx /var/log/nginx; \
fi

COPY .docker/config/php/docker-php-ext-php.ini /usr/local/etc/php/conf.d/docker-php-ext-php.ini
COPY .docker/config/php/xdebug.ini /usr/local/etc/php/conf.d/xdebug.ini
COPY .docker/config/php/zz-docker.conf /usr/local/etc/php-fpm.d/zz-docker.conf
COPY .docker/config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY .docker/scripts/* /usr/local/bin/
COPY .docker/config/mysql/my.cnf  /etc/mysql/my.cnf
COPY .docker/config/redis/my-redis.conf /etc/my-redis.conf
COPY .env /usr/local/bin/

RUN chmod +x /usr/share/opensearch/bin/opensearch \
    && mkdir -p /usr/share/opensearch/jdk/bin/ \
    && if [ ! -e /usr/share/opensearch/jdk/bin/java ]; then ln -s /usr/bin/java /usr/share/opensearch/jdk/bin/java; fi \
    && chmod +x -R /usr/local/bin

WORKDIR $WORKDIR_SERVER
EXPOSE 80
USER $WEBUSER:$WEBGROUP
CMD [ "fixuid", "sudo", "supervisord-wrapper" ]