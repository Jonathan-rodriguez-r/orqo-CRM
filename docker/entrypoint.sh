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
ORQO_DEFAULT_LANGUAGE="${ORQO_DEFAULT_LANGUAGE:-es_ES}"
ORQO_USD_TO_COP_RATE_FALLBACK="${ORQO_USD_TO_COP_RATE_FALLBACK:-4000.000000}"
ORQO_TRM_API_URL="${ORQO_TRM_API_URL:-https://www.datos.gov.co/resource/32sa-8pi3.json?\$select=valor,vigenciadesde,vigenciahasta&\$order=vigenciadesde%20DESC&\$limit=1}"
ORQO_SPANISH_LANGUAGE_PACK_URL="${ORQO_SPANISH_LANGUAGE_PACK_URL:-https://sourceforge.net/projects/suitecrmtranslations/files/8.9/es_ES_SuiteCRM_lang_8.9.zip/download}"

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
  mkdir -p "${APP_DIR}/public/legacy/custom"

  if [[ -d /opt/orqo-overlay/public/legacy/custom ]]; then
    cp -a /opt/orqo-overlay/public/legacy/custom/. "${APP_DIR}/public/legacy/custom/"
  fi

  if [[ -f "${APP_DIR}/public/legacy/custom/themes/default/images/company_logo.png" ]]; then
    mkdir -p \
      "${APP_DIR}/public/legacy/themes/default/images" \
      "${APP_DIR}/public/legacy/themes/SuiteP/images" \
      "${APP_DIR}/public/legacy/themes/suite8/images" \
      "${APP_DIR}/public/dist/themes/suite8/images"

    cp -f "${APP_DIR}/public/legacy/custom/themes/default/images/company_logo.png" \
      "${APP_DIR}/public/legacy/themes/default/images/company_logo.png" 2>/dev/null || true
    cp -f "${APP_DIR}/public/legacy/custom/themes/default/images/company_logo.png" \
      "${APP_DIR}/public/legacy/themes/suite8/images/company_logo.png" 2>/dev/null || true
    cp -f "${APP_DIR}/public/legacy/custom/themes/default/images/company_logo.png" \
      "${APP_DIR}/public/legacy/themes/suite8/images/login_logo.png" 2>/dev/null || true

    local header_logo="${APP_DIR}/public/legacy/custom/themes/default/images/company_logo_white.png"
    if [[ ! -f "${header_logo}" ]]; then
      header_logo="${APP_DIR}/public/legacy/custom/themes/default/images/company_logo.png"
    fi

    cp -f "${header_logo}" \
      "${APP_DIR}/public/legacy/themes/SuiteP/images/company_logo.png" 2>/dev/null || true
    cp -f "${header_logo}" \
      "${APP_DIR}/public/legacy/themes/suite8/images/company_logo_white.png" 2>/dev/null || true
  fi

  if [[ -f "${APP_DIR}/public/legacy/custom/themes/default/images/orqo-icon.png" ]]; then
    cp -f "${APP_DIR}/public/legacy/custom/themes/default/images/orqo-icon.png" \
      "${APP_DIR}/public/favicon.png" 2>/dev/null || true
    cp -f "${APP_DIR}/public/legacy/custom/themes/default/images/orqo-icon.png" \
      "${APP_DIR}/public/apple-touch-icon.png" 2>/dev/null || true
    cp -f "${APP_DIR}/public/legacy/custom/themes/default/images/orqo-icon.png" \
      "${APP_DIR}/public/icon-192.png" 2>/dev/null || true
  fi

  if [[ -f "${APP_DIR}/public/legacy/custom/themes/default/images/favicon.ico" ]]; then
    cp -f "${APP_DIR}/public/legacy/custom/themes/default/images/favicon.ico" \
      "${APP_DIR}/public/favicon.ico" 2>/dev/null || true
    cp -f "${APP_DIR}/public/legacy/custom/themes/default/images/favicon.ico" \
      "${APP_DIR}/public/legacy/themes/default/images/favicon.ico" 2>/dev/null || true
    cp -f "${APP_DIR}/public/legacy/custom/themes/default/images/favicon.ico" \
      "${APP_DIR}/public/legacy/themes/suite8/images/favicon.ico" 2>/dev/null || true
    cp -f "${APP_DIR}/public/legacy/custom/themes/default/images/favicon.ico" \
      "${APP_DIR}/public/dist/themes/suite8/images/favicon.ico" 2>/dev/null || true
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
      -e "s/SugarCRM/${ORQO_BRAND_NAME}/g" \
      -e "s/Sugar CRM/${ORQO_BRAND_NAME}/g" \
      -e "s/SalesAgility/Orqo/g" \
      -e "s/Open Source CRM/Engineering CRM/g" \
      -e "s/Open source CRM/Engineering CRM/g" \
      -e "s/Powered By ${ORQO_BRAND_NAME}/Powered by Orqo/g" \
      -e "s/Powered by ${ORQO_BRAND_NAME}/Powered by Orqo/g" \
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

body .navbar,
body .navbar-inverse,
body app-navbar,
body scrm-navbar,
body .topnav {
  min-height: 46px !important;
  height: 46px !important;
  background: #2E4038 !important;
  overflow: visible !important;
}

body .navbar-brand,
body .navbar-header,
body .navbar .logo,
body .navbar img[src*="company_logo"],
body header img[src*="company_logo"] {
  content: url("/legacy/themes/suite8/images/company_logo_white.png") !important;
  height: 36px !important;
  max-height: 36px !important;
  width: auto !important;
  max-width: 190px !important;
  object-fit: contain !important;
  margin: 6px 12px !important;
  position: static !important;
  transform: none !important;
}

body .navbar-brand *,
body .navbar-header * {
  line-height: 46px !important;
}

body::before {
  content: "";
  position: fixed;
  inset: 0;
  pointer-events: none;
  background:
    radial-gradient(circle at 12% 18%, rgba(36, 169, 155, 0.12), transparent 24rem),
    radial-gradient(circle at 84% 12%, rgba(26, 138, 85, 0.12), transparent 26rem);
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
  background: #1A8A55 !important;
  border-color: #1A8A55 !important;
}

button[type="submit"]:hover,
.btn-primary:hover,
.login-button:hover {
  background: #176647 !important;
  border-color: #176647 !important;
}

img[src*="company_logo"] {
  max-width: 430px !important;
  height: auto !important;
}

body:has([class*="about"]) img[src*="company_logo"],
[class*="about"] img[src*="company_logo"],
[class*="About"] img[src*="company_logo"],
.about img[src*="company_logo"] {
  content: url("/legacy/themes/suite8/images/company_logo.png") !important;
  width: min(430px, 78vw) !important;
  max-width: 430px !important;
  height: auto !important;
}

[class*="about"],
[class*="About"],
.about {
  color: #161c2d !important;
}

footer,
.footer,
.login-footer {
  color: #5f6470 !important;
}

.loading,
.loader,
.loading-screen,
.loading-container,
.spinner,
.loading-icon,
.suitecrm-loader,
scrm-loading,
scrm-loader,
app-loading {
  position: relative !important;
}

.loading::before,
.loader::before,
.loading-screen::before,
.loading-container::before,
.spinner::before,
.loading-icon::before,
.suitecrm-loader::before,
scrm-loading::before,
scrm-loader::before,
app-loading::before {
  content: "" !important;
  position: absolute !important;
  left: 50% !important;
  top: 50% !important;
  width: 82px !important;
  height: 82px !important;
  margin: -41px 0 0 -41px !important;
  background: url("/legacy/themes/suite8/images/orqo-icon.png?v=20260512b") center / contain no-repeat !important;
  animation: orqo-loader-pulse 1.35s ease-in-out infinite !important;
  z-index: 20 !important;
}

.loading *,
.loader *,
.loading-screen *,
.loading-container *,
.spinner *,
.loading-icon *,
.suitecrm-loader *,
scrm-loading *,
scrm-loader *,
app-loading * {
  visibility: hidden !important;
}

body .app-overlay,
body app-full-page-spinner .app-overlay,
body scrm-full-page-spinner .app-overlay {
  position: fixed !important;
  inset: 0 !important;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  background: rgba(247, 243, 236, 0.94) !important;
  z-index: 99999 !important;
}

body .app-overlay::after,
body app-full-page-spinner .app-overlay::after,
body scrm-full-page-spinner .app-overlay::after {
  content: "" !important;
  width: 88px !important;
  height: 88px !important;
  background: url("/legacy/themes/suite8/images/orqo-icon.png?v=20260512c") center / contain no-repeat !important;
  animation: orqo-loader-pulse 1.2s ease-in-out infinite !important;
  display: block !important;
}

body .app-overlay #overlay-spinner,
body .app-overlay .spinner,
body .app-overlay [class*="spinner"],
body .app-overlay [class*="Spinner"],
body .app-overlay [class*="cube"],
body .app-overlay [class*="Cube"],
body .app-overlay [class*="square"],
body .app-overlay [class*="Square"],
body .app-overlay [class*="rect"],
body .app-overlay [class*="Rect"] {
  opacity: 0 !important;
  visibility: hidden !important;
  background: transparent !important;
  box-shadow: none !important;
}

@keyframes orqo-loader-pulse {
  0% {
    opacity: 0.58;
    transform: scale(0.9) rotate(-8deg);
    filter: drop-shadow(0 0 0 rgba(26, 138, 85, 0));
  }

  50% {
    opacity: 1;
    transform: scale(1.04) rotate(0deg);
    filter: drop-shadow(0 0 16px rgba(26, 138, 85, 0.28));
  }

  100% {
    opacity: 0.58;
    transform: scale(0.9) rotate(8deg);
    filter: drop-shadow(0 0 0 rgba(26, 138, 85, 0));
  }
}
/* ORQO_CRM_BRANDING_END */
EOF
  done

  if [[ -f public/site.webmanifest ]]; then
    sed -i \
      -e "s/SuiteCRM/${ORQO_BRAND_NAME}/g" \
      -e "s/Suite CRM/${ORQO_BRAND_NAME}/g" \
      -e "s/SugarCRM/${ORQO_BRAND_NAME}/g" \
      -e "s/Sugar CRM/${ORQO_BRAND_NAME}/g" \
      -e "s/SalesAgility/Orqo/g" \
      -e "s/Open Source CRM/Engineering CRM/g" \
      -e "s/Open source CRM/Engineering CRM/g" \
      -e "s/Powered By ${ORQO_BRAND_NAME}/Powered by Orqo/g" \
      -e "s/Powered by ${ORQO_BRAND_NAME}/Powered by Orqo/g" \
      public/site.webmanifest
  fi

  if [[ -f public/legacy/themes/suite8/tpls/_head.tpl ]]; then
    sed -i \
      -e "s/SuiteCRM/${ORQO_BRAND_NAME}/g" \
      -e "s/Suite CRM/${ORQO_BRAND_NAME}/g" \
      -e "s/SugarCRM/${ORQO_BRAND_NAME}/g" \
      -e "s/Sugar CRM/${ORQO_BRAND_NAME}/g" \
      -e "s/SalesAgility/Orqo/g" \
      -e "s/Open Source CRM/Engineering CRM/g" \
      -e "s/Open source CRM/Engineering CRM/g" \
      -e "s/Powered By ${ORQO_BRAND_NAME}/Powered by Orqo/g" \
      -e "s/Powered by ${ORQO_BRAND_NAME}/Powered by Orqo/g" \
      public/legacy/themes/suite8/tpls/_head.tpl
  fi

  find public/legacy \( -path '*/cache/*' -o -path '*/custom/*' \) -prune -o \
    -type f \( -name '*.tpl' -o -name '*.js' -o -name '*.html' \) -exec sed -i \
      -e "s/SuiteCRM/${ORQO_BRAND_NAME}/g" \
      -e "s/Suite CRM/${ORQO_BRAND_NAME}/g" \
      -e "s/SugarCRM/${ORQO_BRAND_NAME}/g" \
      -e "s/Sugar CRM/${ORQO_BRAND_NAME}/g" \
      -e "s/SalesAgility/Orqo/g" \
      -e "s/Open Source CRM/Engineering CRM/g" \
      -e "s/Open source CRM/Engineering CRM/g" \
      -e "s/Powered By ${ORQO_BRAND_NAME}/Powered by Orqo/g" \
      -e "s/Powered by ${ORQO_BRAND_NAME}/Powered by Orqo/g" \
      {} + 2>/dev/null || true
}

repair_core_branding_side_effects() {
  if [[ ! -d public/legacy ]]; then
    return
  fi

  log "Repairing protected legacy PHP namespaces after branding overlay."

  find public/legacy \( -path '*/custom/*' -o -path '*/cache/*' \) -prune -o \
    -type f -name '*.php' -exec sed -i \
      -e 's/Orqo CRM\\/SugarCRM\\/g' \
      -e 's/Orqo CRM_/SugarCRM_/g' \
      -e 's/Orqo CRM::/SugarCRM::/g' \
      {} + 2>/dev/null || true
}

install_orqo_runtime_branding_patch() {
  local version="${ORQO_BRANDING_ASSET_VERSION:-20260512b}"

  log "Installing Orqo CRM runtime branding patch."

  cat > public/orqo-branding-runtime.css <<'EOF'
/* ORQO_RUNTIME_BRANDING_START */
:root {
  --orqo-ink: #161c2d;
  --orqo-coral: #1A8A55;
  --orqo-teal: #00c784;
  --orqo-muted: #7c8a8a;
}

.orqo-loader-host {
  position: relative !important;
  background: transparent !important;
  box-shadow: none !important;
}

.orqo-loader-host::after {
  content: "" !important;
  position: absolute !important;
  left: 50% !important;
  top: 50% !important;
  width: 86px !important;
  height: 86px !important;
  margin: -43px 0 0 -43px !important;
  background: url("/legacy/themes/suite8/images/orqo-icon.png?v=20260512b") center / contain no-repeat !important;
  animation: orqo-loader-orbit 1.2s ease-in-out infinite !important;
  z-index: 9999 !important;
  pointer-events: none !important;
}

.orqo-loader-host > *,
.orqo-loader-host [class*="cube"],
.orqo-loader-host [class*="Cube"],
.orqo-loader-host [class*="square"],
.orqo-loader-host [class*="Square"],
.orqo-loader-host [class*="rect"],
.orqo-loader-host [class*="Rect"],
.orqo-loader-piece {
  opacity: 0 !important;
  visibility: hidden !important;
  background: transparent !important;
  box-shadow: none !important;
}

body .app-overlay,
body app-full-page-spinner .app-overlay,
body scrm-full-page-spinner .app-overlay {
  position: fixed !important;
  inset: 0 !important;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  background: rgba(247, 243, 236, 0.94) !important;
  z-index: 99999 !important;
}

body .app-overlay::after,
body app-full-page-spinner .app-overlay::after,
body scrm-full-page-spinner .app-overlay::after {
  content: "" !important;
  width: 88px !important;
  height: 88px !important;
  background: url("/legacy/themes/suite8/images/orqo-icon.png?v=20260512c") center / contain no-repeat !important;
  animation: orqo-loader-orbit 1.2s ease-in-out infinite !important;
  display: block !important;
}

body .app-overlay #overlay-spinner,
body .app-overlay .spinner,
body .app-overlay [class*="spinner"],
body .app-overlay [class*="Spinner"],
body .app-overlay [class*="cube"],
body .app-overlay [class*="Cube"],
body .app-overlay [class*="square"],
body .app-overlay [class*="Square"],
body .app-overlay [class*="rect"],
body .app-overlay [class*="Rect"] {
  opacity: 0 !important;
  visibility: hidden !important;
  background: transparent !important;
  box-shadow: none !important;
}

.sk-cube-grid,
.cube-grid,
.sk-spinner,
.scrm-loader,
.suitecrm-loader,
[class*="suite-loader"],
[class*="SuiteLoader"] {
  background: transparent !important;
  box-shadow: none !important;
}

.orqo-about-logo {
  display: block !important;
  width: min(420px, 78vw) !important;
  height: auto !important;
  margin: 0 0 2rem !important;
}

.orqo-about-title {
  color: var(--orqo-ink) !important;
  font-weight: 600 !important;
}

@keyframes orqo-loader-orbit {
  0% {
    opacity: 0.56;
    transform: scale(0.92) rotate(-8deg);
    filter: drop-shadow(0 0 0 rgba(26, 138, 85, 0));
  }

  50% {
    opacity: 1;
    transform: scale(1.05) rotate(0deg);
    filter: drop-shadow(0 0 18px rgba(26, 138, 85, 0.28));
  }

  100% {
    opacity: 0.56;
    transform: scale(0.92) rotate(8deg);
    filter: drop-shadow(0 0 0 rgba(26, 138, 85, 0));
  }
}
/* ORQO_RUNTIME_BRANDING_END */
EOF

  cat > public/orqo-branding-runtime.js <<'EOF'
(function () {
  "use strict";

  var BRAND = "Orqo CRM";
  var ASSET_VERSION = "20260512b";
  var aboutText = {
    "SuiteCRM - Open source CRM for the world": "Orqo CRM - Engineering CRM para alta ingenieria, fidelizacion y PQRS",
    "SuiteCRM - Open Source CRM for the world": "Orqo CRM - Engineering CRM para alta ingenieria, fidelizacion y PQRS",
    "About SuiteCRM": "Acerca de Orqo CRM",
    "About SuiteCRM Translations": "Traducciones de Orqo CRM",
    "SuiteCRM is published under an open source licence - AGPLv3": "Orqo CRM se basa en una plataforma open source AGPLv3 y se personaliza para procesos de alta ingenieria.",
    "All SuiteCRM code managed and developed by the project will be released as open source - AGPLv3": "Las extensiones propias de Orqo CRM se mantienen en la capa custom para conservar compatibilidad de actualizacion.",
    "SuiteCRM support is available in both free and paid-for options": "El soporte operativo de Orqo CRM se gestiona por el equipo de arquitectura y SRE del proyecto.",
    "Collaborative translation by the SuiteCRM Community": "Localizacion gestionada para la operacion de Orqo CRM.",
    "Translation created using Crowdin": "Traducciones adaptadas para Orqo CRM.",
    "We have loyal SuiteCRM partners who are passionate about open source. To view our full partner list, see our website.": "Orqo CRM integra capacidades de CRM, fidelizacion, PQRS y arquitectura de software para equipos de alta exigencia.",
    "SuiteCRM LOGO Provided by Conscious Solutions": "Identidad visual Orqo CRM.",
    "SugarCRM Inc - providers of CE framework": "Base CRM legacy compatible con el ecosistema SuiteCRM."
  };

  var textRules = [
    [/Suite\s*CRM/g, BRAND],
    [/SuiteCRM/g, BRAND],
    [/SugarCRM/g, BRAND],
    [/Sugar\s*CRM/g, BRAND],
    [/SalesAgility/g, "Orqo"]
  ];

  function isAboutRoute() {
    return window.location.hash.indexOf("/home/about") !== -1;
  }

  function replaceTextNode(node) {
    var value = node.nodeValue;
    var trimmed = value.trim();
    var next = value;

    if (aboutText[trimmed]) {
      next = value.replace(trimmed, aboutText[trimmed]);
    }

    textRules.forEach(function (rule) {
      next = next.replace(rule[0], rule[1]);
    });

    if (next !== value) {
      node.nodeValue = next;
    }
  }

  function walkText(root) {
    if (!root) {
      return;
    }

    var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
      acceptNode: function (node) {
        if (!node.nodeValue || !node.nodeValue.trim()) {
          return NodeFilter.FILTER_REJECT;
        }
        return NodeFilter.FILTER_ACCEPT;
      }
    });

    var node;
    while ((node = walker.nextNode())) {
      replaceTextNode(node);
    }
  }

  function patchLogos() {
    var logo = isAboutRoute()
      ? "/legacy/themes/suite8/images/company_logo.png"
      : "/legacy/themes/suite8/images/company_logo_white.png";

    document.querySelectorAll('img[src*="company_logo"], img[src*="suitecrm"], img[alt*="Suite"]').forEach(function (img) {
      img.src = logo + "?v=" + ASSET_VERSION;
      img.alt = BRAND;
      if (isAboutRoute()) {
        img.classList.add("orqo-about-logo");
      }
    });
  }

  function patchAboutHeadings() {
    if (!isAboutRoute()) {
      return;
    }

    document.querySelectorAll("h1, h2, h3").forEach(function (heading) {
      if (heading.textContent.indexOf(BRAND) !== -1) {
        heading.classList.add("orqo-about-title");
      }
    });
  }

  function patchLoaders() {
    var selectors = [
      ".sk-cube-grid",
      ".cube-grid",
      ".sk-spinner",
      ".scrm-loader",
      ".suitecrm-loader",
      ".loading",
      ".loader",
      ".loading-screen",
      ".loading-container",
      ".spinner",
      "[class*='cube-grid']",
      "[class*='CubeGrid']",
      "[class*='cube']",
      "[class*='Cube']",
      "[class*='square']",
      "[class*='Square']",
      "[class*='rect']",
      "[class*='Rect']",
      "[class*='suitecrm-loader']",
      "[class*='SuiteCRMLoader']"
    ];

    document.querySelectorAll(selectors.join(",")).forEach(function (el) {
      var rect = el.getBoundingClientRect();
      if (rect.width <= 220 && rect.height <= 220) {
        var className = String(el.className || "");
        var isPiece = /cube|square|rect/i.test(className) && rect.width <= 80 && rect.height <= 80;
        if (isPiece) {
          el.classList.add("orqo-loader-piece");
          if (el.parentElement) {
            var parentRect = el.parentElement.getBoundingClientRect();
            if (parentRect.width <= 240 && parentRect.height <= 240) {
              el.parentElement.classList.add("orqo-loader-host");
              return;
            }
          }
        }
        el.classList.add("orqo-loader-host");
      }
    });
  }

  function applyBranding() {
    walkText(document.body);
    patchLogos();
    patchAboutHeadings();
    patchLoaders();
  }

  function start() {
    applyBranding();

    var observer = new MutationObserver(function () {
      window.requestAnimationFrame(applyBranding);
    });

    observer.observe(document.documentElement, {
      childList: true,
      subtree: true,
      characterData: true
    });

    window.addEventListener("hashchange", applyBranding);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start);
  } else {
    start();
  }
})();
EOF

  if [[ -f public/index.html ]]; then
    sed -i -E \
      -e 's#<link rel="stylesheet" href="/orqo-branding-runtime\.css\?v=[^"]*">##g' \
      -e 's#<script src="/orqo-branding-runtime\.js\?v=[^"]*" defer></script>##g' \
      public/index.html

    if grep -q '</head>' public/index.html; then
      sed -i "s#</head>#<link rel=\"stylesheet\" href=\"/orqo-branding-runtime.css?v=${version}\"></head>#" public/index.html
    fi

    if grep -q '</body>' public/index.html; then
      sed -i "s#</body>#<script src=\"/orqo-branding-runtime.js?v=${version}\" defer></script></body>#" public/index.html
    else
      printf '\n<script src="/orqo-branding-runtime.js?v=%s" defer></script>\n' "${version}" >> public/index.html
    fi
  fi
}

refresh_orqo_ui_cache() {
  log "Refreshing Orqo CRM UI language and branding cache."

  rm -rf \
    public/legacy/cache/jsLanguage/Home \
    public/legacy/cache/jsLanguage/application \
    public/legacy/cache/themes \
    public/legacy/cache/smarty/templates_c/* \
    2>/dev/null || true

  find public/legacy/cache -type f \( \
    -name '*Home*en_us*' -o \
    -name '*Home*es_ES*' -o \
    -name '*suitecrm*' -o \
    -name '*SuiteCRM*' \
  \) -delete 2>/dev/null || true
}

install_spanish_language_pack_if_needed() {
  if [[ "${ORQO_DEFAULT_LANGUAGE}" != "es_ES" ]]; then
    return
  fi

  if [[ -f public/legacy/include/language/es_ES.lang.php && -f public/legacy/modules/Accounts/language/es_ES.lang.php ]]; then
    log "Spanish language pack already present."
    return
  fi

  log "Installing Spanish language pack for Orqo CRM."

  local tmp_dir
  tmp_dir="$(mktemp -d)"

  if ! curl -fL --retry 5 --retry-delay 5 --connect-timeout 30 \
    -o "${tmp_dir}/es_ES_lang.zip" \
    "${ORQO_SPANISH_LANGUAGE_PACK_URL}"; then
    log "Spanish language pack download failed; keeping current language files."
    rm -rf "${tmp_dir}"
    return
  fi

  unzip -q "${tmp_dir}/es_ES_lang.zip" -d "${tmp_dir}/extract"

  local language_root
  language_root="$(find "${tmp_dir}/extract" -mindepth 1 -maxdepth 3 -type f -name manifest.php -printf '%h\n' | head -n 1)"

  if [[ -z "${language_root}" ]]; then
    language_root="$(find "${tmp_dir}/extract" -mindepth 1 -maxdepth 3 -type f -path '*/include/language/es_ES.lang.php' -printf '%h\n' | sed 's#/include/language##' | head -n 1)"
  fi

  if [[ -z "${language_root}" || ! -d "${language_root}" ]]; then
    log "Spanish language pack structure was not recognized; keeping current language files."
    rm -rf "${tmp_dir}"
    return
  fi

  cp -a "${language_root}/." public/legacy/
  rm -rf "${tmp_dir}"
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
\$sugar_config['default_language'] = '${ORQO_DEFAULT_LANGUAGE}';
\$sugar_config['languages']['en_us'] = 'English (US)';
\$sugar_config['languages']['es_ES'] = 'Espanol (Espana)';
\$sugar_config['default_currency_name'] = 'Colombian Peso';
\$sugar_config['default_currency_symbol'] = '$';
\$sugar_config['default_currency_iso4217'] = 'COP';
\$sugar_config['default_currency_significant_digits'] = '2';
\$sugar_config['default_number_grouping_seperator'] = '.';
\$sugar_config['default_decimal_seperator'] = ',';
\$sugar_config['company_logo'] = 'company_logo.png';
\$sugar_config['company_logo_url'] = '';
\$sugar_config['company_logo_width'] = '720';
\$sugar_config['company_logo_height'] = '150';
EOF

  touch public/legacy/config_override.php
  if [[ ! -s public/legacy/config_override.php ]]; then
    printf "%s\n" "<?php" > public/legacy/config_override.php
  fi

  if ! grep -q "orqo_branding_config.php" public/legacy/config_override.php; then
    printf "\nrequire_once __DIR__ . '/custom/orqo_branding_config.php';\n" >> public/legacy/config_override.php
  fi
}

configure_orqo_currency_and_locale() {
  if ! database_has_suitecrm; then
    return
  fi

  local usd_to_cop_rate
  local suitecrm_usd_rate

  usd_to_cop_rate="$(fetch_current_trm)"
  suitecrm_usd_rate="$(php -r 'printf("%.12F", 1 / (float) $argv[1]);' "${usd_to_cop_rate}")"

  log "Configuring Orqo CRM locale: ${ORQO_DEFAULT_LANGUAGE}, COP base currency, USD secondary. TRM=${usd_to_cop_rate}; SuiteCRM USD conversion_rate=${suitecrm_usd_rate}."

  MYSQL_PWD="${DB_PASSWORD}" mysql \
    --host="${DB_HOST}" \
    --port="${DB_PORT}" \
    --user="${DB_USER}" \
    --database="${DB_NAME}" \
    --execute="
      INSERT INTO config (category, name, value)
      VALUES
        ('system', 'default_language', '${ORQO_DEFAULT_LANGUAGE}'),
        ('system', 'default_currency_name', 'Colombian Peso'),
        ('system', 'default_currency_symbol', '$'),
        ('system', 'default_currency_iso4217', 'COP'),
        ('system', 'default_currency_significant_digits', '2'),
        ('system', 'default_number_grouping_seperator', '.'),
        ('system', 'default_decimal_seperator', ',')
      ON DUPLICATE KEY UPDATE value = VALUES(value);

      INSERT INTO currencies (
        id, name, symbol, iso4217, conversion_rate, status, deleted,
        date_entered, date_modified, created_by
      )
      VALUES (
        'orqo-usd-secondary',
        'US Dollar',
        '$',
        'USD',
        ${suitecrm_usd_rate},
        'Active',
        0,
        UTC_TIMESTAMP(),
        UTC_TIMESTAMP(),
        '1'
      )
      ON DUPLICATE KEY UPDATE
        name = VALUES(name),
        symbol = VALUES(symbol),
        iso4217 = VALUES(iso4217),
        conversion_rate = VALUES(conversion_rate),
        status = 'Active',
        deleted = 0,
        date_modified = UTC_TIMESTAMP();

    " 2>/dev/null || log "Currency/locale DB configuration skipped; schema may still be initializing."

  MYSQL_PWD="${DB_PASSWORD}" mysql \
    --host="${DB_HOST}" \
    --port="${DB_PORT}" \
    --user="${DB_USER}" \
    --database="${DB_NAME}" \
    --execute="
      UPDATE user_preferences
      SET contents = REPLACE(contents, 'en_us', '${ORQO_DEFAULT_LANGUAGE}')
      WHERE assigned_user_id = '1' AND deleted = 0;
    " 2>/dev/null || true
}

fetch_current_trm() {
  local trm

  trm="$(
    curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 "${ORQO_TRM_API_URL}" \
      | php -r '
          $payload = stream_get_contents(STDIN);
          $rows = json_decode($payload, true);
          $value = $rows[0]["valor"] ?? null;
          if (!is_numeric($value)) {
              exit(1);
          }
          printf("%.6F", (float) $value);
        ' 2>/dev/null
  )" || trm=""

  if [[ -z "${trm}" ]]; then
    printf '[orqo-entrypoint] %s\n' "TRM API unavailable; using fallback USD/COP rate ${ORQO_USD_TO_COP_RATE_FALLBACK}." >&2
    trm="${ORQO_USD_TO_COP_RATE_FALLBACK}"
  else
    printf '[orqo-entrypoint] %s\n' "Fetched official Colombian TRM from datos.gov.co: ${trm} COP per USD." >&2
  fi

  printf '%s' "${trm}"
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
  install_spanish_language_pack_if_needed
  write_legacy_branding_config
  repair_core_branding_side_effects
  replace_visible_suitecrm_branding
  install_orqo_runtime_branding_patch
  refresh_orqo_ui_cache
  run_composer_install
  ensure_permissions
  install_suitecrm_if_needed "$@"
  configure_orqo_currency_and_locale
  reset_admin_password_if_requested
  ensure_permissions
  tail_application_logs

  exec "$@"
}

main "$@"
