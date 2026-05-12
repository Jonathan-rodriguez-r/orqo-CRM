<?php

if (!defined('sugarEntry') || !sugarEntry) {
    die('Not A Valid Entry Point');
}

class OrqoLoyaltyPointsService
{
    private const POINTS_PER_AMOUNT_UNIT = 0.01;

    public function __construct(
        private DBManager $db,
        private LoggerManager $logger
    ) {
    }

    public function applyPointsToOpportunity(string $opportunityId, float $amount): void
    {
        $points = $this->calculatePoints($amount);
        $quotedId = $this->db->quoted($opportunityId);
        $quotedPoints = (int) $points;

        $sql = "
            INSERT INTO opportunities_cstm (id_c, orqo_loyalty_points_c)
            VALUES ({$quotedId}, {$quotedPoints})
            ON DUPLICATE KEY UPDATE orqo_loyalty_points_c = {$quotedPoints}
        ";

        $this->db->query($sql, true);
        $this->logger->info("Orqo CRM loyalty points applied to Opportunity {$opportunityId}: {$points}");
    }

    public function calculatePoints(float $amount): int
    {
        return (int) floor($amount * self::POINTS_PER_AMOUNT_UNIT);
    }
}
