<?php
// backend/setup_db.php

$host = '127.0.0.1';
$username = 'root';
$password = '';

try {
    // 1. Hubungkan ke MySQL server
    $pdo = new PDO("mysql:host=$host", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // 2. Buat database
    $pdo->exec("DROP DATABASE IF EXISTS expense_tracker_db");
    $pdo->exec("CREATE DATABASE expense_tracker_db");
    echo "Database 'expense_tracker_db' berhasil di-recreate.\n";
    
    // 3. Masuk ke database
    $pdo->exec("USE expense_tracker_db");
    
    // 4. Buat tabel expenses
    $sql = "CREATE TABLE expenses (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id VARCHAR(128) NOT NULL,
        title VARCHAR(255) NOT NULL,
        amount DECIMAL(12,2) NOT NULL,
        expense_date DATETIME NOT NULL,
        category_id INT DEFAULT NULL,
        note TEXT DEFAULT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_user_id (user_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;";
    
    $pdo->exec($sql);
    echo "Tabel 'expenses' berhasil dibuat atau sudah ada.\n";
    
} catch (PDOException $e) {
    die("Koneksi/SQL Error: " . $e->getMessage() . "\n");
}
