<?php
declare(strict_types=1);
require __DIR__ . '/config.php';

$action = $_GET['action'] ?? '';

if ($action === 'login' && method() === 'POST') {
    $in = body();
    $username = trim((string)($in['username'] ?? ''));
    $password = (string)($in['password'] ?? '');

    if ($username === '' || $password === '') {
        json_fail('Username dan password wajib diisi.');
    }

    $stmt = db()->prepare('SELECT * FROM tb_user WHERE username = ? AND status_aktif = TRUE LIMIT 1');
    $stmt->execute([$username]);
    $user = $stmt->fetch();

    if (!$user || !password_verify($password, $user['password'])) {
        json_fail('Username atau password salah.', 401);
    }

    $_SESSION['user'] = [
        'id'    => (int)$user['id_user'],
        'username' => $user['username'],
        'nama'  => $user['nama_lengkap'],
        'role'  => $user['role'],
    ];

    db()->prepare('INSERT INTO tb_log_aktivitas (id_user, aktivitas) VALUES (?, ?)')
        ->execute([$user['id_user'], 'Login ke sistem']);

    json_ok(['user' => $_SESSION['user']]);
}

if ($action === 'logout') {
    $_SESSION = [];
    session_destroy();
    json_ok();
}

if ($action === 'me') {
    $user = current_user();
    json_out($user ? ['success' => true, 'user' => $user] : ['success' => false]);
}

json_fail('Aksi tidak dikenal.', 404);
