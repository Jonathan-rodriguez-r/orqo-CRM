<?php

if (!defined('sugarEntry') || !sugarEntry) {
    die('Not A Valid Entry Point');
}

$hook_array['after_save'][] = [
    100,
    'Orqo CRM - calculate loyalty points when an Opportunity is Closed Won',
    'custom/modules/Opportunities/OrqoLoyaltyAfterSave.php',
    'OrqoLoyaltyAfterSave',
    'afterSave',
];
