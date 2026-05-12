-- Orqo CRM Colombia demo seed.
-- Idempotent fallback seed for Railway. Keep secrets out of this file.

SET @admin_id = '1';
SET @now = UTC_TIMESTAMP();

INSERT INTO accounts (
  id, name, date_entered, date_modified, modified_user_id, created_by,
  description, deleted, assigned_user_id, account_type, industry,
  phone_office, billing_address_city, billing_address_country, website
) VALUES
('orqoacct-0001-4000-8000-000000000001', 'Bancolombia S.A.', @now, @now, @admin_id, @admin_id, 'NIT 890903938-8. Banco colombiano con foco en modernizacion de canales digitales, analitica de riesgo y automatizacion de experiencia cliente.', 0, @admin_id, 'Customer', 'Banking', '+57 604 510 9000', 'Medellin', 'Colombia', 'https://www.bancolombia.com'),
('orqoacct-0001-4000-8000-000000000002', 'Banco de Bogota S.A.', @now, @now, @admin_id, @admin_id, 'NIT 860002964-4. Entidad financiera con necesidades de integracion core, gobierno API y trazabilidad operacional.', 0, @admin_id, 'Customer', 'Banking', '+57 601 382 0000', 'Bogota', 'Colombia', 'https://www.bancodebogota.com'),
('orqoacct-0001-4000-8000-000000000003', 'Banco Davivienda S.A.', @now, @now, @admin_id, @admin_id, 'NIT 860034313-7. Banco con ecosistemas transaccionales de alta disponibilidad y oportunidades de IA aplicada a servicio.', 0, @admin_id, 'Customer', 'Banking', '+57 601 338 3838', 'Bogota', 'Colombia', 'https://www.davivienda.com'),
('orqoacct-0001-4000-8000-000000000004', 'Claro Colombia - Comcel S.A.', @now, @now, @admin_id, @admin_id, 'NIT 800153993-7. Operador telco con foco demo en observabilidad, PQRS masivo e integracion omnicanal.', 0, @admin_id, 'Customer', 'Telecommunications', '+57 601 742 9797', 'Bogota', 'Colombia', 'https://www.claro.com.co'),
('orqoacct-0001-4000-8000-000000000005', 'Movistar Colombia - Colombia Telecomunicaciones S.A. ESP BIC', @now, @now, @admin_id, @admin_id, 'NIT 830122566-1. Operador telco con foco demo en arquitectura de integracion, automatizacion PQRS y calidad de servicio.', 0, @admin_id, 'Customer', 'Telecommunications', '+57 601 705 0000', 'Bogota', 'Colombia', 'https://www.movistar.co')
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  date_modified = VALUES(date_modified),
  modified_user_id = VALUES(modified_user_id),
  description = VALUES(description),
  assigned_user_id = VALUES(assigned_user_id),
  industry = VALUES(industry),
  phone_office = VALUES(phone_office),
  billing_address_city = VALUES(billing_address_city),
  billing_address_country = VALUES(billing_address_country),
  website = VALUES(website),
  deleted = 0;

INSERT INTO contacts (
  id, date_entered, date_modified, modified_user_id, created_by,
  description, deleted, assigned_user_id, first_name, last_name,
  title, department, phone_work, account_id, primary_address_city,
  primary_address_country
) VALUES
('orqocont-0001-4000-8000-000000000001', @now, @now, @admin_id, @admin_id, 'Contacto demo para arquitectura empresarial y canales digitales.', 0, @admin_id, 'Laura', 'Restrepo', 'Directora de Arquitectura Empresarial', 'Tecnologia', '+57 604 510 9010', 'orqoacct-0001-4000-8000-000000000001', 'Medellin', 'Colombia'),
('orqocont-0001-4000-8000-000000000002', @now, @now, @admin_id, @admin_id, 'Contacto demo para integracion core y gobierno API.', 0, @admin_id, 'Andres', 'Cortes', 'Gerente de Integracion Core', 'Arquitectura', '+57 601 382 0042', 'orqoacct-0001-4000-8000-000000000002', 'Bogota', 'Colombia'),
('orqocont-0001-4000-8000-000000000003', @now, @now, @admin_id, @admin_id, 'Contacto demo para IA y canales digitales.', 0, @admin_id, 'Camila', 'Rojas', 'Lider IA y Canales Digitales', 'Innovacion', '+57 601 338 3841', 'orqoacct-0001-4000-8000-000000000003', 'Bogota', 'Colombia'),
('orqocont-0001-4000-8000-000000000004', @now, @now, @admin_id, @admin_id, 'Contacto demo para operaciones BSS.', 0, @admin_id, 'Felipe', 'Arango', 'Jefe de Operaciones BSS', 'Operaciones TI', '+57 601 742 9733', 'orqoacct-0001-4000-8000-000000000004', 'Bogota', 'Colombia'),
('orqocont-0001-4000-8000-000000000005', @now, @now, @admin_id, @admin_id, 'Contacto demo para PQRS digital.', 0, @admin_id, 'Natalia', 'Mejia', 'Responsable PQRS Digital', 'Experiencia Cliente', '+57 601 705 0198', 'orqoacct-0001-4000-8000-000000000005', 'Bogota', 'Colombia')
ON DUPLICATE KEY UPDATE
  date_modified = VALUES(date_modified),
  modified_user_id = VALUES(modified_user_id),
  assigned_user_id = VALUES(assigned_user_id),
  first_name = VALUES(first_name),
  last_name = VALUES(last_name),
  title = VALUES(title),
  department = VALUES(department),
  phone_work = VALUES(phone_work),
  account_id = VALUES(account_id),
  deleted = 0;

INSERT INTO leads (
  id, date_entered, date_modified, modified_user_id, created_by,
  description, deleted, assigned_user_id, first_name, last_name,
  account_name, title, status, lead_source, phone_work
) VALUES
('orqolead-0001-4000-8000-000000000001', @now, @now, @admin_id, @admin_id, 'Lead interesado en automatizar PQRS y trazabilidad de reclamos financieros con IA.', 0, @admin_id, 'Juliana', 'Vargas', 'Nequi Demo Lab', 'Product Owner Plataforma', 'New', 'Web Site', '+57 300 100 2001'),
('orqolead-0001-4000-8000-000000000002', @now, @now, @admin_id, @admin_id, 'Lead para modernizacion de integraciones legacy y gobierno API.', 0, @admin_id, 'Santiago', 'Leon', 'ETB Demo Enterprise', 'Director Transformacion Digital', 'Assigned', 'Campaign', '+57 300 100 2002'),
('orqolead-0001-4000-8000-000000000003', @now, @now, @admin_id, @admin_id, 'Interes en agentes IA para atencion interna y soporte a asesores.', 0, @admin_id, 'Paula', 'Hernandez', 'Banco Popular Demo', 'Gerente de Canales', 'In Process', 'Conference', '+57 300 100 2003'),
('orqolead-0001-4000-8000-000000000004', @now, @now, @admin_id, @admin_id, 'Explora observabilidad SRE para plataforma de activaciones y ordenes.', 0, @admin_id, 'Martin', 'Salazar', 'Tigo Demo Colombia', 'Arquitecto Soluciones', 'New', 'Partner', '+57 300 100 2004')
ON DUPLICATE KEY UPDATE
  date_modified = VALUES(date_modified),
  modified_user_id = VALUES(modified_user_id),
  description = VALUES(description),
  assigned_user_id = VALUES(assigned_user_id),
  status = VALUES(status),
  lead_source = VALUES(lead_source),
  deleted = 0;

INSERT INTO aos_products (
  id, name, date_entered, date_modified, modified_user_id, created_by,
  description, deleted, assigned_user_id, maincode, part_number,
  category, type, cost, price
) VALUES
('orqoprod-0001-4000-8000-000000000001', 'Assessment de Arquitectura Empresarial', @now, @now, @admin_id, @admin_id, 'Diagnostico de arquitectura, riesgos tecnicos, mapa de capacidades, roadmap de modernizacion y recomendaciones C4/ADR.', 0, @admin_id, 'ORQO-AE-001', 'ORQO-AE-001', 'Consultoria', 'Service', 0, 28000000),
('orqoprod-0001-4000-8000-000000000002', 'Diseno de Plataforma API y Gobierno', @now, @now, @admin_id, @admin_id, 'Estrategia API, OAuth2/OIDC, versionamiento, observabilidad, contrato OpenAPI y politicas de consumo.', 0, @admin_id, 'ORQO-API-002', 'ORQO-API-002', 'Arquitectura', 'Service', 0, 36000000),
('orqoprod-0001-4000-8000-000000000003', 'Implementacion de Agentes IA Empresariales', @now, @now, @admin_id, @admin_id, 'Agentes con RAG, herramientas internas, trazabilidad de prompts, evaluaciones, guardrails y despliegue seguro.', 0, @admin_id, 'ORQO-AI-003', 'ORQO-AI-003', 'Inteligencia Artificial', 'Service', 0, 45000000),
('orqoprod-0001-4000-8000-000000000004', 'SRE y Observabilidad para Plataformas Criticas', @now, @now, @admin_id, @admin_id, 'SLI/SLO, alertamiento accionable, dashboards, runbooks, analisis de incidentes y hardening de confiabilidad.', 0, @admin_id, 'ORQO-SRE-004', 'ORQO-SRE-004', 'Confiabilidad', 'Service', 0, 32000000),
('orqoprod-0001-4000-8000-000000000005', 'Modernizacion Legacy hacia Cloud Native', @now, @now, @admin_id, @admin_id, 'Migracion incremental a contenedores, eventos, APIs y despliegue automatizado.', 0, @admin_id, 'ORQO-MOD-005', 'ORQO-MOD-005', 'Modernizacion', 'Service', 0, 52000000)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  date_modified = VALUES(date_modified),
  description = VALUES(description),
  maincode = VALUES(maincode),
  part_number = VALUES(part_number),
  price = VALUES(price),
  deleted = 0;

INSERT INTO opportunities (
  id, name, date_entered, date_modified, modified_user_id, created_by,
  description, deleted, assigned_user_id, opportunity_type, lead_source,
  amount, amount_usdollar, currency_id, date_closed, next_step,
  sales_stage, probability
) VALUES
('orqoopp0-0001-4000-8000-000000000001', 'Gobierno API y trazabilidad OAuth2 Bancolombia', @now, @now, @admin_id, @admin_id, 'Propuesta para gobierno API, trazabilidad distribuida, hardening OAuth2 y dashboard ejecutivo de consumo.', 0, @admin_id, 'Existing Business', 'Web Site', 185000000, 185000000, '-99', DATE_ADD(CURDATE(), INTERVAL 28 DAY), 'Validar alcance de integraciones core y seguridad tokenizada.', 'Proposal/Price Quote', 65),
('orqoopp0-0001-4000-8000-000000000002', 'Agentes IA para servicio digital Davivienda', @now, @now, @admin_id, @admin_id, 'Implementacion de agentes IA con RAG, evaluaciones, guardrails y auditoria de respuestas.', 0, @admin_id, 'New Business', 'Conference', 240000000, 240000000, '-99', DATE_ADD(CURDATE(), INTERVAL 18 DAY), 'Revisar riesgos de datos sensibles y alcance RAG.', 'Negotiation/Review', 80),
('orqoopp0-0001-4000-8000-000000000003', 'SRE para plataforma BSS y ordenes Claro', @now, @now, @admin_id, @admin_id, 'Definicion de observabilidad, runbooks, alertas accionables y postmortems para flujos BSS.', 0, @admin_id, 'Existing Business', 'Partner', 165000000, 165000000, '-99', DATE_ADD(CURDATE(), INTERVAL 45 DAY), 'Levantamiento de SLI/SLO y fuentes de logs.', 'Qualification', 35),
('orqoopp0-0001-4000-8000-000000000004', 'Automatizacion PQRS omnicanal Movistar', @now, @now, @admin_id, @admin_id, 'Flujo PQRS con clasificacion, SLA, asignacion automatica y tableros para experiencia cliente.', 0, @admin_id, 'New Business', 'Campaign', 138000000, 138000000, '-99', DATE_SUB(CURDATE(), INTERVAL 4 DAY), 'Kickoff tecnico y matriz de escalamiento.', 'Closed Won', 100),
('orqoopp0-0001-4000-8000-000000000005', 'Modernizacion legacy Banco de Bogota', @now, @now, @admin_id, @admin_id, 'Roadmap incremental para migracion legacy hacia arquitectura cloud native orientada a eventos.', 0, @admin_id, 'New Business', 'Cold Call', 310000000, 310000000, '-99', DATE_ADD(CURDATE(), INTERVAL 60 DAY), 'Mapear dependencias batch y contratos de integracion.', 'Needs Analysis', 45)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  date_modified = VALUES(date_modified),
  modified_user_id = VALUES(modified_user_id),
  description = VALUES(description),
  assigned_user_id = VALUES(assigned_user_id),
  amount = VALUES(amount),
  amount_usdollar = VALUES(amount_usdollar),
  sales_stage = VALUES(sales_stage),
  probability = VALUES(probability),
  deleted = 0;

INSERT INTO accounts_opportunities (id, opportunity_id, account_id, date_modified, deleted) VALUES
('orqorel0-0001-4000-8000-000000000001', 'orqoopp0-0001-4000-8000-000000000001', 'orqoacct-0001-4000-8000-000000000001', @now, 0),
('orqorel0-0001-4000-8000-000000000002', 'orqoopp0-0001-4000-8000-000000000002', 'orqoacct-0001-4000-8000-000000000003', @now, 0),
('orqorel0-0001-4000-8000-000000000003', 'orqoopp0-0001-4000-8000-000000000003', 'orqoacct-0001-4000-8000-000000000004', @now, 0),
('orqorel0-0001-4000-8000-000000000004', 'orqoopp0-0001-4000-8000-000000000004', 'orqoacct-0001-4000-8000-000000000005', @now, 0),
('orqorel0-0001-4000-8000-000000000005', 'orqoopp0-0001-4000-8000-000000000005', 'orqoacct-0001-4000-8000-000000000002', @now, 0)
ON DUPLICATE KEY UPDATE
  opportunity_id = VALUES(opportunity_id),
  account_id = VALUES(account_id),
  date_modified = VALUES(date_modified),
  deleted = 0;

INSERT INTO cases (
  id, name, date_entered, date_modified, modified_user_id, created_by,
  description, deleted, assigned_user_id, account_id, type, status,
  priority, resolution
) VALUES
('orqocase-0001-4000-8000-000000000001', 'PQRS Alta - Latencia critica en autenticacion transaccional', @now, DATE_SUB(@now, INTERVAL 3 HOUR), @admin_id, @admin_id, 'Cliente reporta incremento de latencia p95 sobre 4s en autenticacion OAuth2 durante pico transaccional. Requiere revision de trazas distribuidas, pools de conexion y cache de tokens.', 0, @admin_id, 'orqoacct-0001-4000-8000-000000000001', 'Problem', 'Assigned', 'High', NULL),
('orqocase-0001-4000-8000-000000000002', 'PQRS Alta - Ordenes duplicadas en integracion BSS', @now, DATE_SUB(@now, INTERVAL 4 HOUR), @admin_id, @admin_id, 'Integracion entre CRM, bus de eventos y plataforma BSS presenta eventos duplicados y ordenes en estado divergente. Requiere analisis de idempotencia y reconciliacion.', 0, @admin_id, 'orqoacct-0001-4000-8000-000000000004', 'Problem', 'Assigned', 'High', NULL),
('orqocase-0001-4000-8000-000000000003', 'PQRS Media - Dashboard SLO para canal digital', @now, DATE_SUB(@now, INTERVAL 1 HOUR), @admin_id, @admin_id, 'Equipo de operaciones solicita dashlet ejecutivo con disponibilidad, tasa de error, tiempo medio de respuesta y backlog PQRS por severidad.', 0, @admin_id, 'orqoacct-0001-4000-8000-000000000005', 'Feature', 'New', 'Medium', NULL),
('orqocase-0001-4000-8000-000000000004', 'PQRS Alta - Validacion de respuestas IA sensibles', @now, DATE_SUB(@now, INTERVAL 2 HOUR), @admin_id, @admin_id, 'Gobierno de riesgo solicita trazabilidad de prompts, fuentes RAG y evaluaciones para respuestas generadas por IA en canales digitales.', 0, @admin_id, 'orqoacct-0001-4000-8000-000000000003', 'Question', 'New', 'High', NULL),
('orqocase-0001-4000-8000-000000000005', 'PQRS Baja - Ajuste de catalogo de servicios API', @now, @now, @admin_id, @admin_id, 'Solicitud de actualizacion menor del catalogo de APIs expuestas para consumo interno y documentacion OpenAPI.', 0, @admin_id, 'orqoacct-0001-4000-8000-000000000002', 'Question', 'New', 'Low', NULL)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  date_modified = VALUES(date_modified),
  modified_user_id = VALUES(modified_user_id),
  description = VALUES(description),
  assigned_user_id = VALUES(assigned_user_id),
  account_id = VALUES(account_id),
  status = VALUES(status),
  priority = VALUES(priority),
  deleted = 0;

INSERT INTO aos_quotes (
  id, name, date_entered, date_modified, modified_user_id, created_by,
  description, deleted, assigned_user_id, opportunity_id, billing_account_id,
  billing_address_city, billing_address_country, shipping_address_city,
  shipping_address_country, expiration, stage, total_amt, total_amt_usdollar,
  subtotal_amount, subtotal_amount_usdollar, total_amount, total_amount_usdollar
) VALUES
('orqoquot-0001-4000-8000-000000000001', 'PRE-ORQO-001 Gobierno API Bancolombia', @now, @now, @admin_id, @admin_id, 'Cotizacion para gobierno API, arquitectura de seguridad y trazabilidad distribuida.', 0, @admin_id, 'orqoopp0-0001-4000-8000-000000000001', 'orqoacct-0001-4000-8000-000000000001', 'Medellin', 'Colombia', 'Medellin', 'Colombia', DATE_ADD(CURDATE(), INTERVAL 20 DAY), 'Delivered', 185000000, 185000000, 185000000, 185000000, 185000000, 185000000),
('orqoquot-0001-4000-8000-000000000002', 'PRE-ORQO-002 Agentes IA Davivienda', @now, @now, @admin_id, @admin_id, 'Cotizacion para diseno e implementacion de agentes IA empresariales.', 0, @admin_id, 'orqoopp0-0001-4000-8000-000000000002', 'orqoacct-0001-4000-8000-000000000003', 'Bogota', 'Colombia', 'Bogota', 'Colombia', DATE_ADD(CURDATE(), INTERVAL 15 DAY), 'Negotiation', 240000000, 240000000, 240000000, 240000000, 240000000, 240000000),
('orqoquot-0001-4000-8000-000000000003', 'PRE-ORQO-003 Automatizacion PQRS Movistar', @now, @now, @admin_id, @admin_id, 'Cotizacion aceptada para automatizacion PQRS y tablero ejecutivo.', 0, @admin_id, 'orqoopp0-0001-4000-8000-000000000004', 'orqoacct-0001-4000-8000-000000000005', 'Bogota', 'Colombia', 'Bogota', 'Colombia', DATE_ADD(CURDATE(), INTERVAL 10 DAY), 'Closed Accepted', 138000000, 138000000, 138000000, 138000000, 138000000, 138000000),
('orqoquot-0001-4000-8000-000000000004', 'PRE-ORQO-004 SRE Claro BSS', @now, @now, @admin_id, @admin_id, 'Borrador de cotizacion para observabilidad SRE y runbooks.', 0, @admin_id, 'orqoopp0-0001-4000-8000-000000000003', 'orqoacct-0001-4000-8000-000000000004', 'Bogota', 'Colombia', 'Bogota', 'Colombia', DATE_ADD(CURDATE(), INTERVAL 30 DAY), 'Draft', 165000000, 165000000, 165000000, 165000000, 165000000, 165000000)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  date_modified = VALUES(date_modified),
  modified_user_id = VALUES(modified_user_id),
  description = VALUES(description),
  assigned_user_id = VALUES(assigned_user_id),
  opportunity_id = VALUES(opportunity_id),
  billing_account_id = VALUES(billing_account_id),
  stage = VALUES(stage),
  total_amount = VALUES(total_amount),
  deleted = 0;

SELECT 'accounts' AS module, COUNT(*) AS demo_count FROM accounts WHERE id LIKE 'orqoacct-%'
UNION ALL SELECT 'contacts', COUNT(*) FROM contacts WHERE id LIKE 'orqocont-%'
UNION ALL SELECT 'leads', COUNT(*) FROM leads WHERE id LIKE 'orqolead-%'
UNION ALL SELECT 'opportunities', COUNT(*) FROM opportunities WHERE id LIKE 'orqoopp0-%'
UNION ALL SELECT 'products', COUNT(*) FROM aos_products WHERE id LIKE 'orqoprod-%'
UNION ALL SELECT 'quotes', COUNT(*) FROM aos_quotes WHERE id LIKE 'orqoquot-%'
UNION ALL SELECT 'cases', COUNT(*) FROM cases WHERE id LIKE 'orqocase-%';
