<?php

if (!defined('sugarEntry') || !sugarEntry) {
    die('Not A Valid Entry Point');
}

require_once 'custom/modules/Opportunities/services/OrqoLoyaltyPointsService.php';

class OrqoLoyaltyAfterSave
{
    /**
     * @var array<string, bool>
     */
    private static array $processed = [];

    public function afterSave($bean, $event, $arguments): void
    {
        if (empty($bean->id) || !empty($bean->deleted)) {
            return;
        }

        if (($bean->sales_stage ?? '') !== 'Closed Won') {
            return;
        }

        if (!empty(self::$processed[$bean->id])) {
            return;
        }

        self::$processed[$bean->id] = true;

        $service = new OrqoLoyaltyPointsService($GLOBALS['db'], $GLOBALS['log']);
        $service->applyPointsToOpportunity(
            (string) $bean->id,
            $this->resolveOpportunityAmount($bean)
        );
    }

    private function resolveOpportunityAmount($bean): float
    {
        $amount = $bean->amount_usdollar ?? $bean->amount ?? 0;

        if (is_string($amount)) {
            $amount = preg_replace('/[^0-9.-]/', '', $amount);
        }

        return max(0.0, (float) $amount);
    }
}
