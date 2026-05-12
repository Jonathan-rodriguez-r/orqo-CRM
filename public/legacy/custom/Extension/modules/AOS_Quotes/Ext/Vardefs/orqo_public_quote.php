<?php
/**
 * Orqo CRM — Campos para cotización pública.
 * orqo_public_token_c : token único que identifica la URL pública.
 * orqo_public_url_c   : URL pública completa (calculada al publicar).
 */
$dictionary['AOS_Quotes']['fields']['orqo_public_token_c'] = [
    'name'            => 'orqo_public_token_c',
    'vname'           => 'LBL_ORQO_PUBLIC_TOKEN',
    'type'            => 'varchar',
    'len'             => 64,
    'required'        => false,
    'reportable'      => false,
    'importable'      => false,
    'duplicate_merge' => 'disabled',
    'comment'         => 'Token único para URL pública de la cotización',
];

$dictionary['AOS_Quotes']['fields']['orqo_public_url_c'] = [
    'name'            => 'orqo_public_url_c',
    'vname'           => 'LBL_ORQO_PUBLIC_URL',
    'type'            => 'varchar',
    'len'             => 512,
    'required'        => false,
    'reportable'      => false,
    'importable'      => false,
    'duplicate_merge' => 'disabled',
    'comment'         => 'URL pública de la cotización para compartir con el cliente',
];
