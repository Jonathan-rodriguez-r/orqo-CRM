# Orqo CRM - Datos demo Colombia

Este proyecto incluye un seeder idempotente para poblar Orqo CRM con informacion dummy orientada a una demo comercial/tecnica.

El seeder vive en:

```text
public/legacy/custom/orqo/seeders/demo_colombia.php
```

## Que crea

El demo crea un escenario Colombia con bancos y telcos:

- 5 cuentas empresariales.
- 5 contactos ejecutivos/tecnicos.
- 5 productos/servicios Orqo.
- 4 leads.
- 5 oportunidades en distintas etapas.
- 4 presupuestos/cotizaciones.
- 5 casos PQRS, incluyendo casos de prioridad alta envejecidos para demo de escalamiento.

## Flujo sugerido para mostrar

```text
Lead nuevo
  -> Calificacion comercial
  -> Cuenta + Contacto
  -> Oportunidad
  -> Presupuesto
  -> PQRS prioritaria
  -> Escalamiento SLA
  -> Closed Won
  -> Puntos de fidelizacion
```

## Ejecucion manual dentro del contenedor

Desde una shell del servicio Railway o un contenedor local ya instalado:

```bash
php public/legacy/custom/orqo/seeders/demo_colombia.php
```

El script es idempotente: intenta actualizar registros demo existentes por nombre/apellido/codigo en vez de duplicarlos.

## Ejecucion automatica en Railway

Agregar temporalmente la variable:

```env
ORQO_SEED_DEMO_DATA="1"
```

Luego redeploy.

Cuando el seeder termine y confirmes que los datos estan cargados, vuelve a dejar:

```env
ORQO_SEED_DEMO_DATA="0"
```

o elimina la variable.

Aunque el seeder es idempotente, se recomienda no dejarlo activo permanentemente en demos compartidas para evitar que sobrescriba cambios manuales hechos durante presentaciones.

## Modulos afectados

```text
Accounts
Contacts
Leads
Opportunities
AOS_Products
AOS_Quotes
Cases
```

## Notas tecnicas

- Usa `BeanFactory` y `SugarBean`, no SQL directo, para respetar hooks y comportamiento legacy.
- La oportunidad `Automatizacion PQRS omnicanal Movistar` queda en `Closed Won` para activar el hook de fidelizacion.
- Los casos PQRS de prioridad alta se dejan con `date_modified` envejecido para simular vencimiento de SLA.
- Los correos usan dominios `.example` para evitar direcciones reales.
- No incluye secretos, usuarios reales ni credenciales.
