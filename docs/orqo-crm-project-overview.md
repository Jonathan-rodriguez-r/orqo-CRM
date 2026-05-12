# Orqo CRM - Documento tecnico del proyecto

Fecha de referencia: 2026-05-12

## Proposito

Orqo CRM es una distribucion personalizada de SuiteCRM 8 orientada a procesos de alta ingenieria, fidelizacion y PQRS. El producto conserva la base tecnica de SuiteCRM 8, pero la experiencia publica, el branding, el login, los textos visibles y la configuracion regional se presentan bajo la identidad de Orqo CRM.

Este documento resume lo implementado hasta ahora, la estructura del repositorio y las decisiones relevantes para continuar el desarrollo sin romper la compatibilidad con SuiteCRM.

## Base tecnologica

Orqo CRM se apoya en la arquitectura hibrida de SuiteCRM 8:

- Capa moderna Symfony/Angular: ubicada principalmente en `core/`, `public/`, `public/dist` y `bin/console` dentro de la aplicacion descargada en runtime.
- Capa legacy SugarCRM/SuiteCRM: ubicada en `public/legacy`, donde viven Beans, metadatos, vardefs, viewdefs, logic hooks, temas legacy, cache y archivos de idioma.
- Capa custom upgrade-safe: ubicada en `public/legacy/custom`. Todas las personalizaciones propias deben vivir aqui o ser inyectadas desde el entrypoint sin editar el core instalado.

Importante: aunque la interfaz se rebrandea como Orqo CRM, internamente siguen existiendo clases, namespaces y convenciones de SuiteCRM/SugarCRM que no deben ser reemplazadas globalmente.

## Estructura actual del repositorio

```text
.
|-- Dockerfile
|-- docker-compose.yml
|-- docker/
|   `-- entrypoint.sh
|-- public/
|   `-- legacy/
|       `-- custom/
|           |-- Extension/
|           |-- application/
|           |-- modules/
|           `-- themes/
|-- database/
|   `-- seeders/
|-- docs/
|   |-- railway-orqo-crm.md
|   `-- orqo-crm-project-overview.md
`-- .gitignore
```

El repositorio no contiene todo SuiteCRM versionado. El contenedor descarga SuiteCRM en runtime si el volumen esta vacio, y luego aplica el overlay de Orqo desde `public/legacy/custom`.

## Infraestructura Docker y Railway

Se creo una imagen basada en `php:8.2-apache-bookworm`.

Extensiones instaladas:

- `mysqli`
- `pdo_mysql`
- `gd`
- `zip`
- `xml`
- `mbstring`
- `imap`
- `curl`
- `opcache`
- `intl`
- `bcmath`
- `soap`

Apache queda configurado con:

- `DocumentRoot` en `/var/www/html/public`
- `mod_rewrite`
- `headers`
- `expires`
- `remoteip`
- `mpm_prefork`
- puerto HTTP `80`

Railway debe apuntar el dominio al puerto `80`.

## Persistencia

Railway usa almacenamiento efimero en el contenedor, por eso el proyecto monta un volumen persistente en `/data`.

El entrypoint enlaza o persiste:

- `public/legacy/cache`
- `public/legacy/upload`
- `public/legacy/custom`
- `logs`
- `config.php`
- `.env.local`
- configuraciones runtime necesarias para reinicios

El objetivo es que los uploads, configuraciones, cache legacy y personalizaciones no se pierdan entre despliegues.

## EntryPoint

El archivo principal de orquestacion es `docker/entrypoint.sh`.

Responsabilidades actuales:

- Configurar runtime PHP/Apache.
- Descargar SuiteCRM `8.8.1` si `/var/www/html` esta vacio.
- Aplicar el overlay de Orqo desde `/opt/orqo-overlay`.
- Copiar logos, favicon e iconos Orqo a rutas esperadas por SuiteCRM.
- Instalar paquete de idioma `es_ES` cuando corresponde.
- Escribir configuracion de marca en legacy.
- Reparar efectos colaterales de branding sobre namespaces protegidos.
- Reemplazar textos visibles de SuiteCRM/SugarCRM/SalesAgility en assets seguros.
- Inyectar parche runtime de branding para loader y About.
- Ejecutar `composer install` cuando aplique.
- Preparar permisos `www-data`.
- Esperar la base de datos.
- Ejecutar instalacion desatendida si no existe DB instalada.
- Configurar moneda COP y USD secundaria.
- Consultar TRM oficial cuando esta disponible.
- Resetear password admin si `RESET_ADMIN_PASSWORD` existe.
- Arrancar Apache.

## Instalacion desatendida

La instalacion se realiza con:

```bash
bin/console suitecrm:app:install
```

Variables usadas por el contenedor:

- `DB_HOST`
- `DB_PORT`
- `DB_NAME`
- `DB_USER`
- `DB_PASSWORD`
- `SITE_URL`
- `ADMIN_USER`
- `ADMIN_PASSWORD`
- `APP_ENV`
- `APP_DEBUG`
- `APP_SECRET`

El proceso es idempotente: si la base de datos ya contiene la tabla `users`, no reinstala.

## Variables Railway relevantes

No se deben documentar secretos reales en Git. Usar referencias o variables.

Variables esperadas:

```env
APP_ENV="prod"
APP_DEBUG="0"
APP_SECRET="<generado-seguro>"
PHP_TIMEZONE="America/Bogota"
SITE_URL="https://crm.orqo.io"

DB_HOST="${{MYSQLHOST}}"
DB_PORT="${{MYSQLPORT}}"
DB_NAME="${{MYSQLDATABASE}}"
DB_USER="${{MYSQLUSER}}"
DB_PASSWORD="${{MYSQLPASSWORD}}"

MYSQLHOST="${{RAILWAY_PRIVATE_DOMAIN}}"
MYSQLPORT="3306"
MYSQLDATABASE="${{MYSQL_DATABASE}}"
MYSQLUSER="root"
MYSQLPASSWORD="${{MYSQL_ROOT_PASSWORD}}"

ORQO_DEFAULT_LANGUAGE="es_ES"
ORQO_INSTALL_SPANISH_PACK="1"
ORQO_DEFAULT_CURRENCY_ISO4217="COP"
ORQO_USD_TO_COP_RATE_FALLBACK="4000.000000"
```

`RESET_ADMIN_PASSWORD` solo debe usarse temporalmente para recuperar acceso. Despues de entrar y cambiar la clave desde la UI, conviene eliminar esa variable.

## Branding y ofuscacion visual de SuiteCRM

Objetivo: que el usuario final vea Orqo CRM, no SuiteCRM.

Se personalizo:

- Logo del login.
- Logo del header para fondos oscuros.
- Favicon.
- Manifest/iconos del navegador.
- Textos globales de busqueda y titulo.
- Footer del login.
- Pantalla `About`.
- Loader/spinner inicial.
- Assets visibles de `public/dist`.
- Assets visibles legacy HTML/TPL/JS.

Archivos y rutas relevantes:

```text
public/legacy/custom/themes/default/images/company_logo.png
public/legacy/custom/themes/default/images/company_logo_white.png
public/legacy/custom/themes/default/images/orqo-icon.png
public/legacy/custom/themes/default/images/favicon.ico
public/legacy/custom/themes/suite8/css/Dawn/style.css
public/legacy/custom/Extension/application/Ext/Language/
public/legacy/custom/application/Ext/Language/
```

Tambien se agrego un parche runtime desde `entrypoint.sh`:

- `public/orqo-branding-runtime.css`
- `public/orqo-branding-runtime.js`

Este parche observa el DOM de Angular y corrige textos visibles que llegan despues de cargar, especialmente en:

- `#/home/about`
- loader inicial
- logos cargados por rutas internas

## Regla critica de branding

No hacer reemplazos globales en archivos PHP del core.

Error que ya ocurrio:

```text
SugarCRM\ErrorMessage -> Orqo CRM\ErrorMessage
Zend_Oauth_Provider -> Orqo CRM\Zend_Oauth_Provider
```

Eso rompe namespaces y genera errores fatales.

Regla:

- Reemplazos visibles: si.
- Reemplazos en `.tpl`, `.html`, `.js`, `.json`, `.webmanifest`: con cuidado.
- Reemplazos en `public/legacy/custom`: si son archivos propios.
- Reemplazos en PHP core legacy/Symfony: no.
- Si se toca branding desde script, excluir `cache`, `custom` cuando aplique y reparar namespaces protegidos.

## Idioma

Se configuro `es_ES` como idioma principal de Orqo CRM.

Se agregaron overrides especificos para interfaz en:

```text
public/legacy/custom/Extension/application/Ext/Language/es_ES.orqo_ui_labels.php
public/legacy/custom/application/Ext/Language/es_ES.lang.ext.php
public/legacy/custom/Extension/modules/Accounts/Ext/Language/es_ES.orqo_ui_labels.php
public/legacy/custom/modules/Accounts/Ext/Language/es_ES.lang.ext.php
public/legacy/custom/Extension/modules/Contacts/Ext/Language/es_ES.orqo_ui_labels.php
public/legacy/custom/modules/Contacts/Ext/Language/es_ES.lang.ext.php
public/legacy/custom/Extension/modules/Opportunities/Ext/Language/es_ES.orqo_ui_labels.php
public/legacy/custom/modules/Opportunities/Ext/Language/es_ES.lang.ext.php
public/legacy/custom/Extension/modules/AOS_Quotes/Ext/Language/es_ES.orqo_ui_labels.php
public/legacy/custom/modules/AOS_Quotes/Ext/Language/es_ES.lang.ext.php
```

Modulos cubiertos:

- Cuentas
- Contactos
- Oportunidades
- Presupuestos
- Etiquetas globales comunes

Nota: los overrides de interfaz en espanol no modifican `en_us`. Si un usuario selecciona English, debe conservar la UI en ingles.

## Moneda y TRM

Se configuro COP como moneda base y USD como moneda secundaria.

El entrypoint intenta consultar la TRM vigente desde datos.gov.co:

- Recurso: `32sa-8pi3`
- Campo usado: `valor`

Si la consulta falla, usa `ORQO_USD_TO_COP_RATE_FALLBACK`.

SuiteCRM maneja la tasa de monedas relativo a la moneda base. Por eso, si COP es base, la tasa USD se calcula como:

```text
conversion_rate_USD = 1 / TRM
```

## Logic Hook de fidelizacion

Se agrego una base para fidelizacion en `Opportunities`.

Rutas:

```text
public/legacy/custom/modules/Opportunities/OrqoLoyaltyAfterSave.php
public/legacy/custom/modules/Opportunities/services/OrqoLoyaltyPointsService.php
public/legacy/custom/Extension/modules/Opportunities/Ext/LogicHooks/orqo_loyalty_after_save.php
public/legacy/custom/Extension/modules/Opportunities/Ext/Vardefs/orqo_loyalty_points.php
```

Objetivo:

- Ejecutar hook `after_save`.
- Detectar oportunidad en estado `Closed Won`.
- Calcular puntos de fidelizacion a partir del monto.
- Guardar el resultado en campo custom.

## Seeders demo Colombia

Se creo seeder SQL para demo:

```text
database/seeders/demo_colombia.sql
```

Incluye datos orientados a Colombia:

- Cuentas de banca y telco.
- Productos/servicios de arquitectura e IA.
- Casos PQRS con descripciones tecnicas.

## Desarrollo local

Archivo:

```text
docker-compose.yml
```

Servicios:

- `app`: Orqo CRM PHP/Apache.
- `db`: MariaDB 10.11.

Comando base:

```bash
docker compose up --build
```

URL local esperada:

```text
http://localhost:8080
```

## Flujo Git y despliegue

Repositorio remoto:

```text
https://github.com/Jonathan-rodriguez-r/orqo-CRM.git
```

Rama principal:

```text
main
```

Railway despliega automaticamente desde `main`.

Commits recientes relevantes:

```text
e5e7d70 fix(branding): patch runtime loader and about identity
a23cb6f fix(i18n): localize Spanish CRM interface labels
0ee3f62 fix(branding): update about page identity
357b1fa style(branding): replace SuiteCRM loader with Orqo animation
0af9b12 style(branding): use provided Orqo logos and favicon
f964358 style(branding): update Orqo logo mark
493670f fix(branding): repair legacy PHP namespace replacements
8f10bb9 fix(branding): use white header logo and remove Sugar footer
ca813d7 feat(locale): update USD rate from official TRM
5b1fa98 feat(locale): default Orqo CRM to Spanish and COP
07846c5 fix(branding): copy overlay into custom symlink target
ca6455b feat(branding): apply Orqo CRM identity overlay
```

## Problemas resueltos

### Dependencias de Docker

Se ajusto la base a Debian Bookworm para resolver paquetes disponibles y extensiones PHP necesarias.

### Driver de base de datos

Error resuelto:

```text
could not find driver
```

Se agrego `pdo_mysql`.

### APP_SECRET

Error resuelto:

```text
Environment variable not found: APP_SECRET
```

Se aseguro escritura/persistencia de `.env.local`.

### Doctrine MariaDB serverVersion

Error resuelto por formato correcto:

```text
serverVersion=mariadb-10.11.0&charset=utf8mb4
```

### Apache MPM

Error resuelto:

```text
More than one MPM loaded
```

Se deshabilitan MPM no usados y se habilita `mpm_prefork`.

### Permisos de cache/logs

Errores resueltos:

```text
fatal rename failure
Unable to write in the logs directory
```

Se ajustaron `chown`, `chmod`, `TMPDIR`, symlinks y rutas persistentes.

### Login admin

Se agrego mecanismo temporal `RESET_ADMIN_PASSWORD`.

Nota: no dejar contrasenas ni hashes reales en documentacion ni en Git.

## Reglas para futuras personalizaciones

1. Mantener todo lo propio en `public/legacy/custom`.
2. Evitar editar archivos core descargados de SuiteCRM.
3. No reemplazar cadenas globalmente en PHP.
4. Usar `Extension Framework` para vardefs, logic hooks, labels y metadata.
5. Documentar nuevas variables de entorno sin secretos.
6. Si una pantalla Angular no respeta labels legacy, usar override runtime controlado o asset visible, no core.
7. Despues de cambios de idioma o metadata, limpiar cache o ejecutar Quick Repair si la UI no refresca.
8. Validar en Railway logs despues de cada deploy.

## Pendientes recomendados

- Crear modulo PQRS formal y sus vardefs upgrade-safe.
- Definir workflows AOW para escalamiento por prioridad y tiempo sin actualizacion.
- Formalizar scheduler/cron para TRM si se requiere actualizacion diaria fuera del arranque.
- Agregar healthcheck HTTP estable para Railway.
- Crear documentacion de recuperacion admin y rotacion de secretos.
- Agregar pruebas basicas de lint/sintaxis PHP en CI.
- Consolidar branding runtime con versionado de assets por variable.

## Resumen ejecutivo

Orqo CRM hoy es una capa custom y un bootstrap de infraestructura sobre SuiteCRM 8. La estrategia elegida evita versionar todo el core, descarga la base en runtime, monta persistencia en Railway y aplica una identidad Orqo upgrade-safe mediante overlay, language packs, CSS, assets y parches runtime controlados.

La prioridad tecnica es seguir respetando la arquitectura hibrida: SuiteCRM/SugarCRM permanece como motor interno, mientras Orqo CRM se presenta como producto final en la interfaz y experiencia de usuario.
