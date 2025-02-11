# ベースイメージ
FROM php:latest

# システムの依存関係をインストール
RUN apt-get update && apt-get install -y \
    git \
    curl \
    zlib1g-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    sqlite3 \
    libsqlite3-dev \
    build-essential \
    && docker-php-ext-install exif pcntl bcmath gd \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/src/* \
    && rm -rf /tmp/*

# PHPの設定を強化
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
    && sed -i \
        -e 's/expose_php = On/expose_php = Off/' \
        -e 's/display_errors = On/display_errors = Off/' \
        -e 's/display_startup_errors = On/display_startup_errors = Off/' \
        -e 's/log_errors = Off/log_errors = On/' \
        -e 's/allow_url_fopen = On/allow_url_fopen = Off/' \
        -e 's/allow_url_include = On/allow_url_include = Off/' \
        "$PHP_INI_DIR/php.ini"

# Composerをインストール
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# アプリケーションディレクトリを作成
WORKDIR /var/www

# アプリケーションファイルをコピー
COPY ./apps /var/www

# SQLiteの設定
RUN mkdir -p /var/www/database \
    && touch /var/www/database/database.sqlite \
    && chmod 777 /var/www/database/database.sqlite

# 依存関係のインストールとセキュリティ設定
ENV COMPOSER_ALLOW_SUPERUSER=1
RUN composer install \
    && chown -R www-data:www-data /var/www \
    && chmod -R 755 /var/www/storage \
    && chmod -R 755 /var/www/bootstrap/cache \
    && rm -rf /var/www/.git \
    && rm -rf /var/www/tests \
    && rm -f /var/www/*.md \
    && find /var/www -type d -exec chmod 755 {} \; \
    && find /var/www -type f -exec chmod 644 {} \;

# 非rootユーザーとして実行
USER www-data

# マイグレーション
RUN php artisan migrate --force

# ポート指定
EXPOSE 8000

CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]
