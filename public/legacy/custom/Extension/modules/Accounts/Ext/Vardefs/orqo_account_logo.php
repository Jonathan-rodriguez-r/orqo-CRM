<?php
/**
 * Orqo CRM — Campo logo para cuentas (clientes).
 * Upgrade-safe: vive en custom/Extension, no modifica el core.
 */
$dictionary['Account']['fields']['orqo_logo_c'] = [
    'name'       => 'orqo_logo_c',
    'vname'      => 'LBL_ORQO_LOGO',
    'type'       => 'image',
    'dbType'     => 'varchar',
    'len'        => 255,
    'comment'    => 'Logo del cliente',
    'required'   => false,
    'reportable' => false,
    'importable' => false,
    'duplicate_merge' => 'disabled',
];
