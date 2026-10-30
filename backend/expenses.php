<?php
// backend/expenses.php

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Max-Age: 3600");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/auth_middleware.php';

// 1. Jalankan middleware verifikasi token
$uid = verify_auth_token();

$method = $_SERVER['REQUEST_METHOD'];
$id = isset($_GET['id']) ? (int)$_GET['id'] : null;

switch ($method) {
    case 'GET':
        if ($id) {
            // Get single expense
            $stmt = $pdo->prepare("SELECT * FROM expenses WHERE id = :id AND user_id = :uid");
            $stmt->execute(['id' => $id, 'uid' => $uid]);
            $row = $stmt->fetch();
            if ($row) {
                echo json_encode([
                    'id' => (int)$row['id'],
                    'user_id' => $row['user_id'],
                    'title' => $row['title'],
                    'amount' => (int)$row['amount'],
                    'date' => $row['expense_date'],
                    'note' => $row['note'],
                    'category_id' => $row['category_id'] !== null ? (int)$row['category_id'] : null,
                    'created_at' => $row['created_at']
                ]);
            } else {
                http_response_code(404);
                echo json_encode(['error' => 'Expense not found or unauthorized']);
            }
        } else {
            // Get all expenses
            $stmt = $pdo->prepare("SELECT * FROM expenses WHERE user_id = :uid ORDER BY expense_date DESC");
            $stmt->execute(['uid' => $uid]);
            $rows = $stmt->fetchAll();
            
            $res = [];
            foreach ($rows as $row) {
                $res[] = [
                    'id' => (int)$row['id'],
                    'user_id' => $row['user_id'],
                    'title' => $row['title'],
                    'amount' => (int)$row['amount'],
                    'date' => $row['expense_date'],
                    'note' => $row['note'],
                    'category_id' => $row['category_id'] !== null ? (int)$row['category_id'] : null,
                    'created_at' => $row['created_at']
                ];
            }
            echo json_encode($res);
        }
        break;

    case 'POST':
        $body = file_get_contents('php://input');
        $data = json_decode($body, true);

        if (empty($data['title']) || empty($data['amount']) || empty($data['date'])) {
            http_response_code(400);
            echo json_encode(['error' => 'Bad request: title, amount, and date are required']);
            break;
        }

        // Abaikan user_id dari input body, paksa menggunakan $uid hasil verifikasi
        $stmt = $pdo->prepare("INSERT INTO expenses (user_id, title, amount, expense_date, category_id, note) 
                               VALUES (:uid, :title, :amount, :date, :category_id, :note)");
        
        $stmt->execute([
            'uid' => $uid,
            'title' => $data['title'],
            'amount' => $data['amount'],
            'date' => $data['date'],
            'category_id' => isset($data['category_id']) ? (int)$data['category_id'] : null,
            'note' => isset($data['note']) ? $data['note'] : null
        ]);

        $insertedId = (int)$pdo->lastInsertId();
        
        http_response_code(201);
        echo json_encode([
            'id' => $insertedId,
            'user_id' => $uid,
            'title' => $data['title'],
            'amount' => (int)$data['amount'],
            'date' => $data['date'],
            'category_id' => isset($data['category_id']) ? (int)$data['category_id'] : null,
            'note' => isset($data['note']) ? $data['note'] : null,
            'created_at' => date('Y-m-d H:i:s')
        ]);
        break;

    case 'PUT':
        if (!$id) {
            http_response_code(400);
            echo json_encode(['error' => 'Missing expense ID']);
            break;
        }

        $body = file_get_contents('php://input');
        $data = json_decode($body, true);

        if (empty($data['title']) || empty($data['amount']) || empty($data['date'])) {
            http_response_code(400);
            echo json_encode(['error' => 'Bad request: title, amount, and date are required']);
            break;
        }

        // Cek apakah item ada dan milik user saat ini (Double validation)
        $checkStmt = $pdo->prepare("SELECT user_id FROM expenses WHERE id = :id");
        $checkStmt->execute(['id' => $id]);
        $existing = $checkStmt->fetch();

        if (!$existing) {
            http_response_code(404);
            echo json_encode(['error' => 'Expense not found']);
            break;
        }

        if ($existing['user_id'] !== $uid) {
            http_response_code(403);
            echo json_encode(['error' => 'Forbidden: You do not own this expense']);
            break;
        }

        // Lakukan update dengan filter kepemilikan ganda
        $stmt = $pdo->prepare("UPDATE expenses 
                               SET title = :title, amount = :amount, expense_date = :date, category_id = :category_id, note = :note 
                               WHERE id = :id AND user_id = :uid");
        
        $stmt->execute([
            'id' => $id,
            'uid' => $uid,
            'title' => $data['title'],
            'amount' => $data['amount'],
            'date' => $data['date'],
            'category_id' => isset($data['category_id']) ? (int)$data['category_id'] : null,
            'note' => isset($data['note']) ? $data['note'] : null
        ]);

        echo json_encode([
            'id' => $id,
            'user_id' => $uid,
            'title' => $data['title'],
            'amount' => (int)$data['amount'],
            'date' => $data['date'],
            'category_id' => isset($data['category_id']) ? (int)$data['category_id'] : null,
            'note' => isset($data['note']) ? $data['note'] : null,
            'created_at' => $data['created_at'] ?? date('Y-m-d H:i:s')
        ]);
        break;

    case 'DELETE':
        if (!$id) {
            http_response_code(400);
            echo json_encode(['error' => 'Missing expense ID']);
            break;
        }

        // Cek kepemilikan sebelum hapus
        $checkStmt = $pdo->prepare("SELECT user_id FROM expenses WHERE id = :id");
        $checkStmt->execute(['id' => $id]);
        $existing = $checkStmt->fetch();

        if (!$existing) {
            http_response_code(404);
            echo json_encode(['error' => 'Expense not found']);
            break;
        }

        if ($existing['user_id'] !== $uid) {
            http_response_code(403);
            echo json_encode(['error' => 'Forbidden: You do not own this data']);
            break;
        }

        // Delete query dengan validasi ganda
        $stmt = $pdo->prepare("DELETE FROM expenses WHERE id = :id AND user_id = :uid");
        $stmt->execute(['id' => $id, 'uid' => $uid]);

        echo json_encode(['success' => true]);
        break;

    default:
        http_response_code(405);
        echo json_encode(['error' => 'Method not allowed']);
        break;
}
