# Academick - Laravel/React Production Dockerfile

# -----------------------------------------------------------------------------
# Stage 1: Frontend Asset Builder (Node.js)
#
# This stage uses Node.js to install npm dependencies and build the
# production-ready frontend assets using Vite.
# -----------------------------------------------------------------------------
FROM node:20-alpine AS node-builder

WORKDIR /app

# Copy package manifests to leverage Docker layer caching.
# This step only re-runs if package.json or package-lock.json changes.
COPY package.json package-lock.json ./

# Install npm dependencies using 'ci' for a clean, reproducible install.
# Based on the presence of package-lock.json.
RUN npm ci

# Copy the rest of the project files.
COPY . .

# Build the frontend assets for production.
# The output is expected in the 'public/build' directory for Laravel with Vite.
RUN npm run build

# -----------------------------------------------------------------------------
# Stage 2: Backend Dependency Builder (Composer)
#
# This stage installs PHP dependencies using Composer. It creates a 'vendor'
# directory that will be copied to the final image.
# -----------------------------------------------------------------------------
FROM composer:2 AS composer-vendor

WORKDIR /app

# Copy Composer manifests to leverage Docker layer caching.
COPY composer.json composer.lock ./

# Install production dependencies without dev packages and with an optimized autoloader.
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Copy the full application source code.
COPY . .

# -----------------------------------------------------------------------------
# Stage 3: Final Production Image (PHP-FPM)
#
# This is the final, optimized image that will run the application.
# It uses PHP-FPM and copies artifacts from the previous stages.
# -----------------------------------------------------------------------------
FROM php:8.3-fpm-alpine

WORKDIR /var/www/html

# Install required system packages and PHP extensions for Laravel.
# We create a virtual package `.build-deps` for build-time dependencies,
# install extensions, and then remove the virtual package to keep the image small.
RUN apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        libzip-dev \
        libpng-dev \
        jpeg-dev \
        freetype-dev \
    && apk add --no-cache \
        zip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        mbstring \
        exif \
        pcntl \
        bcmath \
        gd \
        zip \
    && pecl install redis && docker-php-ext-enable redis \
    && apk del .build-deps

# Copy the application code and Composer dependencies from the 'composer-vendor' stage.
COPY --from=composer-vendor /app .

# Copy the compiled frontend assets from the 'node-builder' stage.
COPY --from=node-builder /app/public/build ./public/build

# Set the correct ownership and permissions for Laravel's storage and cache directories.
# This allows the web server user (www-data) to write logs and cache files.
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R 755 /var/www/html/storage /var/www/html/bootstrap/cache

# --- Production Usage Note ---
# This image exposes PHP-FPM on port 9000. It does not include a web server.
# For production, you should run a separate web server container (e.g., nginx)
# and configure it to proxy HTTP requests to this container on port 9000.
# -----------------------------

# Expose port 9000 to the host/network.
EXPOSE 9000

# The main command to run when the container starts.
CMD ["php-fpm"]