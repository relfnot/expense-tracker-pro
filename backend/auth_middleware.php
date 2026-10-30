<?php
// backend/auth_middleware.php

define('FIREBASE_PROJECT_ID', 'coffee-35055');

function base64url_decode($data) {
    $remainder = strlen($data) % 4;
    if ($remainder) {
        $padlen = 4 - $remainder;
        $data .= str_repeat('=', $padlen);
    }
    return base64_decode(strtr($data, '-_', '+/'));
}

function get_google_public_keys() {
    $cache_file = __DIR__ . '/certs.json';
    $cache_lifetime = 3600; // 1 hour

    if (file_exists($cache_file) && (time() - filemtime($cache_file) < $cache_lifetime)) {
        $data = json_decode(file_get_contents($cache_file), true);
        if (!empty($data)) {
            return $data;
        }
    }

    // Fetch new keys
    $url = 'https://www.googleapis.com/robot/v1/metadata/x509/securetoken-system@system.gserviceaccount.com';
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
    // Disable SSL verification if there are CA cert issues on Windows
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    
    $response = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($http_code === 200 && !empty($response)) {
        $data = json_decode($response, true);
        if (!empty($data)) {
            file_put_contents($cache_file, json_encode($data));
            return $data;
        }
    }

    // Fallback if cURL fails
    if (file_exists($cache_file)) {
        return json_decode(file_get_contents($cache_file), true);
    }

    return [];
}

function verify_auth_token() {
    // 1. Get Authorization Header
    $auth_header = null;
    if (isset($_SERVER['HTTP_AUTHORIZATION'])) {
        $auth_header = $_SERVER['HTTP_AUTHORIZATION'];
    } elseif (isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
        $auth_header = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'];
    } else {
        $headers = apache_request_headers();
        if (isset($headers['Authorization'])) {
            $auth_header = $headers['Authorization'];
        }
    }

    if (!$auth_header || !preg_match('/Bearer\s(\S+)/i', $auth_header, $matches)) {
        http_response_code(401);
        echo json_encode(['error' => 'Missing or invalid Authorization header']);
        exit;
    }

    $token = $matches[1];

    // 2. Split Token into Parts
    $parts = explode('.', $token);
    if (count($parts) !== 3) {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid token structure']);
        exit;
    }

    list($headb64, $bodyb64, $cryptob64) = $parts;
    
    $header = json_decode(base64url_decode($headb64), true);
    $payload = json_decode(base64url_decode($bodyb64), true);
    $signature = base64url_decode($cryptob64);

    if (!$header || !$payload || !$signature) {
        http_response_code(401);
        echo json_encode(['error' => 'Failed to parse token']);
        exit;
    }

    // 3. Verify Header and Claims
    if ($header['alg'] !== 'RS256' || empty($header['kid'])) {
        http_response_code(401);
        echo json_encode(['error' => 'Unsupported token algorithm or missing kid']);
        exit;
    }

    $now = time();
    $project_id = FIREBASE_PROJECT_ID;

    if ($payload['iss'] !== "https://securetoken.google.com/{$project_id}") {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid token issuer']);
        exit;
    }

    if ($payload['aud'] !== $project_id) {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid token audience']);
        exit;
    }

    if ($payload['exp'] <= $now) {
        http_response_code(401);
        echo json_encode(['error' => 'Token has expired']);
        exit;
    }

    // 4. Verify Signature
    $public_keys = get_google_public_keys();
    $kid = $header['kid'];

    if (!isset($public_keys[$kid])) {
        http_response_code(401);
        echo json_encode(['error' => 'Public key not found for kid']);
        exit;
    }

    $cert_pem = $public_keys[$kid];
    $data_to_verify = "$headb64.$bodyb64";

    $verified = openssl_verify($data_to_verify, $signature, $cert_pem, OPENSSL_ALGO_SHA256);

    if ($verified !== 1) {
        http_response_code(401);
        echo json_encode(['error' => 'Signature verification failed']);
        exit;
    }

    // 5. Return Subject UID
    return $payload['sub'];
}
