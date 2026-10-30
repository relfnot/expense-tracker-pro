<?php
// backend/router.php

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

// Allow standard file requests if they exist
if (file_exists(__DIR__ . $uri) && !is_dir(__DIR__ . $uri)) {
    return false;
}

// Route match for /expenses or /expenses/123
if (preg_match('#^/expenses(?:/([0-9]+))?$#', $uri, $matches)) {
    if (isset($matches[1])) {
        $_GET['id'] = $matches[1];
    }
    require __DIR__ . '/expenses.php';
    exit;
}

http_response_code(404);
echo json_encode(['error' => 'Not Found']);
