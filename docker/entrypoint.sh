#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="${APP_DIR:-/var/www/html}"
WEB_USER="${APACHE_RUN_USER:-www-data}"
WEB_GROUP="${APACHE_RUN_GROUP:-www-data}"
HTTP_PORT="${HTTP_PORT:-80}"
PERSIST_ROOT="${PERSIST_ROOT:-}"

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
RESET_ADMIN_PASSWORD="${RESET_ADMIN_PASSWORD:-}"
ORQO_BRAND_NAME="${ORQO_BRAND_NAME:-Orqo CRM}"

log() {
  printf '[orqo-entrypoint] %s\n' "$*"
}

tail_application_logs() {
  log "Tailing Orqo CRM runtime logs to container stdout."
  touch \
    logs/prod/prod.log \
    logs/dev/dev.log \
    public/legacy/suitecrm.log \
    public/legacy/fatal.log \
    2>/dev/null || true

  tail -n 0 -F \
    logs/prod/prod.log \
    logs/dev/dev.log \
    public/legacy/suitecrm.log \
    public/legacy/fatal.log \
    2>/dev/null &
}

configure_runtime() {
  if [[ -n "${PHP_TIMEZONE:-}" ]]; then
    echo "date.timezone=${PHP_TIMEZONE}" > /usr/local/etc/php/conf.d/99-orqo-timezone.ini
  fi

  echo "ServerName ${SERVER_NAME:-localhost}" > /etc/apache2/conf-available/server-name.conf
  a2enconf server-name >/dev/null 2>&1 || true

  mkdir -p "${APP_DIR}/public/legacy/cache/tmp"
  export TMPDIR="${APP_DIR}/public/legacy/cache/tmp"
  echo "sys_temp_dir=${APP_DIR}/public/legacy/cache/tmp" > /usr/local/etc/php/conf.d/98-orqo-tempdir.ini

  rm -f /etc/apache2/mods-enabled/mpm_event.* /etc/apache2/mods-enabled/mpm_worker.*
  a2enmod mpm_prefork >/dev/null 2>&1 || true

  sed -ri "s/^Listen .*/Listen ${HTTP_PORT}/" /etc/apache2/ports.conf
  sed -ri "s/<VirtualHost \*:.*>/<VirtualHost *:${HTTP_PORT}>/" /etc/apache2/sites-available/000-default.conf
}

is_app_empty() {
  [[ -z "$(find "${APP_DIR}" -mindepth 1 -maxdepth 1 \
    ! -name '.gitkeep' \
    ! -name 'tmp' \
    ! -name 'logs' \
    ! -name 'var' \
    ! -name 'public' \
    -print -quit 2>/dev/null)" ]]
}

download_suitecrm_if_needed() {
  mkdir -p "${APP_DIR}"

  if [[ -f "${APP_DIR}/bin/console" && -d "${APP_DIR}/public/legacy" ]]; then
    log "Orqo CRM base application already present in ${APP_DIR}."
    return
  fi

  if ! is_app_empty; then
    log "Application directory is not empty but Orqo CRM base application is not complete; leaving existing files untouched."
    return
  fi

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' RETURN

  log "Downloading Orqo CRM base package ${SUITECRM_VERSION}."
  curl -fL --retry 5 --retry-delay 5 --connect-timeout 30 \
    -o "${tmp_dir}/suitecrm.zip" \
    "${SUITECRM_DOWNLOAD_URL}"

  unzip -q "${tmp_dir}/suitecrm.zip" -d "${tmp_dir}/extract"

  local extracted_root
  extracted_root="$(find "${tmp_dir}/extract" -mindepth 1 -maxdepth 2 -type f -name composer.json -printf '%h\n' | head -n 1)"

  if [[ -z "${extracted_root}" || ! -f "${extracted_root}/bin/console" ]]; then
    log "Downloaded archive does not look like the expected Orqo CRM base package."
    exit 1
  fi

  cp -a "${extracted_root}/." "${APP_DIR}/"
  log "Orqo CRM base files copied into ${APP_DIR}."
}

apply_orqo_overlay() {
  if [[ ! -d /opt/orqo-overlay ]]; then
    return
  fi

  log "Applying Orqo CRM custom overlay."
  cp -a /opt/orqo-overlay/. "${APP_DIR}/"

  if [[ -f "${APP_DIR}/public/legacy/custom/themes/default/images/company_logo.png" ]]; then
    mkdir -p \
      "${APP_DIR}/public/legacy/themes/default/images" \
      "${APP_DIR}/public/legacy/themes/SuiteP/images" \
      "${APP_DIR}/public/legacy/themes/suite8/images"

    cp -f "${APP_DIR}/public/legacy/custom/themes/default/images/company_logo.png" \
      "${APP_DIR}/public/legacy/themes/default/images/company_logo.png" 2>/dev/null || true
    cp -f "${APP_DIR}/public/legacy/custom/themes/default/images/company_logo.png" \
      "${APP_DIR}/public/legacy/themes/SuiteP/images/company_logo.png" 2>/dev/null || true
    cp -f "${APP_DIR}/public/legacy/custom/themes/default/images/company_logo.png" \
      "${APP_DIR}/public/legacy/themes/suite8/images/company_logo.png" 2>/dev/null || true
  fi
}

replace_visible_suitecrm_branding() {
  log "Replacing visible SuiteCRM branding with ${ORQO_BRAND_NAME}."

  if [[ -d public/dist ]]; then
    find public/dist -type f \( \
      -name '*.js' -o \
      -name '*.html' -o \
      -name '*.json' -o \
      -name '*.webmanifest' \
    \) -exec sed -i \
      -e "s/SuiteCRM/${ORQO_BRAND_NAME}/g" \
      -e "s/Suite CRM/${ORQO_BRAND_NAME}/g" \
      {} +
  fi

  for css_file in public/dist/styles*.css; do
    [[ -f "${css_file}" ]] || continue
    if grep -q "ORQO_CRM_BRANDING_START" "${css_file}"; then
      continue
    fi

    cat >> "${css_file}" <<'EOF'
/* ORQO_CRM_BRANDING_START */
body {
  background: #f7f3ec;
}

body::before {
  content: "";
  position: fixed;
  inset: 0;
  pointer-events: none;
  background:
    radial-gradient(circle at 12% 18%, rgba(36, 169, 155, 0.12), transparent 24rem),
    radial-gradient(circle at 84% 12%, rgba(236, 91, 79, 0.14), transparent 26rem);
  z-index: -1;
}

input,
.form-control {
  border-radius: 8px !important;
}

button,
.btn,
.button {
  border-radius: 8px !important;
  font-weight: 700 !important;
}

button[type="submit"],
.btn-primary,
.login-button {
  background: #ec5b4f !important;
  border-color: #ec5b4f !important;
}

button[type="submit"]:hover,
.btn-primary:hover,
.login-button:hover {
  background: #d94f45 !important;
  border-color: #d94f45 !important;
}

img[src*="company_logo"] {
  max-width: 300px !important;
  height: auto !important;
}
/* ORQO_CRM_BRANDING_END */
EOF
  done

  if [[ -f public/site.webmanifest ]]; then
    sed -i \
      -e "s/SuiteCRM/${ORQO_BRAND_NAME}/g" \
      -e "s/Suite CRM/${ORQO_BRAND_NAME}/g" \
      public/site.webmanifest
  fi

  if [[ -f public/legacy/themes/suite8/tpls/_head.tpl ]]; then
    sed -i \
      -e "s/SuiteCRM/${ORQO_BRAND_NAME}/g" \
      -e "s/Suite CRM/${ORQO_BRAND_NAME}/g" \
      public/legacy/themes/suite8/tpls/_head.tpl
  fi
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

write_legacy_branding_config() {
  mkdir -p public/legacy/custom

  cat > public/legacy/custom/orqo_branding_config.php <<EOF
<?php
// Managed by Orqo CRM bootstrap. Keep brand overrides out of SuiteCRM core.
\$sugar_config['system_name'] = '${ORQO_BRAND_NAME}';
\$sugar_config['company_logo'] = 'company_logo.png';
\$sugar_config['company_logo_url'] = '';
\$sugar_config['company_logo_width'] = '300';
\$sugar_config['company_logo_height'] = '80';
EOF

  touch public/legacy/config_override.php
  if [[ ! -s public/legacy/config_override.php ]]; then
    printf "%s\n" "<?php" > public/legacy/config_override.php
  fi

  if ! grep -q "orqo_branding_config.php" public/legacy/config_override.php; then
    printf "\nrequire_once __DIR__ . '/custom/orqo_branding_config.php';\n" >> public/legacy/config_override.php
  fi
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
    public/legacy/cache/modules \
    public/legacy/cache/tmp \
    public/legacy/upload \
    public/legacy/custom \
    logs \
    logs/prod \
    var/cache \
    var/log

  if [[ ! -e cache ]]; then
    ln -s public/legacy/cache cache
  fi

  if [[ ! -e public/cache ]]; then
    ln -s legacy/cache public/cache
  fi

  if [[ -d public/legacy/modules ]]; then
    for module_dir in public/legacy/modules/*; do
      [[ -d "${module_dir}" ]] || continue
      mkdir -p "public/legacy/cache/modules/$(basename "${module_dir}")"
    done
  fi

  mkdir -p \
    public/legacy/cache/modules/Users \
    public/legacy/cache/modules/Employees \
    public/legacy/cache/modules/UserPreferences \
    public/legacy/cache/modules/Administration

  chmod +x bin/console 2>/dev/null || true

  chown -R "${WEB_USER}:${WEB_GROUP}" \
    "${APP_DIR}" \
    2>/dev/null || true

  for writable_path in public/legacy/cache public/legacy/upload public/legacy/custom logs var/cache var/log; do
    [[ -e "${writable_path}" ]] || continue
    chown -R "${WEB_USER}:${WEB_GROUP}" "${writable_path}/" 2>/dev/null || true
    find -L "${writable_path}" -type d -exec chmod 2775 {} \; 2>/dev/null || true
    find -L "${writable_path}" -type f -exec chmod 664 {} \; 2>/dev/null || true
  done
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
  local escaped_value

  touch "${file}"
  escaped_value="${value//\\/\\\\}"
  escaped_value="${escaped_value//&/\\&}"
  escaped_value="${escaped_value//|/\\|}"

  if grep -q "^${key}=" "${file}"; then
    sed -i "s|^${key}=.*|${key}=${escaped_value}|" "${file}"
  else
    printf '%s=%s\n' "${key}" "${value}" >> "${file}"
  fi
}

write_runtime_env() {
  if [[ -z "${APP_SECRET:-}" ]]; then
    if grep -q "^APP_SECRET=" .env.local 2>/dev/null; then
      APP_SECRET="$(grep "^APP_SECRET=" .env.local | tail -n 1 | cut -d= -f2- | tr -d '\"')"
    else
      APP_SECRET="$(php -r 'echo bin2hex(random_bytes(32));')"
    fi
    export APP_SECRET
  fi

  set_env_value APP_ENV "${APP_ENV:-prod}"
  set_env_value APP_DEBUG "${APP_DEBUG:-0}"
  set_env_value APP_SECRET "\"${APP_SECRET}\""
  set_env_value DATABASE_URL "\"mysql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?serverVersion=mariadb-10.11.0&charset=utf8mb4\""
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
    log "bin/console not found; cannot run Orqo CRM installer."
    exit 1
  }

  wait_for_database

  if database_has_suitecrm; then
    log "Orqo CRM database already contains users table; skipping unattended install."
    write_runtime_env
    return
  fi

  if [[ -f public/legacy/config.php ]]; then
    log "config.php exists but DB install marker was not found; skipping reinstall to protect existing state."
    return
  fi

  cleanup_partial_install_files
  log "Running unattended Orqo CRM install."
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

reset_admin_password_if_requested() {
  if [[ -z "${RESET_ADMIN_PASSWORD}" ]]; then
    return
  fi

  if ! database_has_suitecrm; then
    return
  fi

  log "Resetting SuiteCRM admin password from RESET_ADMIN_PASSWORD."

  local password_hash
  password_hash="$(
    RESET_ADMIN_PASSWORD="${RESET_ADMIN_PASSWORD}" php -r 'echo password_hash(md5(getenv("RESET_ADMIN_PASSWORD")), PASSWORD_BCRYPT);'
  )"
  local escaped_hash
  escaped_hash="${password_hash//\\/\\\\}"
  escaped_hash="${escaped_hash//\'/\'\'}"

  MYSQL_PWD="${DB_PASSWORD}" mysql \
    --host="${DB_HOST}" \
    --port="${DB_PORT}" \
    --user="${DB_USER}" \
    --database="${DB_NAME}" \
    --execute="
      UPDATE users
      SET
        user_hash = '${escaped_hash}',
        status = 'Active',
        deleted = 0,
        is_admin = 1,
        sugar_login = 1,
        external_auth_only = 0,
        system_generated_password = 0,
        pwd_last_changed = UTC_DATE()
      WHERE id = '1' OR user_name = 'admin';

      SELECT id, user_name, LEFT(user_hash, 7) AS hash_prefix, status, is_admin, deleted, sugar_login
      FROM users
      WHERE id = '1' OR user_name = 'admin';
    "
}

main() {
  configure_runtime
  download_suitecrm_if_needed
  cd "${APP_DIR}"
  configure_persistence
  apply_orqo_overlay
  write_legacy_branding_config
  replace_visible_suitecrm_branding
  run_composer_install
  ensure_permissions
  install_suitecrm_if_needed "$@"
  reset_admin_password_if_requested
  ensure_permissions
  tail_application_logs

  exec "$@"
}

main "$@"
