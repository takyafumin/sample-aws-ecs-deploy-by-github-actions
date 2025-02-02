# ベースイメージ（セキュリティアップデート済みの公式PHPイメージを利用）
FROM php:8.3-cli-bookworm

# システムパッケージのインストール
RUN apt-get update && apt-get install -y \
    build-essential \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libonig-dev \
    zip \
    unzip \
    git \
    sqlite3 \
    libsqlite3-dev \
    libzip-dev \
    && rm -rf /var/lib/apt/lists/*

# GD拡張のための設定
RUN docker-php-ext-configure gd --with-freetype --with-jpeg

# PHP拡張モジュールのインストール
RUN docker-php-ext-install pdo
RUN docker-php-ext-install pdo_sqlite
RUN docker-php-ext-install mbstring
RUN docker-php-ext-install exif
RUN docker-php-ext-install pcntl
RUN docker-php-ext-install bcmath
RUN docker-php-ext-install gd
RUN docker-php-ext-install zip

# Composerのインストール
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# 作業ディレクトリの作成
WORKDIR /var/www

# プロジェクトのファイルをコピー
COPY ./apps /var/www

# Composer依存関係のインストール（プロダクション向けオプション）
RUN /usr/bin/composer install --no-dev --optimize-autoloader

# キャッシュなどのパーミッション調整
RUN chown -R www-data:www-data /var/www \
    && chmod -R 755 /var/www/storage

# ポート指定（必要に応じて変更）
EXPOSE 8000

# PHP Laravel Server の起動
CMD ["php", "artisan", "serve", "--host", "0.0.0.0", "--port", "8000"]
