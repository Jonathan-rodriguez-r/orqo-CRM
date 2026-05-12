<?php

if (!defined('sugarEntry') || !sugarEntry) {
    die('Not A Valid Entry Point');
}

$dictionary['Opportunity']['fields']['orqo_loyalty_points_c'] = [
    'name' => 'orqo_loyalty_points_c',
    'vname' => 'LBL_ORQO_LOYALTY_POINTS',
    'type' => 'int',
    'len' => '11',
    'default' => '0',
    'audited' => true,
    'massupdate' => false,
    'reportable' => true,
    'duplicate_merge' => 'disabled',
    'comment' => 'Orqo CRM loyalty points calculated from Closed Won opportunity amount.',
];
