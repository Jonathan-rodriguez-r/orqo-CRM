<?php
/**
 * Orqo CRM — Vista pública de cotización (sin autenticación).
 * Acceso: /legacy/index.php?entryPoint=OrqoPublicQuote&q=TOKEN
 *
 * Renderiza un HTML completo con los datos de la cotización
 * con branding Orqo, listo para compartir con el cliente.
 */
if (!defined('sugarEntry') || !sugarEntry) { die('Not A Valid Entry Point'); }

// ── 1. Validar token ────────────────────────────────────────────────────────
$token = isset($_GET['q']) ? preg_replace('/[^a-f0-9]/i', '', trim($_GET['q'])) : '';
if (strlen($token) !== 64) {
    http_response_code(400);
    exit('<h2>Enlace inválido.</h2>');
}

// ── 2. Buscar cotización por token ──────────────────────────────────────────
$db     = DBManagerFactory::getInstance();
$tokenQ = $db->quote($token);
$row    = $db->fetchOne(
    "SELECT id_c FROM aos_quotes_cstm WHERE orqo_public_token_c = '{$tokenQ}' LIMIT 1"
);

if (empty($row['id_c'])) {
    http_response_code(404);
    exit('<h2>Cotización no encontrada o enlace expirado.</h2>');
}

// ── 3. Cargar bean ──────────────────────────────────────────────────────────
/** @var AOS_Quotes $quote */
$quote = BeanFactory::getBean('AOS_Quotes', $row['id_c']);
if (empty($quote->id) || $quote->deleted) {
    http_response_code(404);
    exit('<h2>Cotización no disponible.</h2>');
}

// ── 4. Cargar cuenta (para logo del cliente) ────────────────────────────────
$accountLogoHtml = '';
if (!empty($quote->billing_account_id)) {
    $account = BeanFactory::getBean('Accounts', $quote->billing_account_id);
    if (!empty($account->orqo_logo_c)) {
        $logoPath = rtrim(sugar_cached('upload://') ?: 'upload/', '/') . '/' . $account->orqo_logo_c;
        // SuiteCRM almacena imágenes en upload/ con el ID del bean como nombre
        $uploadPath = 'upload/' . $account->orqo_logo_c;
        if (file_exists($uploadPath)) {
            $mime = mime_content_type($uploadPath) ?: 'image/png';
            $b64  = base64_encode(file_get_contents($uploadPath));
            $accountLogoHtml = '<img src="data:' . htmlspecialchars($mime) . ';base64,' . $b64
                             . '" alt="' . htmlspecialchars($account->name) . '"'
                             . ' style="max-height:56px;max-width:180px;height:auto;width:auto;object-fit:contain;">';
        }
    }
}

// ── 5. Cargar líneas de producto ────────────────────────────────────────────
$quote->load_relationship('aos_products_quotes');
$lineItems = [];
if (!empty($quote->aos_products_quotes)) {
    $quote->aos_products_quotes->fetch();
    foreach ($quote->aos_products_quotes->getBeans() as $item) {
        $quantity = $item->product_qty ?? $item->quantity ?? 0;
        $unitPrice = $item->product_unit_price ?? $item->unit_price ?? 0;
        $totalPrice = $item->product_total_price ?? $item->total_price ?? 0;
        $lineItems[] = [
            'name'        => $item->name,
            'part_number' => $item->part_number ?? $item->product_part_number ?? '',
            'description' => $item->description ?? $item->product_description ?? '',
            'quantity'    => (float) $quantity,
            'list_price'  => (float) ($item->product_list_price ?? $item->list_price ?? $unitPrice),
            'discount'    => (float) ($item->product_discount ?? 0),
            'unit_price'  => (float) $unitPrice,
            'vat'         => $item->vat ?? '',
            'total_price' => (float) $totalPrice,
        ];
    }
}

// ── 6. Helpers de formato ────────────────────────────────────────────────────
$currency    = !empty($quote->currency_symbol) ? htmlspecialchars($quote->currency_symbol) : '$';
$formatMoney = function ($v) use ($currency) {
    return $currency . ' ' . number_format((float)$v, 2, ',', '.');
};
$formatDate  = function ($d) {
    if (empty($d)) { return '—'; }
    $ts = strtotime($d);
    return $ts ? date('d/m/Y', $ts) : htmlspecialchars($d);
};

// ── 7. URL base para logo Orqo ───────────────────────────────────────────────
$siteUrl = rtrim(
    !empty($GLOBALS['sugar_config']['site_url']) ? $GLOBALS['sugar_config']['site_url']
        : (getenv('SITE_URL') ?: ''),
    '/'
);
$orqoLogo = $siteUrl . '/legacy/custom/themes/suite8/images/company_logo.png';

function orqo_quote_public_escape($value)
{
    return htmlspecialchars((string) ($value ?? ''), ENT_QUOTES, 'UTF-8');
}

function orqo_quote_public_money($value, $currency)
{
    if ($value === null || $value === '') {
        return '';
    }

    return $currency . ' ' . number_format((float) $value, 2, ',', '.');
}

function orqo_quote_public_pdf_template($db)
{
    try {
        $row = $db->fetchOne(
            "SELECT id, name, description, pdfheader, pdffooter
               FROM aos_pdf_templates
              WHERE deleted = 0
                AND type IN ('AOS_Quotes', 'Quotes')
              ORDER BY date_modified DESC
              LIMIT 1"
        );
    } catch (Throwable $e) {
        return '';
    }

    if (empty($row) || empty($row['description'])) {
        return '';
    }

    return ($row['pdfheader'] ?? '') . $row['description'] . ($row['pdffooter'] ?? '');
}

function orqo_quote_public_replace_product_rows($html, array $lineItems, $currency)
{
    return preg_replace_callback('/<tr\b[^>]*>.*?\$aos_products_quotes_.*?<\/tr>/is', function ($match) use ($lineItems, $currency) {
        if (empty($lineItems)) {
            return '';
        }

        $rows = '';
        foreach ($lineItems as $item) {
            $rows .= strtr($match[0], [
                '$aos_products_quotes_product_qty' => orqo_quote_public_escape($item['quantity']),
                '$aos_products_quotes_name' => orqo_quote_public_escape($item['name']),
                '$aos_products_quotes_part_number' => orqo_quote_public_escape($item['part_number']),
                '$aos_products_description' => orqo_quote_public_escape($item['description']),
                '$aos_products_quotes_product_list_price' => orqo_quote_public_money($item['list_price'], $currency),
                '$aos_products_quotes_product_discount' => orqo_quote_public_money($item['discount'], $currency),
                '$aos_products_quotes_product_unit_price' => orqo_quote_public_money($item['unit_price'], $currency),
                '$aos_products_quotes_vat' => orqo_quote_public_escape($item['vat']),
                '$aos_products_quotes_product_total_price' => orqo_quote_public_money($item['total_price'], $currency),
            ]);
        }

        return $rows;
    }, $html);
}

function orqo_quote_public_render_pdf_template($templateHtml, $quote, array $lineItems, $currency, $orqoLogo)
{
    $templateHtml = orqo_quote_public_replace_product_rows($templateHtml, $lineItems, $currency);
    $templateHtml = preg_replace('/<tr\b[^>]*>.*?\$aos_services_quotes_.*?<\/tr>/is', '', $templateHtml);

    $templateHtml = strtr($templateHtml, [
        '$aos_quotes_name' => orqo_quote_public_escape($quote->name ?? ''),
        '$aos_quotes_number' => orqo_quote_public_escape($quote->number ?? ''),
        '$aos_quotes_date_entered' => orqo_quote_public_escape($quote->date_entered ?? ''),
        '$aos_quotes_expiration' => orqo_quote_public_escape($quote->expiration ?? ''),
        '$aos_quotes_term' => orqo_quote_public_escape($quote->term ?? ''),
        '$aos_quotes_modified_by_name' => orqo_quote_public_escape($quote->modified_by_name ?? $quote->assigned_user_name ?? ''),
        '$aos_quotes_billing_account' => orqo_quote_public_escape($quote->billing_account ?? $quote->billing_account_name ?? ''),
        '$aos_quotes_billing_address_street' => orqo_quote_public_escape($quote->billing_address_street ?? ''),
        '$aos_quotes_billing_address_city' => orqo_quote_public_escape($quote->billing_address_city ?? ''),
        '$aos_quotes_billing_address_state' => orqo_quote_public_escape($quote->billing_address_state ?? ''),
        '$aos_quotes_billing_address_postalcode' => orqo_quote_public_escape($quote->billing_address_postalcode ?? ''),
        '$aos_quotes_billing_address_country' => orqo_quote_public_escape($quote->billing_address_country ?? ''),
        '$total_amt' => orqo_quote_public_money($quote->total_amt ?? '', $currency),
        '$discount_amount' => orqo_quote_public_money($quote->discount_amount ?? '', $currency),
        '$subtotal_amount' => orqo_quote_public_money($quote->subtotal_amount ?? '', $currency),
        '$tax_amount' => orqo_quote_public_money($quote->tax_amount ?? '', $currency),
        '$shipping_amount' => orqo_quote_public_money($quote->shipping_amount ?? '', $currency),
        '$total_amount' => orqo_quote_public_money($quote->total_amount ?? '', $currency),
    ]);

    $safeLogo = orqo_quote_public_escape($orqoLogo);
    $templateHtml = preg_replace(
        '#(?:https://crm\.orqo\.io)?/?(?:legacy/)?custom/themes/suite8/images/company_logo\.png#',
        $safeLogo,
        $templateHtml
    );

    return preg_replace('/\$[a-zA-Z0-9_]+/', '', $templateHtml);
}

$pdfTemplateHtml = orqo_quote_public_pdf_template($db);
if ($pdfTemplateHtml !== '') {
    $renderedTemplate = orqo_quote_public_render_pdf_template($pdfTemplateHtml, $quote, $lineItems, $currency, $orqoLogo);

    header('Content-Type: text/html; charset=UTF-8');
    header('X-Robots-Tag: noindex, nofollow');
    echo '<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8">';
    echo '<meta name="viewport" content="width=device-width, initial-scale=1.0">';
    echo '<title>Cotizacion ' . orqo_quote_public_escape($quote->name ?? '') . ' - Orqo CRM</title>';
    echo '</head><body>' . $renderedTemplate . '</body></html>';
    if (function_exists('sugar_cleanup')) {
        sugar_cleanup();
    }
    exit;
}

// ── 8. Renderizar HTML ───────────────────────────────────────────────────────
header('Content-Type: text/html; charset=UTF-8');
header('X-Robots-Tag: noindex, nofollow');
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Cotización <?= htmlspecialchars($quote->name) ?> — Orqo CRM</title>
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: 'Segoe UI', Arial, sans-serif;
    background: #f5f5f2;
    color: #2e2e2e;
    min-height: 100vh;
  }
  .page {
    max-width: 860px;
    margin: 2rem auto;
    background: #ffffff;
    border-radius: 8px;
    box-shadow: 0 2px 18px rgba(46,64,56,0.10);
    overflow: hidden;
  }
  /* Header */
  .header {
    background: #2E4038;
    padding: 1.6rem 2.4rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 1rem;
  }
  .header img.orqo-logo {
    height: 40px;
    width: auto;
    object-fit: contain;
  }
  .header .client-logo { /* logo del cliente */ }
  .header .quote-ref {
    text-align: right;
    color: #c8ddd4;
    font-size: 0.85rem;
    line-height: 1.6;
  }
  .header .quote-ref strong {
    display: block;
    color: #ffffff;
    font-size: 1.1rem;
    font-weight: 700;
    letter-spacing: 0.02em;
  }
  /* Body */
  .body { padding: 2rem 2.4rem; }
  .section-title {
    font-size: 0.72rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: #1A8A55;
    margin-bottom: 0.5rem;
    border-bottom: 2px solid #e8f5ee;
    padding-bottom: 0.25rem;
  }
  .meta-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
    gap: 1.2rem 2rem;
    margin-bottom: 2rem;
  }
  .meta-item label {
    display: block;
    font-size: 0.75rem;
    color: #7c8a8a;
    margin-bottom: 0.2rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }
  .meta-item span {
    font-size: 0.95rem;
    color: #2E4038;
    font-weight: 500;
  }
  /* Addresses */
  .addresses {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1.5rem;
    margin-bottom: 2rem;
  }
  @media (max-width: 580px) { .addresses { grid-template-columns: 1fr; } }
  .address-box h4 {
    font-size: 0.72rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: #1A8A55;
    margin-bottom: 0.4rem;
  }
  .address-box p {
    font-size: 0.88rem;
    line-height: 1.7;
    color: #3a3a3a;
  }
  /* Line items table */
  .items-section { margin-bottom: 2rem; }
  table.items {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.88rem;
  }
  table.items thead tr {
    background: #2E4038;
    color: #ffffff;
  }
  table.items thead th {
    padding: 0.65rem 0.9rem;
    text-align: left;
    font-weight: 600;
    font-size: 0.78rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }
  table.items thead th.num { text-align: right; }
  table.items tbody tr:nth-child(even) { background: #f7f3ec; }
  table.items tbody td {
    padding: 0.6rem 0.9rem;
    border-bottom: 1px solid #ece8e0;
    vertical-align: top;
  }
  table.items tbody td.num { text-align: right; font-variant-numeric: tabular-nums; }
  /* Totals */
  .totals {
    display: flex;
    justify-content: flex-end;
    margin-bottom: 2rem;
  }
  .totals-box {
    min-width: 280px;
    border: 1px solid #e0e0d8;
    border-radius: 6px;
    overflow: hidden;
  }
  .totals-row {
    display: flex;
    justify-content: space-between;
    padding: 0.5rem 1rem;
    font-size: 0.88rem;
    border-bottom: 1px solid #ece8e0;
  }
  .totals-row:last-child { border-bottom: none; }
  .totals-row.grand {
    background: #2E4038;
    color: #ffffff;
    font-weight: 700;
    font-size: 1rem;
  }
  .totals-row label { color: #7c8a8a; }
  .totals-row.grand label { color: #c8ddd4; }
  /* Description */
  .description-box {
    background: #f7f3ec;
    border-left: 3px solid #1A8A55;
    padding: 1rem 1.2rem;
    border-radius: 0 4px 4px 0;
    font-size: 0.88rem;
    line-height: 1.7;
    margin-bottom: 2rem;
    white-space: pre-wrap;
  }
  /* Footer */
  .footer {
    background: #f7f3ec;
    border-top: 1px solid #e0e0d8;
    padding: 1.2rem 2.4rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 0.5rem;
    font-size: 0.78rem;
    color: #8a8a8a;
  }
  .badge {
    display: inline-block;
    padding: 0.25rem 0.7rem;
    border-radius: 20px;
    font-size: 0.75rem;
    font-weight: 600;
    letter-spacing: 0.03em;
  }
  .badge-draft     { background:#e8f0fe; color:#3c5fc9; }
  .badge-approved  { background:#e8f5ee; color:#1A8A55; }
  .badge-delivered { background:#fff3cd; color:#856404; }
  .badge-closed    { background:#e2e3e5; color:#555; }
</style>
</head>
<body>
<div class="page">

  <!-- ── HEADER ── -->
  <div class="header">
    <div style="display:flex;align-items:center;gap:1.5rem;">
      <img src="<?= htmlspecialchars($orqoLogo) ?>" class="orqo-logo" alt="Orqo CRM">
      <?php if ($accountLogoHtml): ?>
        <div class="client-logo"><?= $accountLogoHtml ?></div>
      <?php endif; ?>
    </div>
    <div class="quote-ref">
      <strong><?= htmlspecialchars($quote->name) ?></strong>
      N.° <?= htmlspecialchars($quote->quote_num ?: $quote->id) ?><br>
      <?php
        $statusLabels = [
          'Draft'     => 'Borrador',
          'Approved'  => 'Aprobada',
          'Delivered' => 'Entregada',
          'Closed'    => 'Cerrada',
        ];
        $statusClass = [
          'Draft'     => 'badge-draft',
          'Approved'  => 'badge-approved',
          'Delivered' => 'badge-delivered',
          'Closed'    => 'badge-closed',
        ];
        $st = $quote->approval_status ?: ($quote->quote_stage ?? '');
        $stLabel = $statusLabels[$st] ?? htmlspecialchars($st ?: '—');
        $stClass = $statusClass[$st] ?? 'badge-draft';
      ?>
      <span class="badge <?= $stClass ?>"><?= $stLabel ?></span>
    </div>
  </div>

  <div class="body">

    <!-- ── META ── -->
    <p class="section-title">Información de la cotización</p>
    <div class="meta-grid">
      <div class="meta-item">
        <label>Fecha de emisión</label>
        <span><?= $formatDate($quote->date_quote_expected_closed ?: $quote->date_entered) ?></span>
      </div>
      <div class="meta-item">
        <label>Válida hasta</label>
        <span><?= $formatDate($quote->date_quote_expected_closed) ?></span>
      </div>
      <div class="meta-item">
        <label>Cliente</label>
        <span><?= htmlspecialchars($quote->billing_account_name ?: '—') ?></span>
      </div>
      <div class="meta-item">
        <label>Contacto</label>
        <span><?= htmlspecialchars(trim(($quote->billing_contact_first_name ?? '') . ' ' . ($quote->billing_contact_last_name ?? '')) ?: '—') ?></span>
      </div>
    </div>

    <!-- ── ADDRESSES ── -->
    <?php
      $billingLines = array_filter([
        $quote->billing_address_street  ?? '',
        trim(($quote->billing_address_city  ?? '') . ' ' . ($quote->billing_address_postalcode ?? '')),
        $quote->billing_address_state   ?? '',
        $quote->billing_address_country ?? '',
      ]);
      $shippingLines = array_filter([
        $quote->shipping_address_street  ?? '',
        trim(($quote->shipping_address_city  ?? '') . ' ' . ($quote->shipping_address_postalcode ?? '')),
        $quote->shipping_address_state   ?? '',
        $quote->shipping_address_country ?? '',
      ]);
      if ($billingLines || $shippingLines):
    ?>
    <div class="addresses">
      <?php if ($billingLines): ?>
      <div class="address-box">
        <h4>Dirección de facturación</h4>
        <p><?= nl2br(htmlspecialchars(implode("\n", $billingLines))) ?></p>
      </div>
      <?php endif; ?>
      <?php if ($shippingLines): ?>
      <div class="address-box">
        <h4>Dirección de envío</h4>
        <p><?= nl2br(htmlspecialchars(implode("\n", $shippingLines))) ?></p>
      </div>
      <?php endif; ?>
    </div>
    <?php endif; ?>

    <!-- ── LINE ITEMS ── -->
    <?php if (!empty($lineItems)): ?>
    <div class="items-section">
      <p class="section-title">Productos / Servicios</p>
      <table class="items">
        <thead>
          <tr>
            <th>Descripción</th>
            <th class="num">Cant.</th>
            <th class="num">Precio unit.</th>
            <th class="num">Total</th>
          </tr>
        </thead>
        <tbody>
          <?php foreach ($lineItems as $item): ?>
          <tr>
            <td><?= htmlspecialchars($item['name']) ?></td>
            <td class="num"><?= number_format($item['quantity'], 2, ',', '.') ?></td>
            <td class="num"><?= $formatMoney($item['unit_price']) ?></td>
            <td class="num"><?= $formatMoney($item['total_price']) ?></td>
          </tr>
          <?php endforeach; ?>
        </tbody>
      </table>
    </div>
    <?php endif; ?>

    <!-- ── TOTALS ── -->
    <div class="totals">
      <div class="totals-box">
        <?php if (!empty($quote->subtotal_amount)): ?>
        <div class="totals-row">
          <label>Subtotal</label>
          <span><?= $formatMoney($quote->subtotal_amount) ?></span>
        </div>
        <?php endif; ?>
        <?php if (!empty($quote->discount_amount) && (float)$quote->discount_amount > 0): ?>
        <div class="totals-row">
          <label>Descuento</label>
          <span>− <?= $formatMoney($quote->discount_amount) ?></span>
        </div>
        <?php endif; ?>
        <?php if (!empty($quote->tax_amount) && (float)$quote->tax_amount > 0): ?>
        <div class="totals-row">
          <label>Impuesto</label>
          <span><?= $formatMoney($quote->tax_amount) ?></span>
        </div>
        <?php endif; ?>
        <?php if (!empty($quote->shipping_amount) && (float)$quote->shipping_amount > 0): ?>
        <div class="totals-row">
          <label>Envío</label>
          <span><?= $formatMoney($quote->shipping_amount) ?></span>
        </div>
        <?php endif; ?>
        <div class="totals-row grand">
          <label>Total</label>
          <span><?= $formatMoney($quote->total_amount) ?></span>
        </div>
      </div>
    </div>

    <!-- ── DESCRIPTION ── -->
    <?php if (!empty(trim($quote->description ?? ''))): ?>
    <p class="section-title">Notas / Términos</p>
    <div class="description-box"><?= htmlspecialchars($quote->description) ?></div>
    <?php endif; ?>

  </div><!-- /.body -->

  <!-- ── FOOTER ── -->
  <div class="footer">
    <span>Generado por Orqo CRM</span>
    <span>Este documento es confidencial y está destinado exclusivamente al destinatario indicado.</span>
  </div>

</div><!-- /.page -->
</body>
</html>
<?php
sugar_cleanup();
exit;
