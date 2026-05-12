FROM php:8.2-apache

ARG DEBIAN_FRONTEND=noninteractive

ENV APP_DIR=/var/www/html \
    APP_ENV=prod \
    APP_DEBUG=0 \
    PHP_TIMEZONE=America/Bogota \
    SUITECRM_VERSION=8.8.1 \
    APACHE_DOCUMENT_ROOT=/var/www/html/public

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        unzip \
        mariadb-client \
        libcurl4-openssl-dev \
        libfreetype6-dev \
        libicu-dev \
        libjpeg62-turbo-dev \
        libkrb5-dev \
        libc-client-dev \
        libonig-dev \
        libpng-dev \
        libxml2-dev \
        libzip-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
    && docker-php-ext-install -j"$(nproc)" \
        bcmath \
        curl \
        gd \
        imap \
        intl \
        mbstring \
        mysqli \
        opcache \
        xml \
        zip \
    && a2enmod rewrite headers expires remoteip \
    && sed -ri 's!/var/www/html!/var/www/html/public!g' /etc/apache2/sites-available/000-default.conf /etc/apache2/apache2.conf \
    && printf '%s\n' \
        '<Directory /var/www/html/public>' \
        '    Options FollowSymLinks' \
        '    AllowOverride All' \
        '    Require all granted' \
        '</Directory>' \
        > /etc/apache2/conf-available/orqo-suitecrm.conf \
    && a2enconf orqo-suitecrm \
    && { \
        echo 'memory_limit=512M'; \
        echo 'upload_max_filesize=64M'; \
        echo 'post_max_size=64M'; \
        echo 'max_execution_time=300'; \
        echo 'date.timezone=America/Bogota'; \
        echo 'opcache.enable=1'; \
        echo 'opcache.memory_consumption=192'; \
        echo 'opcache.interned_strings_buffer=16'; \
        echo 'opcache.max_accelerated_files=20000'; \
        echo 'opcache.validate_timestamps=0'; \
        echo 'opcache.save_comments=1'; \
    } > /usr/local/etc/php/conf.d/orqo-production.ini \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY docker/entrypoint.sh /usr/local/bin/orqo-entrypoint

RUN chmod +x /usr/local/bin/orqo-entrypoint \
    && mkdir -p /var/www/html \
    && chown -R www-data:www-data /var/www/html

WORKDIR /var/www/html

EXPOSE 80

ENTRYPOINT ["orqo-entrypoint"]
CMD ["apache2-foreground"]
