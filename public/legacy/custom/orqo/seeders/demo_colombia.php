<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    fwrite(STDERR, "This seeder must be executed from CLI.\n");
    exit(1);
}

if (!defined('sugarEntry')) {
    define('sugarEntry', true);
}

$legacyRoot = realpath(__DIR__ . '/../../..');

if ($legacyRoot === false || !is_file($legacyRoot . '/include/entryPoint.php')) {
    fwrite(STDERR, "Unable to locate SuiteCRM legacy entryPoint.php.\n");
    exit(1);
}

chdir($legacyRoot);

require_once $legacyRoot . '/include/entryPoint.php';

global $current_user, $db;

$current_user = BeanFactory::getBean('Users', '1');

if (empty($current_user) || empty($current_user->id)) {
    $admin = BeanFactory::newBean('Users');
    $admin->retrieve_by_string_fields(['user_name' => 'admin']);
    $current_user = $admin;
}

if (empty($current_user) || empty($current_user->id)) {
    fwrite(STDERR, "Unable to resolve an admin user for demo ownership.\n");
    exit(1);
}

$ownerId = $current_user->id;
$summary = [];

function orqo_log(string $message): void
{
    echo '[orqo-demo-seeder] ' . $message . PHP_EOL;
}

function orqo_set_fields(SugarBean $bean, array $fields): void
{
    foreach ($fields as $field => $value) {
        if (isset($bean->field_defs[$field])) {
            $bean->{$field} = $value;
        }
    }
}

function orqo_upsert(string $module, string $lookupField, string $lookupValue, array $fields): SugarBean
{
    $bean = BeanFactory::newBean($module);

    if (!$bean instanceof SugarBean) {
        throw new RuntimeException("Unable to create bean for module {$module}");
    }

    if (isset($bean->field_defs[$lookupField])) {
        $bean->retrieve_by_string_fields([$lookupField => $lookupValue]);
    }

    if (empty($bean->id)) {
        $bean = BeanFactory::newBean($module);
    }

    orqo_set_fields($bean, $fields);
    $bean->save(false);

    return $bean;
}

function orqo_relate(SugarBean $bean, string $link, ?string $relatedId): void
{
    if (empty($relatedId)) {
        return;
    }

    if ($bean->load_relationship($link)) {
        $bean->{$link}->add($relatedId);
    }
}

function orqo_date(int $daysFromToday): string
{
    return gmdate('Y-m-d', strtotime(($daysFromToday >= 0 ? '+' : '') . $daysFromToday . ' days'));
}

function orqo_money(float $amount): string
{
    return number_format($amount, 2, '.', '');
}

function orqo_touch_modified(SugarBean $bean, string $dateTime): void
{
    global $db;

    if (empty($bean->table_name) || empty($bean->id)) {
        return;
    }

    $db->query(
        'UPDATE ' . $bean->table_name .
        " SET date_modified = '" . $db->quote($dateTime) . "'" .
        " WHERE id = '" . $db->quote($bean->id) . "'"
    );
}

$accountsData = [
    'bancolombia' => [
        'name' => 'Bancolombia S.A.',
        'description' => 'NIT 890903938-8. Banco colombiano con foco en modernizacion de canales digitales, analitica de riesgo y automatizacion de experiencia cliente.',
        'account_type' => 'Customer',
        'industry' => 'Banking',
        'phone_office' => '+57 604 510 9000',
        'billing_address_city' => 'Medellin',
        'billing_address_country' => 'Colombia',
        'website' => 'https://www.bancolombia.com',
    ],
    'bogota' => [
        'name' => 'Banco de Bogota S.A.',
        'description' => 'NIT 860002964-4. Entidad financiera con necesidades de integracion core, gobierno API y trazabilidad operacional.',
        'account_type' => 'Customer',
        'industry' => 'Banking',
        'phone_office' => '+57 601 382 0000',
        'billing_address_city' => 'Bogota',
        'billing_address_country' => 'Colombia',
        'website' => 'https://www.bancodebogota.com',
    ],
    'davivienda' => [
        'name' => 'Banco Davivienda S.A.',
        'description' => 'NIT 860034313-7. Banco con ecosistemas transaccionales de alta disponibilidad y oportunidades de IA aplicada a servicio.',
        'account_type' => 'Customer',
        'industry' => 'Banking',
        'phone_office' => '+57 601 338 3838',
        'billing_address_city' => 'Bogota',
        'billing_address_country' => 'Colombia',
        'website' => 'https://www.davivienda.com',
    ],
    'claro' => [
        'name' => 'Claro Colombia - Comcel S.A.',
        'description' => 'NIT 800153993-7. Operador telco con foco demo en observabilidad, PQRS masivo e integracion omnicanal.',
        'account_type' => 'Customer',
        'industry' => 'Telecommunications',
        'phone_office' => '+57 601 742 9797',
        'billing_address_city' => 'Bogota',
        'billing_address_country' => 'Colombia',
        'website' => 'https://www.claro.com.co',
    ],
    'movistar' => [
        'name' => 'Movistar Colombia - Colombia Telecomunicaciones S.A. ESP BIC',
        'description' => 'NIT 830122566-1. Operador telco con foco demo en arquitectura de integracion, automatizacion PQRS y calidad de servicio.',
        'account_type' => 'Customer',
        'industry' => 'Telecommunications',
        'phone_office' => '+57 601 705 0000',
        'billing_address_city' => 'Bogota',
        'billing_address_country' => 'Colombia',
        'website' => 'https://www.movistar.co',
    ],
];

$accounts = [];

foreach ($accountsData as $key => $fields) {
    $fields['assigned_user_id'] = $ownerId;
    $accounts[$key] = orqo_upsert('Accounts', 'name', $fields['name'], $fields);
}

$summary['accounts'] = count($accounts);

$contactsData = [
    ['account' => 'bancolombia', 'first_name' => 'Laura', 'last_name' => 'Restrepo', 'title' => 'Directora de Arquitectura Empresarial', 'department' => 'Tecnologia', 'phone_work' => '+57 604 510 9010', 'email1' => 'laura.restrepo.demo@bancolombia.example'],
    ['account' => 'bogota', 'first_name' => 'Andres', 'last_name' => 'Cortes', 'title' => 'Gerente de Integracion Core', 'department' => 'Arquitectura', 'phone_work' => '+57 601 382 0042', 'email1' => 'andres.cortes.demo@bancodebogota.example'],
    ['account' => 'davivienda', 'first_name' => 'Camila', 'last_name' => 'Rojas', 'title' => 'Lider IA y Canales Digitales', 'department' => 'Innovacion', 'phone_work' => '+57 601 338 3841', 'email1' => 'camila.rojas.demo@davivienda.example'],
    ['account' => 'claro', 'first_name' => 'Felipe', 'last_name' => 'Arango', 'title' => 'Jefe de Operaciones BSS', 'department' => 'Operaciones TI', 'phone_work' => '+57 601 742 9733', 'email1' => 'felipe.arango.demo@claro.example'],
    ['account' => 'movistar', 'first_name' => 'Natalia', 'last_name' => 'Mejia', 'title' => 'Responsable PQRS Digital', 'department' => 'Experiencia Cliente', 'phone_work' => '+57 601 705 0198', 'email1' => 'natalia.mejia.demo@movistar.example'],
];

$contacts = [];

foreach ($contactsData as $contact) {
    $account = $accounts[$contact['account']];
    unset($contact['account']);
    $contact['account_id'] = $account->id;
    $contact['account_name'] = $account->name;
    $contact['assigned_user_id'] = $ownerId;
    $bean = orqo_upsert('Contacts', 'last_name', $contact['last_name'], $contact);
    orqo_relate($account, 'contacts', $bean->id);
    $contacts[] = $bean;
}

$summary['contacts'] = count($contacts);

$productsData = [
    ['name' => 'Assessment de Arquitectura Empresarial', 'maincode' => 'ORQO-AE-001', 'part_number' => 'ORQO-AE-001', 'category' => 'Consultoria', 'type' => 'Service', 'price' => '28000000.00', 'description' => 'Diagnostico de arquitectura, riesgos tecnicos, mapa de capacidades, roadmap de modernizacion y recomendaciones C4/ADR.'],
    ['name' => 'Diseno de Plataforma API y Gobierno', 'maincode' => 'ORQO-API-002', 'part_number' => 'ORQO-API-002', 'category' => 'Arquitectura', 'type' => 'Service', 'price' => '36000000.00', 'description' => 'Estrategia API, OAuth2/OIDC, versionamiento, observabilidad, contrato OpenAPI y politicas de consumo.'],
    ['name' => 'Implementacion de Agentes IA Empresariales', 'maincode' => 'ORQO-AI-003', 'part_number' => 'ORQO-AI-003', 'category' => 'Inteligencia Artificial', 'type' => 'Service', 'price' => '45000000.00', 'description' => 'Agentes con RAG, herramientas internas, trazabilidad de prompts, evaluaciones, guardrails y despliegue seguro.'],
    ['name' => 'SRE y Observabilidad para Plataformas Criticas', 'maincode' => 'ORQO-SRE-004', 'part_number' => 'ORQO-SRE-004', 'category' => 'Confiabilidad', 'type' => 'Service', 'price' => '32000000.00', 'description' => 'SLI/SLO, alertamiento accionable, dashboards, runbooks, analisis de incidentes y hardening de confiabilidad.'],
    ['name' => 'Modernizacion Legacy hacia Cloud Native', 'maincode' => 'ORQO-MOD-005', 'part_number' => 'ORQO-MOD-005', 'category' => 'Modernizacion', 'type' => 'Service', 'price' => '52000000.00', 'description' => 'Migracion incremental a contenedores, eventos, APIs y despliegue automatizado.'],
];

$products = [];

foreach ($productsData as $product) {
    $product['assigned_user_id'] = $ownerId;
    $product['cost'] = '0.00';
    $products[] = orqo_upsert('AOS_Products', 'name', $product['name'], $product);
}

$summary['products'] = count($products);

$leadsData = [
    ['first_name' => 'Juliana', 'last_name' => 'Vargas', 'account_name' => 'Nequi Demo Lab', 'title' => 'Product Owner Plataforma', 'status' => 'New', 'lead_source' => 'Web Site', 'phone_work' => '+57 300 100 2001', 'email1' => 'juliana.vargas.demo@nequi.example', 'description' => 'Lead interesado en automatizar PQRS y trazabilidad de reclamos financieros con IA.'],
    ['first_name' => 'Santiago', 'last_name' => 'Leon', 'account_name' => 'ETB Demo Enterprise', 'title' => 'Director Transformacion Digital', 'status' => 'Assigned', 'lead_source' => 'Campaign', 'phone_work' => '+57 300 100 2002', 'email1' => 'santiago.leon.demo@etb.example', 'description' => 'Lead para modernizacion de integraciones legacy y gobierno API.'],
    ['first_name' => 'Paula', 'last_name' => 'Hernandez', 'account_name' => 'Banco Popular Demo', 'title' => 'Gerente de Canales', 'status' => 'In Process', 'lead_source' => 'Conference', 'phone_work' => '+57 300 100 2003', 'email1' => 'paula.hernandez.demo@bancopopular.example', 'description' => 'Interes en agentes IA para atencion interna y soporte a asesores.'],
    ['first_name' => 'Martin', 'last_name' => 'Salazar', 'account_name' => 'Tigo Demo Colombia', 'title' => 'Arquitecto Soluciones', 'status' => 'New', 'lead_source' => 'Partner', 'phone_work' => '+57 300 100 2004', 'email1' => 'martin.salazar.demo@tigo.example', 'description' => 'Explora observabilidad SRE para plataforma de activaciones y ordenes.'],
];

$leads = [];

foreach ($leadsData as $lead) {
    $lead['assigned_user_id'] = $ownerId;
    $leads[] = orqo_upsert('Leads', 'last_name', $lead['last_name'], $lead);
}

$summary['leads'] = count($leads);

$opportunitiesData = [
    ['key' => 'bancolombia_api', 'account' => 'bancolombia', 'name' => 'Gobierno API y trazabilidad OAuth2 Bancolombia', 'amount' => 185000000, 'sales_stage' => 'Proposal/Price Quote', 'probability' => '65', 'date_closed' => orqo_date(28), 'lead_source' => 'Web Site', 'opportunity_type' => 'Existing Business', 'next_step' => 'Validar alcance de integraciones core y seguridad tokenizada.', 'description' => 'Propuesta para gobierno API, trazabilidad distribuida, hardening OAuth2 y dashboard ejecutivo de consumo.'],
    ['key' => 'davivienda_ai', 'account' => 'davivienda', 'name' => 'Agentes IA para servicio digital Davivienda', 'amount' => 240000000, 'sales_stage' => 'Negotiation/Review', 'probability' => '80', 'date_closed' => orqo_date(18), 'lead_source' => 'Conference', 'opportunity_type' => 'New Business', 'next_step' => 'Revisar riesgos de datos sensibles y alcance RAG.', 'description' => 'Implementacion de agentes IA con RAG, evaluaciones, guardrails y auditoria de respuestas.'],
    ['key' => 'claro_sre', 'account' => 'claro', 'name' => 'SRE para plataforma BSS y ordenes Claro', 'amount' => 165000000, 'sales_stage' => 'Qualification', 'probability' => '35', 'date_closed' => orqo_date(45), 'lead_source' => 'Partner', 'opportunity_type' => 'Existing Business', 'next_step' => 'Levantamiento de SLI/SLO y fuentes de logs.', 'description' => 'Definicion de observabilidad, runbooks, alertas accionables y postmortems para flujos BSS.'],
    ['key' => 'movistar_pqrs', 'account' => 'movistar', 'name' => 'Automatizacion PQRS omnicanal Movistar', 'amount' => 138000000, 'sales_stage' => 'Closed Won', 'probability' => '100', 'date_closed' => orqo_date(-4), 'lead_source' => 'Campaign', 'opportunity_type' => 'New Business', 'next_step' => 'Kickoff tecnico y matriz de escalamiento.', 'description' => 'Flujo PQRS con clasificacion, SLA, asignacion automatica y tableros para experiencia cliente.'],
    ['key' => 'bogota_modernizacion', 'account' => 'bogota', 'name' => 'Modernizacion legacy Banco de Bogota', 'amount' => 310000000, 'sales_stage' => 'Needs Analysis', 'probability' => '45', 'date_closed' => orqo_date(60), 'lead_source' => 'Cold Call', 'opportunity_type' => 'New Business', 'next_step' => 'Mapear dependencias batch y contratos de integracion.', 'description' => 'Roadmap incremental para migracion legacy hacia arquitectura cloud native orientada a eventos.'],
];

$opportunities = [];
$opportunityAccounts = [];

foreach ($opportunitiesData as $opportunity) {
    $key = $opportunity['key'];
    $account = $accounts[$opportunity['account']];
    unset($opportunity['key'], $opportunity['account']);
    $opportunity['account_id'] = $account->id;
    $opportunity['account_name'] = $account->name;
    $opportunity['assigned_user_id'] = $ownerId;
    $opportunity['amount'] = orqo_money((float) $opportunity['amount']);
    $opportunity['amount_usdollar'] = $opportunity['amount'];
    $bean = orqo_upsert('Opportunities', 'name', $opportunity['name'], $opportunity);
    orqo_relate($account, 'opportunities', $bean->id);
    $opportunities[$key] = $bean;
    $opportunityAccounts[$key] = $account;
}

$summary['opportunities'] = count($opportunities);

$quotesData = [
    ['opportunity' => 'bancolombia_api', 'name' => 'PRE-ORQO-001 Gobierno API Bancolombia', 'stage' => 'Delivered', 'expiration' => orqo_date(20), 'total_amount' => 185000000, 'description' => 'Cotizacion para gobierno API, arquitectura de seguridad y trazabilidad distribuida.'],
    ['opportunity' => 'davivienda_ai', 'name' => 'PRE-ORQO-002 Agentes IA Davivienda', 'stage' => 'Negotiation', 'expiration' => orqo_date(15), 'total_amount' => 240000000, 'description' => 'Cotizacion para diseno e implementacion de agentes IA empresariales.'],
    ['opportunity' => 'movistar_pqrs', 'name' => 'PRE-ORQO-003 Automatizacion PQRS Movistar', 'stage' => 'Closed Accepted', 'expiration' => orqo_date(10), 'total_amount' => 138000000, 'description' => 'Cotizacion aceptada para automatizacion PQRS y tablero ejecutivo.'],
    ['opportunity' => 'claro_sre', 'name' => 'PRE-ORQO-004 SRE Claro BSS', 'stage' => 'Draft', 'expiration' => orqo_date(30), 'total_amount' => 165000000, 'description' => 'Borrador de cotizacion para observabilidad SRE y runbooks.'],
];

$quotes = [];

foreach ($quotesData as $quote) {
    $opportunityKey = $quote['opportunity'];
    $opportunity = $opportunities[$opportunityKey];
    $account = $opportunityAccounts[$opportunityKey];
    unset($quote['opportunity']);
    $amount = orqo_money((float) $quote['total_amount']);
    $quote['assigned_user_id'] = $ownerId;
    $quote['opportunity_id'] = $opportunity->id;
    $quote['billing_account_id'] = $account->id ?? null;
    $quote['billing_address_city'] = $account->billing_address_city ?? 'Bogota';
    $quote['billing_address_country'] = 'Colombia';
    $quote['shipping_address_city'] = $quote['billing_address_city'];
    $quote['shipping_address_country'] = 'Colombia';
    $quote['total_amt'] = $amount;
    $quote['subtotal_amount'] = $amount;
    $quote['total_amount'] = $amount;
    $quote['total_amt_usdollar'] = $amount;
    $quote['subtotal_amount_usdollar'] = $amount;
    $quote['total_amount_usdollar'] = $amount;
    $quotes[] = orqo_upsert('AOS_Quotes', 'name', $quote['name'], $quote);
}

$summary['quotes'] = count($quotes);

$casesData = [
    ['account' => 'bancolombia', 'name' => 'PQRS Alta - Latencia critica en autenticacion transaccional', 'type' => 'Problem', 'status' => 'Assigned', 'priority' => 'High', 'age_hours' => 3, 'description' => 'Cliente reporta incremento de latencia p95 sobre 4s en autenticacion OAuth2 durante pico transaccional. Requiere revision de trazas distribuidas, pools de conexion y cache de tokens.'],
    ['account' => 'claro', 'name' => 'PQRS Alta - Ordenes duplicadas en integracion BSS', 'type' => 'Problem', 'status' => 'Assigned', 'priority' => 'High', 'age_hours' => 4, 'description' => 'Integracion entre CRM, bus de eventos y plataforma BSS presenta eventos duplicados y ordenes en estado divergente. Requiere analisis de idempotencia y reconciliacion.'],
    ['account' => 'movistar', 'name' => 'PQRS Media - Dashboard SLO para canal digital', 'type' => 'Feature', 'status' => 'New', 'priority' => 'Medium', 'age_hours' => 1, 'description' => 'Equipo de operaciones solicita dashlet ejecutivo con disponibilidad, tasa de error, tiempo medio de respuesta y backlog PQRS por severidad.'],
    ['account' => 'davivienda', 'name' => 'PQRS Alta - Validacion de respuestas IA sensibles', 'type' => 'Question', 'status' => 'New', 'priority' => 'High', 'age_hours' => 2, 'description' => 'Gobierno de riesgo solicita trazabilidad de prompts, fuentes RAG y evaluaciones para respuestas generadas por IA en canales digitales.'],
    ['account' => 'bogota', 'name' => 'PQRS Baja - Ajuste de catalogo de servicios API', 'type' => 'Question', 'status' => 'New', 'priority' => 'Low', 'age_hours' => 0, 'description' => 'Solicitud de actualizacion menor del catalogo de APIs expuestas para consumo interno y documentacion OpenAPI.'],
];

$cases = [];

foreach ($casesData as $case) {
    $account = $accounts[$case['account']];
    $ageHours = (int) $case['age_hours'];
    unset($case['account'], $case['age_hours']);
    $case['account_id'] = $account->id;
    $case['assigned_user_id'] = $ownerId;
    $bean = orqo_upsert('Cases', 'name', $case['name'], $case);
    orqo_relate($account, 'cases', $bean->id);

    if ($ageHours > 0) {
        orqo_touch_modified($bean, gmdate('Y-m-d H:i:s', strtotime("-{$ageHours} hours")));
    }

    $cases[] = $bean;
}

$summary['cases'] = count($cases);

orqo_log('Demo Colombia seed completed.');

foreach ($summary as $module => $count) {
    orqo_log(str_pad($module, 16) . $count);
}

orqo_log('Suggested demo path: Lead -> Account/Contact -> Opportunity -> Quote -> PQRS escalation -> Closed Won loyalty points.');
