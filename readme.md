# Laravel Octane Production Base Image

An opinionated base image for deploying [Laravel](https://laravel.com/) applications in production, built with proven components. This image follows best practices to ensure security, performance, and maintainability.

## Features
- **[Laravel 11.x](https://laravel.com/docs/11.x)** with support for the following first-party packages:
  - [Laravel Pulse](https://github.com/laravel/pulse)
  - [Laravel Telescope](https://laravel.com/docs/11.x/telescope)
  - [Laravel Horizon](https://laravel.com/docs/11.x/horizon)
  - [Laravel Octane](https://laravel.com/docs/11.x/octane) (using [Swoole](https://www.swoole.co.uk/))
  - [Laravel Reverb](https://laravel.com/docs/11.x/reverb)
- **[PHP 8.4](https://www.php.net/releases/)**
- **[Nginx](https://nginx.org/)** for serving static assets
- **[Supervisor](http://supervisord.org/)** for process management

## Rationale
Deploying Laravel applications often involves complex orchestration with multiple containers handling different tasks. However, many applications do not require this level of complexity. This base image provides a streamlined, efficient, and scalable solution by combining key components within a single container:
- **Process Management**: [Supervisor](http://supervisord.org/) efficiently runs workers and scheduled tasks.
- **Performance Optimization**: [Octane](https://laravel.com/docs/11.x/octane) significantly improves request handling speed.
- **Static Asset Handling**: [Nginx](https://nginx.org/) serves static files with minimal overhead.
- **Monitoring & Observability**: [Pulse](https://github.com/laravel/pulse) offers real-time performance insights.
- **Scalability**: While optimized for a single-container deployment, it remains flexible enough to scale individual components when needed.

## Getting Started
Use this template in your project with the following Dockerfile:

```dockerfile
ARG WWWUSER=1000
ARG ROOT=/var/www/html

FROM therealmkadmi/laravel-octane-stack:latest

ARG WWWUSER
ARG ROOT

ENV ROOT=${ROOT}

WORKDIR ${ROOT}

COPY --link --chown=${WWWUSER}:${WWWUSER} composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-progress --no-interaction

COPY --link --chown=${WWWUSER}:${WWWUSER} . .

RUN composer dump-autoload --optimize

RUN mkdir -p storage/framework/{sessions,views,cache,testing} storage/logs bootstrap/cache && \
    chmod -R 777 storage bootstrap/cache ${ROOT}/public && \
    chown -R ${WWWUSER}:${WWWUSER} . && \
    chmod 777 storage/

ENV WITH_HORIZON=false \
    WITH_SCHEDULER=true \
    WITH_REVERB=false \
    WITH_PULSE_WORK=true \
    WITH_PULSE_CHECK=true \
    WITH_ARTISAN_SCHEDULE=true
```

## License
This project is licensed under the **[MIT License](https://opensource.org/licenses/MIT)**.

## Contributing
Contributions are welcome! Feel free to submit a [pull request](https://github.com/TheRealMkadmi/laravel-octane-stack/pulls) or open an [issue](https://github.com/TheRealMkadmi/laravel-octane-stack/issues) for suggestions or improvements.