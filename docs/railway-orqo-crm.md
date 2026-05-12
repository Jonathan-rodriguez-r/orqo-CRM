# Orqo CRM Railway Runbook

## Phase 1 runtime model

This phase uses a runtime bootstrap container:

- Apache serves SuiteCRM from `/var/www/html/public`.
- If `/var/www/html` is empty, `docker/entrypoint.sh` downloads `SuiteCRM-${SUITECRM_VERSION}.zip` using `curl`.
- The entrypoint runs `composer install` only when `vendor/autoload.php` is missing.
- The unattended installer runs only when the target database does not yet contain SuiteCRM's `users` table and `public/legacy/config.php` is absent.
- Local development persists the full application tree through the `orqo_app_data` volume and operational state through `/data`.

## Railway environment variables

Use Railway's MySQL variables directly:

- `MYSQLHOST`
- `MYSQLPORT`
- `MYSQLUSER`
- `MYSQLPASSWORD`
- `MYSQLDATABASE`
- `SITE_URL`
- `APP_ENV=prod`
- `APP_DEBUG=0`
- `PHP_TIMEZONE=America/Bogota`
- `ORQO_BRAND_NAME=Orqo CRM`
- `PERSIST_ROOT=/data`

## Railway volume mapping

Recommended Railway volume mount:

- Mount one Railway Volume at `/data`.

The entrypoint persists and symlinks these application paths into `/data`:

- `/var/www/html/.env.local`
- `/var/www/html/public/legacy/config.php`
- `/var/www/html/public/legacy/config_override.php`
- `/var/www/html/public/legacy/custom`
- `/var/www/html/public/legacy/upload`
- `/var/www/html/public/legacy/cache`
- `/var/www/html/public/legacy/modules`
- `/var/www/html/logs`
- `/var/www/html/var`

The minimum production-critical paths are `.env.local`, `public/legacy/config.php`, `public/legacy/config_override.php`, `public/legacy/custom`, `public/legacy/upload`, and `logs`.

## Rebranding quick commands

Inside the running container:

```bash
php bin/console cache:clear --env=prod
php bin/console cache:warmup --env=prod
```

Legacy metadata paths for upgrade-safe branding:

- Global system name: generated into `public/legacy/custom/orqo_env_config.php` by `ORQO_BRAND_NAME` and loaded from `public/legacy/config_override.php`.
- Language labels: `public/legacy/custom/Extension/application/Ext/Language/es_ES.orqo_branding.php`.
- SuiteP logo override: `public/legacy/custom/themes/SuiteP/images/company_logo.png`.
- Favicon override: `public/legacy/custom/themes/SuiteP/images/suitecrm-icon.svg` or theme-specific favicon asset used by the installed SuiteP build.

After adding language/theme metadata, run Admin > Repair > Quick Repair and Rebuild from the legacy UI, then clear Symfony cache with the commands above.

Example language override:

```php
<?php
$app_strings['LBL_BROWSER_TITLE'] = 'Orqo CRM';
$app_strings['LBL_SUITECRM'] = 'Orqo CRM';
$app_strings['LBL_SUITECRM_VERSION'] = 'Orqo CRM';
```

## Loyalty logic hook

Files included:

- `public/legacy/custom/Extension/modules/Opportunities/Ext/LogicHooks/orqo_loyalty_points.php`
- `public/legacy/custom/Extension/modules/Opportunities/Ext/Vardefs/orqo_loyalty_points.php`
- `public/legacy/custom/modules/Opportunities/OrqoLoyaltyAfterSave.php`
- `public/legacy/custom/modules/Opportunities/services/OrqoLoyaltyPointsService.php`

Activation:

1. Copy these files into the SuiteCRM 8 installation.
2. Run Admin > Repair > Quick Repair and Rebuild.
3. Execute generated SQL if SuiteCRM asks to create `opportunities_cstm.orqo_loyalty_points_c`.
4. Clear Symfony cache.

## PQRS AOW workflow

Create the workflow in Advanced OpenWorkflow:

- Name: `Orqo PQRS - Escalar prioridad alta sin actualizacion`
- Module: `Cases`
- Status: `Active`
- Repeated Runs: enabled only if the escalation may be re-applied after reassignment.
- Run: scheduled/background workflow, every 15 minutes through SuiteCRM scheduler/cron.

Conditions:

- `Cases.priority` equals `High` or the localized value used by the instance for `Alta`.
- `Cases.status` not in `Closed`, `Rejected`, `Duplicate`.
- `Cases.date_modified` is older than 120 minutes.
- `Cases.assigned_user_id` is not the Senior Architect user id.

Action:

- Update record field `assigned_user_id` to the Senior Architect user id.
- Optional: update `status` to `Assigned`.
- Optional: send email/notification to owner and escalation queue.

Production note: create the Senior Architect user first and use its immutable `users.id`, not the username. Keep the ID in deployment documentation or an environment-backed configuration table.

## Demo seed

Load demo data after install:

```bash
mysql -h "$MYSQLHOST" -P "$MYSQLPORT" -u "$MYSQLUSER" -p"$MYSQLPASSWORD" "$MYSQLDATABASE" < database/seeders/demo_colombia.sql
```
