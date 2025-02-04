# ベースイメージ
FROM php:8.2-cli

# システムの依存関係をインストール
RUN apt-get update && apt-get install -y \
    git \
    curl \
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
    && rm -rf /var/lib/apt/lists/*

# GD拡張のインストール（設定オプションを変更）
RUN docker-php-ext-configure gd \
        --enable-gd \
        --with-freetype \
        --with-jpeg \
    && docker-php-ext-install -j1 gd

# 他の拡張機能を個別にインストール
RUN docker-php-ext-install exif
RUN docker-php-ext-install pcntl
RUN docker-php-ext-install bcmath

# Composerをインストール
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# アプリケーションディレクトリを作成
WORKDIR /var/www

# アプリケーションファイルをコピー
COPY ./apps /var/www

# 依存関係をインストール
RUN composer install

# キャッシュなどのパーミッション調整
RUN chown -R www-data:www-data /var/www \
    && chmod -R 755 /var/www/storage

# ポート指定
EXPOSE 8000

# アプリケーションを起動
CMD ["php", "artisan", "serve", "--host", "0.0.0.0", "--port", "8000"]
