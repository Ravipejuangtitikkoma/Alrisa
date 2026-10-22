<?php
/**
 * REST API Endpoint: /api/settings.php
 * Meneruskan request ke ../settings.php?api=1
 */
$_GET['api'] = '1';
require_once __DIR__ . '/../settings.php';
