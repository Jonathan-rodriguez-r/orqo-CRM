<?php
/**
 * Orqo CRM — Inyecta el campo logo en EditView y DetailView de Cuentas.
 * El campo se agrega al primer panel de la vista.
 */

// DetailView
$viewdefs['Accounts']['DetailView']['panels'][0][] = [
    ['name' => 'orqo_logo_c', 'label' => 'LBL_ORQO_LOGO'],
    ['name' => '', 'label' => ''],
];

// EditView
$viewdefs['Accounts']['EditView']['panels'][0][] = [
    ['name' => 'orqo_logo_c', 'label' => 'LBL_ORQO_LOGO'],
    ['name' => '', 'label' => ''],
];
