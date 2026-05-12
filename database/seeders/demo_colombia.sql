-- Orqo CRM demo seed data for SuiteCRM 8 / MariaDB.
-- Assumes the default admin user id is '1' and AOS Products is installed.

SET @admin_id = '1';
SET @now = UTC_TIMESTAMP();

INSERT INTO accounts (
    id, name, date_entered, date_modified, modified_user_id, created_by,
    description, deleted, assigned_user_id, account_type, industry,
    phone_office, billing_address_city, billing_address_country
) VALUES
(
    '11111111-1111-4111-8111-000000000001',
    'Bancolombia S.A.',
    @now, @now, @admin_id, @admin_id,
    'NIT 890903938-8. Banco colombiano con foco en modernizacion de canales digitales, analitica de riesgo y automatizacion de experiencia cliente.',
    0, @admin_id, 'Customer', 'Banking',
    '+57 604 510 9000', 'Medellin', 'Colombia'
),
(
    '11111111-1111-4111-8111-000000000002',
    'Banco de Bogota S.A.',
    @now, @now, @admin_id, @admin_id,
    'NIT 860002964-4. Entidad financiera con necesidades de integracion core, gobierno API y trazabilidad operacional.',
    0, @admin_id, 'Customer', 'Banking',
    '+57 601 382 0000', 'Bogota', 'Colombia'
),
(
    '11111111-1111-4111-8111-000000000003',
    'Banco Davivienda S.A.',
    @now, @now, @admin_id, @admin_id,
    'NIT 860034313-7. Banco con ecosistemas transaccionales de alta disponibilidad y oportunidades de IA aplicada a servicio.',
    0, @admin_id, 'Customer', 'Banking',
    '+57 601 338 3838', 'Bogota', 'Colombia'
),
(
    '11111111-1111-4111-8111-000000000004',
    'Comunicacion Celular S.A. Comcel S.A.',
    @now, @now, @admin_id, @admin_id,
    'NIT 800153993-7. Operador Claro Colombia; foco demo en observabilidad, PQRS masivo e integracion omnicanal.',
    0, @admin_id, 'Customer', 'Telecommunications',
    '+57 601 742 9797', 'Bogota', 'Colombia'
),
(
    '11111111-1111-4111-8111-000000000005',
    'Colombia Telecomunicaciones S.A. ESP BIC',
    @now, @now, @admin_id, @admin_id,
    'NIT 830122566-1. Operador Movistar Colombia; foco demo en arquitectura de integracion, automatizacion PQRS y calidad de servicio.',
    0, @admin_id, 'Customer', 'Telecommunications',
    '+57 601 705 0000', 'Bogota', 'Colombia'
)
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    date_modified = VALUES(date_modified),
    modified_user_id = VALUES(modified_user_id),
    description = VALUES(description),
    industry = VALUES(industry),
    billing_address_city = VALUES(billing_address_city),
    billing_address_country = VALUES(billing_address_country);

INSERT INTO aos_products (
    id, name, date_entered, date_modified, modified_user_id, created_by,
    description, deleted, assigned_user_id, maincode, part_number,
    category, type, cost, price
) VALUES
(
    '22222222-2222-4222-8222-000000000001',
    'Assessment de Arquitectura Empresarial',
    @now, @now, @admin_id, @admin_id,
    'Diagnostico de arquitectura, riesgos tecnicos, mapa de capacidades, roadmap de modernizacion y recomendaciones C4/ADR.',
    0, @admin_id, 'ORQO-AE-001', 'ORQO-AE-001',
    'Consultoria', 'Service', 0, 28000000
),
(
    '22222222-2222-4222-8222-000000000002',
    'Diseno de Plataforma API y Gobierno',
    @now, @now, @admin_id, @admin_id,
    'Definicion de estrategia API, seguridad OAuth2/OIDC, versionamiento, observabilidad, contrato OpenAPI y politicas de consumo.',
    0, @admin_id, 'ORQO-API-002', 'ORQO-API-002',
    'Arquitectura', 'Service', 0, 36000000
),
(
    '22222222-2222-4222-8222-000000000003',
    'Implementacion de Agentes IA Empresariales',
    @now, @now, @admin_id, @admin_id,
    'Agentes con RAG, herramientas internas, trazabilidad de prompts, evaluaciones, guardrails y despliegue seguro.',
    0, @admin_id, 'ORQO-AI-003', 'ORQO-AI-003',
    'Inteligencia Artificial', 'Service', 0, 45000000
),
(
    '22222222-2222-4222-8222-000000000004',
    'SRE y Observabilidad para Plataformas Criticas',
    @now, @now, @admin_id, @admin_id,
    'SLI/SLO, alertamiento accionable, dashboards, runbooks, analisis de incidentes y hardening de confiabilidad.',
    0, @admin_id, 'ORQO-SRE-004', 'ORQO-SRE-004',
    'Confiabilidad', 'Service', 0, 32000000
),
(
    '22222222-2222-4222-8222-000000000005',
    'Modernizacion Legacy hacia Cloud Native',
    @now, @now, @admin_id, @admin_id,
    'Estrategia incremental para migrar aplicaciones legacy a contenedores, eventos, APIs y despliegue automatizado.',
    0, @admin_id, 'ORQO-MOD-005', 'ORQO-MOD-005',
    'Modernizacion', 'Service', 0, 52000000
)
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    date_modified = VALUES(date_modified),
    description = VALUES(description),
    maincode = VALUES(maincode),
    price = VALUES(price);

INSERT INTO cases (
    id, name, date_entered, date_modified, modified_user_id, created_by,
    description, deleted, assigned_user_id, account_id, type, status,
    priority, resolution
) VALUES
(
    '33333333-3333-4333-8333-000000000001',
    'PQRS - Latencia critica en autenticacion transaccional',
    @now, @now, @admin_id, @admin_id,
    'Cliente reporta incremento de latencia p95 sobre 4s en autenticacion OAuth2 durante pico transaccional. Requiere revision de trazas distribuidas, pools de conexion y cache de tokens.',
    0, @admin_id, '11111111-1111-4111-8111-000000000001',
    'Question', 'New', 'High', NULL
),
(
    '33333333-3333-4333-8333-000000000002',
    'PQRS - Inconsistencia en sincronizacion de estados de orden',
    @now, @now, @admin_id, @admin_id,
    'Integracion entre CRM, bus de eventos y plataforma BSS presenta eventos duplicados y ordenes en estado divergente. Se solicita analisis de idempotencia y reconciliacion.',
    0, @admin_id, '11111111-1111-4111-8111-000000000004',
    'Problem', 'Assigned', 'High', NULL
),
(
    '33333333-3333-4333-8333-000000000003',
    'PQRS - Solicitud de dashboard SLO para canal digital',
    @now, @now, @admin_id, @admin_id,
    'Equipo de operaciones solicita dashlet ejecutivo con disponibilidad, tasa de error, tiempo medio de respuesta y backlog PQRS por severidad.',
    0, @admin_id, '11111111-1111-4111-8111-000000000005',
    'Feature', 'New', 'Medium', NULL
)
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    date_modified = VALUES(date_modified),
    description = VALUES(description),
    status = VALUES(status),
    priority = VALUES(priority),
    account_id = VALUES(account_id);
