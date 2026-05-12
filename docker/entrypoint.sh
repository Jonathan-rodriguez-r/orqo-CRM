#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="${APP_DIR:-/var/www/html}"
WEB_USER="${APACHE_RUN_USER:-www-data}"
WEB_GROUP="${APACHE_RUN_GROUP:-www-data}"
HTTP_PORT="${HTTP_PORT:-80}"
PERSIST_ROOT="${PERSIST_ROOT:-}"
export APP_RUNTIME_OPTIONS="${APP_RUNTIME_OPTIONS:-{\"project_dir\":\"${APP_DIR}\"}}"

SUITECRM_VERSION="${SUITECRM_VERSION:-8.8.1}"
SUITECRM_DOWNLOAD_URL="${SUITECRM_DOWNLOAD_URL:-https://sourceforge.net/projects/suitecrm/files/SuiteCRM-${SUITECRM_VERSION}.zip/download}"

DB_HOST="${DB_HOST:-${MYSQLHOST:-db}}"
DB_PORT="${DB_PORT:-${MYSQLPORT:-3306}}"
DB_NAME="${DB_NAME:-${MYSQLDATABASE:-suitecrm}}"
DB_USER="${DB_USER:-${MYSQLUSER:-suitecrm}}"
DB_PASSWORD="${DB_PASSWORD:-${MYSQLPASSWORD:-}}"
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-ChangeMe123!}"
SITE_URL="${SITE_URL:-http://localhost:${HTTP_PORT}}"
DEMO_DATA="${DEMO_DATA:-no}"

log() {
  printf '[orqo-entrypoint] %s\n' "$*"
}

configure_runtime() {
  if [[ -n "${PHP_TIMEZONE:-}" ]]; then
    echo "date.timezone=${PHP_TIMEZONE}" > /usr/local/etc/php/conf.d/99-orqo-timezone.ini
  fi

  rm -f /etc/apache2/mods-enabled/mpm_event.* /etc/apache2/mods-enabled/mpm_worker.*
  a2enmod mpm_prefork >/dev/null 2>&1 || true

  sed -ri "s/^Listen .*/Listen ${HTTP_PORT}/" /etc/apache2/ports.conf
  sed -ri "s/<VirtualHost \*:.*>/<VirtualHost *:${HTTP_PORT}>/" /etc/apache2/sites-available/000-default.conf
}

is_app_empty() {
  [[ -z "$(find "${APP_DIR}" -mindepth 1 -maxdepth 1 ! -name '.gitkeep' -print -quit 2>/dev/null)" ]]
}

download_suitecrm_if_needed() {
  mkdir -p "${APP_DIR}"

  if [[ -f "${APP_DIR}/bin/console" && -d "${APP_DIR}/public/legacy" ]]; then
    log "SuiteCRM already present in ${APP_DIR}."
    return
  fi

  if ! is_app_empty; then
    log "Application directory is not empty but SuiteCRM is not complete; leaving existing files untouched."
    return
  fi

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' RETURN

  log "Downloading SuiteCRM ${SUITECRM_VERSION} from ${SUITECRM_DOWNLOAD_URL}."
  curl -fL --retry 5 --retry-delay 5 --connect-timeout 30 \
    -o "${tmp_dir}/suitecrm.zip" \
    "${SUITECRM_DOWNLOAD_URL}"

  unzip -q "${tmp_dir}/suitecrm.zip" -d "${tmp_dir}/extract"

  local extracted_root
  extracted_root="$(find "${tmp_dir}/extract" -mindepth 1 -maxdepth 2 -type f -name composer.json -printf '%h\n' | head -n 1)"

  if [[ -z "${extracted_root}" || ! -f "${extracted_root}/bin/console" ]]; then
    log "Downloaded archive does not look like a SuiteCRM 8 package."
    exit 1
  fi

  cp -a "${extracted_root}/." "${APP_DIR}/"
  log "SuiteCRM files copied into ${APP_DIR}."
}

persist_path() {
  local app_path="$1"
  printf '%s/%s' "${PERSIST_ROOT}" "${app_path}"
}

persist_dir() {
  local app_path="$1"
  local persisted
  persisted="$(persist_path "${app_path}")"

  [[ -n "${PERSIST_ROOT}" ]] || return 0
  mkdir -p "$(dirname "${persisted}")"

  if [[ ! -e "${persisted}" ]]; then
    mkdir -p "${persisted}"
    if [[ -d "${APP_DIR}/${app_path}" ]]; then
      cp -a "${APP_DIR}/${app_path}/." "${persisted}/" 2>/dev/null || true
    fi
  fi

  rm -rf "${APP_DIR:?}/${app_path}"
  mkdir -p "$(dirname "${APP_DIR}/${app_path}")"
  ln -s "${persisted}" "${APP_DIR}/${app_path}"
}

persist_file() {
  local app_path="$1"
  local persisted
  persisted="$(persist_path "${app_path}")"

  [[ -n "${PERSIST_ROOT}" ]] || return 0
  mkdir -p "$(dirname "${persisted}")"

  if [[ ! -e "${persisted}" && -f "${APP_DIR}/${app_path}" ]]; then
    cp -a "${APP_DIR}/${app_path}" "${persisted}"
  fi

  rm -f "${APP_DIR}/${app_path}"
  mkdir -p "$(dirname "${APP_DIR}/${app_path}")"
  ln -s "${persisted}" "${APP_DIR}/${app_path}"
}

configure_persistence() {
  [[ -n "${PERSIST_ROOT}" ]] || return 0

  mkdir -p "${PERSIST_ROOT}"
  persist_dir public/legacy/cache
  persist_dir public/legacy/upload
  persist_dir public/legacy/custom
  persist_dir logs
  persist_dir var
  persist_file .env.local
  persist_file public/legacy/config.php
  persist_file public/legacy/config_override.php
}

run_composer_install() {
  if [[ ! -f composer.json ]]; then
    log "composer.json not found; skipping composer install."
    return
  fi

  if [[ -d vendor && -f vendor/autoload.php ]]; then
    log "Composer vendor directory already exists."
    return
  fi

  log "Running composer install."
  COMPOSER_ALLOW_SUPERUSER=1 composer install \
    --no-dev \
    --prefer-dist \
    --no-interaction \
    --no-progress \
    --optimize-autoloader
}

ensure_permissions() {
  mkdir -p \
    public/legacy/cache \
    public/legacy/upload \
    public/legacy/custom \
    logs \
    var/cache \
    var/log

  chmod +x bin/console 2>/dev/null || true

  chown -R "${WEB_USER}:${WEB_GROUP}" \
    "${APP_DIR}" \
    2>/dev/null || true

  find public/legacy/cache public/legacy/upload public/legacy/custom logs var/cache var/log -type d -exec chmod 775 {} \; 2>/dev/null || true
  find public/legacy/cache public/legacy/upload public/legacy/custom logs var/cache var/log -type f -exec chmod 664 {} \; 2>/dev/null || true
}

wait_for_database() {
  log "Waiting for database ${DB_HOST}:${DB_PORT}/${DB_NAME}."

  for _ in $(seq 1 60); do
    if MYSQL_PWD="${DB_PASSWORD}" mysqladmin ping \
      --host="${DB_HOST}" \
      --port="${DB_PORT}" \
      --user="${DB_USER}" \
      --silent >/dev/null 2>&1; then
      log "Database is reachable."
      return
    fi

    sleep 2
  done

  log "Database did not become reachable in time."
  exit 1
}

database_has_suitecrm() {
  MYSQL_PWD="${DB_PASSWORD}" mysql \
    --batch \
    --skip-column-names \
    --host="${DB_HOST}" \
    --port="${DB_PORT}" \
    --user="${DB_USER}" \
    --database="${DB_NAME}" \
    --execute="SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME}' AND table_name='users';" \
    2>/dev/null | grep -qx '1'
}

set_env_value() {
  local key="$1"
  local value="$2"
  local file="${3:-.env.local}"

  touch "${file}"
  if grep -q "^${key}=" "${file}"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "${file}"
  else
    printf '%s=%s\n' "${key}" "${value}" >> "${file}"
  fi
}

write_runtime_env() {
  set_env_value APP_ENV "${APP_ENV:-prod}"
  set_env_value APP_DEBUG "${APP_DEBUG:-0}"
  set_env_value DATABASE_URL "\"mysql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?serverVersion=mariadb-10.11&charset=utf8mb4\""
  chmod 660 .env.local
}

cleanup_partial_install_files() {
  if database_has_suitecrm; then
    return
  fi

  log "Cleaning partial installer files before retry."
  rm -f .env.local .env.local.php config_si.php public/legacy/config_si.php
}

install_suitecrm_if_needed() {
  [[ -f bin/console ]] || {
    log "bin/console not found; cannot run SuiteCRM installer."
    exit 1
  }

  wait_for_database

  if database_has_suitecrm; then
    log "SuiteCRM database already contains users table; skipping unattended install."
    write_runtime_env
    return
  fi

  if [[ -f public/legacy/config.php ]]; then
    log "config.php exists but DB install marker was not found; skipping reinstall to protect existing state."
    return
  fi

  cleanup_partial_install_files
  log "Running unattended SuiteCRM install."
  APP_ENV=prod APP_DEBUG=0 php bin/console suitecrm:app:install \
    -u "${ADMIN_USER}" \
    -p "${ADMIN_PASSWORD}" \
    -U "${DB_USER}" \
    -P "${DB_PASSWORD}" \
    -H "${DB_HOST}" \
    -Z "${DB_PORT}" \
    -N "${DB_NAME}" \
    -S "${SITE_URL}" \
    -d "${DEMO_DATA}" \
    -W "true" \
    --no-interaction

  write_runtime_env
}

main() {
  configure_runtime
  download_suitecrm_if_needed
  cd "${APP_DIR}"
  configure_persistence
  run_composer_install
  ensure_permissions
  install_suitecrm_if_needed "$@"
  ensure_permissions

  exec "$@"
}

main "$@"
