<?php
/**
 * Orqo CRM — Controlador custom para AOS_Quotes.
 * Agrega la acción OrqoPublish: genera un token único y persiste la URL pública.
 */
if (!defined('sugarEntry') || !sugarEntry) { die('Not A Valid Entry Point'); }

require_once('include/MVC/Controller/SugarController.php');

class AOS_QuotesController extends SugarController
{
    /**
     * action_OrqoPublish
     *
     * Genera (o regenera) el token público de la cotización y redirige
     * de vuelta al DetailView mostrando la URL para compartir.
     */
    public function action_OrqoPublish()
    {
        $record = isset($_REQUEST['record']) ? trim($_REQUEST['record']) : '';
        if (empty($record)) {
            sugar_cleanup();
            exit('Cotización no especificada.');
        }

        /** @var AOS_Quotes $quote */
        $quote = BeanFactory::getBean('AOS_Quotes', $record);
        if (empty($quote->id)) {
            sugar_cleanup();
            exit('Cotización no encontrada.');
        }

        // Generar token seguro de 32 bytes en hex (64 caracteres)
        $token = bin2hex(random_bytes(32));

        // Construir URL base desde config o variable de entorno
        $siteUrl = rtrim(
            !empty($GLOBALS['sugar_config']['site_url'])
                ? $GLOBALS['sugar_config']['site_url']
                : (getenv('SITE_URL') ?: ''),
            '/'
        );
        $publicUrl = $siteUrl . '/legacy/index.php?entryPoint=OrqoPublicQuote&q=' . $token;

        // Persistir en la tabla _cstm usando DB directamente para evitar
        // que save() de AOS_Quotes dispare hooks innecesarios
        $db = DBManagerFactory::getInstance();
        $quoteId = $db->quote($quote->id);
        $tokenQ  = $db->quote($token);
        $urlQ    = $db->quote($publicUrl);

        $exists = $db->fetchOne(
            "SELECT id FROM aos_quotes_cstm WHERE id_c = '{$quoteId}' LIMIT 1"
        );

        if ($exists) {
            $db->query(
                "UPDATE aos_quotes_cstm
                    SET orqo_public_token_c = '{$tokenQ}',
                        orqo_public_url_c   = '{$urlQ}'
                  WHERE id_c = '{$quoteId}'"
            );
        } else {
            $db->query(
                "INSERT INTO aos_quotes_cstm (id_c, orqo_public_token_c, orqo_public_url_c)
                 VALUES ('{$quoteId}', '{$tokenQ}', '{$urlQ}')"
            );
        }

        // Redirigir al DetailView con parámetro para mostrar el link
        $redirect = 'index.php?module=AOS_Quotes&action=DetailView'
                  . '&record=' . urlencode($record)
                  . '&orqo_published=1'
                  . '&orqo_url=' . urlencode($publicUrl);

        header('Location: ' . $redirect);
        sugar_cleanup();
        exit;
    }
}
