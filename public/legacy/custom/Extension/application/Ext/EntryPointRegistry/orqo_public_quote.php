<?php
/**
 * Orqo CRM — Entry point público para cotizaciones.
 * Accesible sin autenticación: cualquier cliente con el link puede ver la cotización.
 * URL: /legacy/index.php?entryPoint=OrqoPublicQuote&q=TOKEN
 */
$entry_point_registry['OrqoPublicQuote'] = [
    'file' => 'custom/OrqoPublicQuoteEntryPoint.php',
    'auth' => false,
];
