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
        $lineItems[] = [
            'name'        => $item->name,
            'quantity'    => (float) $item->quantity,
            'unit_price'  => (float) $item->unit_price,
            'total_price' => (float) $item->total_price,
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
