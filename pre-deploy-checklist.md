# Pre-Deployment Checklist

## Environment Configuration
- [ ] Verify .env file is properly configured for production
- [ ] Check APP_DEBUG is set to false
- [ ] Confirm APP_ENV is set to production
- [ ] Validate database credentials
- [ ] Check queue configuration

## Cache and Optimization
- [ ] Run composer install --optimize-autoloader --no-dev
- [ ] Clear all caches:
  ```bash
  php artisan config:clear
  php artisan cache:clear
  php artisan route:clear
  php artisan view:clear
  ```
- [ ] Generate optimized files:
  ```bash
  php artisan config:cache
  php artisan route:cache
  php artisan view:cache
  ```

## Security
- [ ] Check file permissions
- [ ] Verify sensitive files are in .gitignore
- [ ] Review API endpoints security
- [ ] Confirm SSL certificate is valid

## Docker
- [ ] Validate Dockerfile configuration
- [ ] Check multi-stage build optimization
- [ ] Verify container health checks
- [ ] Review Docker volumes configuration

## Performance
- [ ] Enable OPcache
- [ ] Configure PHP-FPM settings
- [ ] Review Redis configuration
- [ ] Check queue worker settings
