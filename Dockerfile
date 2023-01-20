FROM php:8.1.14-fpm-alpine3.17 as composer
RUN apk update
RUN apk add --no-cache redis
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin/ --filename=composer \
    && chmod +x -R /usr/local/bin/
ARG MODE=$MODE
RUN if [ "$MODE" = "latest" ] ; then  \
    cd /var/www/html \
    && composer create-project --remove-vcs --ignore-platform-reqs --no-progress \
      --repository-url=https://mirror.mage-os.org/ magento/project-community-edition:2.4.5-p1 . \
    && composer req --ignore-platform-reqs --no-progress \
    magepal/magento2-gmailsmtpapp yireo/magento2-webp2 dominicwatts/cachewarmer \
    magento/module-bundle-sample-data magento/module-catalog-rule-sample-data magento/module-catalog-sample-data \
    magento/module-cms-sample-data magento/module-configurable-sample-data magento/module-customer-sample-data \
    magento/module-downloadable-sample-data magento/module-grouped-product-sample-data magento/module-msrp-sample-data \
    magento/module-offline-shipping-sample-data magento/module-product-links-sample-data magento/module-review-sample-data \
    magento/module-sales-rule-sample-data magento/module-sales-sample-data magento/module-swatches-sample-data \
    magento/module-tax-sample-data magento/module-theme-sample-data magento/module-widget-sample-data \
    magento/module-wishlist-sample-data magento/sample-data-media; \
fi


FROM php:8.1.14-fpm-alpine3.17
ARG WEBUSER=www-data
ARG WEBGROUP=www-data
ARG COMPOSE_USER=1000
ARG WORKDIR_SERVER=/var/www/html
LABEL maintainer="Osiozekhai Aliu"
RUN apk update && apk upgrade
RUN apk add --no-cache --virtual build-dependencies libc-dev libxslt-dev freetype-dev libjpeg-turbo-dev  \
    libpng-dev libzip-dev libwebp-dev \
    && apk add --no-cache --virtual .php-deps make \
    && apk add --no-cache --virtual .build-deps $PHPIZE_DEPS zlib-dev gettext-dev \
    g++ curl-dev wget ca-certificates gnupg openssl \
    && apk add --no-cache supervisor pwgen gettext openjdk11 su-exec pcre2-dev bash sudo icu-dev git \
    && docker-php-ext-configure hash --with-mhash \
    && docker-php-ext-configure gd --with-webp --with-jpeg --with-freetype \
    && docker-php-ext-install gd bcmath intl gettext pdo_mysql soap sockets xsl zip opcache \
    && pecl channel-update pecl.php.net \
    && pecl install -o -f redis apcu-5.1.21 \
    && docker-php-ext-enable redis apcu \
    && docker-php-source delete \
    && echo 'https://dl-cdn.alpinelinux.org/alpine/v3.12/main' >> /etc/apk/repositories \
    && apk update \
    && apk add --no-cache mariadb=10.4.25-r0 mariadb-client=10.4.25-r0 mariadb-server-utils=10.4.25-r0 \
    && apk del --purge .build-deps .build-deps $PHPIZE_DEPS \
    && apk del --purge openjdk11-demos \
    && apk del --purge openjdk11-doc \
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/* \
    && addgroup -S elasticsearch \
    && adduser -S --no-create-home elasticsearch -G elasticsearch \
    && addgroup -S redis \
    && adduser -S --no-create-home redis -G redis \
    && addgroup -S nginx \
    && adduser -S --no-create-home nginx -G nginx \
    && echo "JAVA_HOME=/usr/lib/jvm/java-11-openjdk/bin/java" | tee -a /etc/profile \
    && source /etc/profile \
    && echo "$WEBUSER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && echo "$COMPOSE_USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && curl -SsL https://github.com/boxboat/fixuid/releases/download/v0.5.1/fixuid-0.5.1-linux-amd64.tar.gz | tar -C /usr/local/bin -xzf -  \
    && chmod 4755 /usr/local/bin/fixuid \
    && mkdir -p /etc/fixuid \
    && printf "user: $WEBUSER\ngroup: $WEBGROUP\n" >> /etc/fixuid/config.yml \
    && printf "user: $COMPOSE_USER\ngroup: $WEBGROUP\n" >> /etc/fixuid/config.yml \
    && addgroup -S $COMPOSE_USER \
    && adduser --disabled-password -sS $COMPOSE_USER -G $WEBGROUP \
    && echo "Defaults  lecture=\"never\"" >> /etc/sudoers

COPY --from=composer --chown=$WEBUSER:$WEBUSER $WORKDIR_SERVER $WORKDIR_SERVER
COPY --from=composer --chown=redis:redis /etc/sentinel.conf /etc/sentinel.conf
COPY --from=composer --chown=redis:redis /var/log/redis /var/log/redis
COPY --from=composer --chown=redis:redis /var/lib/redis /var/lib/redis
COPY --from=composer --chown=redis:redis /run/redis /run/redis
COPY --from=composer --chown=redis:redis /usr/bin/redis-server /usr/bin/redis-server
COPY --from=composer /usr/local/bin/composer /usr/local/bin/composer
COPY --from=blacktop/elasticsearch:7.5 --chown=elasticsearch:elasticsearch /usr/share/elasticsearch /usr/share/elasticsearch
COPY --from=nginx:1.23.3-alpine-slim  --chown=nginx:nginx /usr/sbin/nginx /usr/sbin/nginx
COPY --from=nginx:1.23.3-alpine-slim  --chown=nginx:nginx /usr/share/nginx /usr/share/nginx
COPY --from=nginx:1.23.3-alpine-slim  --chown=nginx:nginx /usr/share/licenses/nginx /usr/share/licenses/nginx
COPY --from=nginx:1.23.3-alpine-slim  --chown=nginx:nginx /usr/lib/nginx /usr/lib/nginx
COPY --from=nginx:1.23.3-alpine-slim  --chown=nginx:nginx /etc/init.d/nginx /etc/init.d/nginx
COPY --from=nginx:1.23.3-alpine-slim  --chown=nginx:nginx /etc/logrotate.d/nginx /etc/logrotate.d/nginx
COPY --from=nginx:1.23.3-alpine-slim  --chown=nginx:nginx /etc/nginx /etc/nginx
COPY --from=nginx:1.23.3-alpine-slim  --chown=nginx:nginx /var/cache/nginx /var/cache/nginx
COPY --from=nginx:1.23.3-alpine-slim  --chown=nginx:nginx /var/log/nginx /var/log/nginx

COPY .docker/config/nginx/nginx.conf /etc/nginx/nginx.conf
COPY .docker/config/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY .docker/config/nginx/cert_key.key /etc/nginx/ssl/cert_key.key
COPY .docker/config/nginx/cert.crt /etc/nginx/ssl/cert.crt
COPY .docker/config/php/docker-php-ext-php.ini /usr/local/etc/php/conf.d/docker-php-ext-php.ini
COPY .docker/config/php/zz-docker.conf /usr/local/etc/php-fpm.d/zz-docker.conf
COPY .docker/config/mysql/z.cnf /etc/mysql/z.cnf
COPY .docker/config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY .docker/scripts/* /usr/local/bin/
COPY .docker/config/mysql/z.cnf /etc/mysql/z.cnf
COPY .docker/config/redis/my-redis.conf /etc/my-redis.conf
COPY .env /usr/local/bin/

RUN chmod +x /usr/share/elasticsearch/bin/elasticsearch \
    && mkdir -p /usr/share/elasticsearch/jdk/bin/ \
    && ln -s /usr/bin/java /usr/share/elasticsearch/jdk/bin/java \
    && chmod +x -R /usr/local/bin

WORKDIR $WORKDIR_SERVER
EXPOSE 80
USER $WEBUSER:$WEBGROUP
CMD [ "sudo", "supervisord-wrapper" ]