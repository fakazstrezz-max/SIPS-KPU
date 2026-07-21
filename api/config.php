<?php
/**
 * SIPS — Konfigurasi koneksi database & helper bersama
 * Sesuaikan kredensial di bawah dengan environment Anda
 * (XAMPP/Laragon default: user root, password kosong).
 */

declare(strict_types=1);

ini_set('display_errors', '0');
error_reporting(E_ALL);

session_start();
header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');

/**
 * DB_DRIVER: 'mysql' untuk MySQL/MariaDB lokal atau hosting cPanel,
 *            'pgsql' untuk Supabase (PostgreSQL).
 *
 * Semua nilai bisa ditimpa lewat environment variable (dipakai saat
 * online di Railway/Render dkk, supaya password tidak ditulis di kode).
 * Jika env var tidak ada, dipakai nilai default di bawah (untuk XAMPP/
 * Laragon lokal).
 */
const DB_DRIVER_DEFAULT = 'mysql'; // ganti ke 'pgsql' di sini HANYA untuk dev lokal; di hosting online, atur lewat env var DB_DRIVER

function env(string $key, string $default): string {
    $v = getenv($key);
    return ($v === false || $v === '') ? $default : $v;
}

define('DB_DRIVER', env('DB_DRIVER', DB_DRIVER_DEFAULT));

const DB_NAME_DEFAULT = 'db_sips';
const DB_USER_DEFAULT = 'sips_app';
const DB_PASS_DEFAULT = 'sips_pass123';

function db(): PDO {
    static $pdo = null;
    if ($pdo === null) {
        $host = env('DB_HOST', '127.0.0.1');
        $port = env('DB_PORT', DB_DRIVER === 'pgsql' ? '5432' : '3306');
        $name = env('DB_NAME', DB_NAME_DEFAULT);
        $user = env('DB_USER', DB_USER_DEFAULT);
        $pass = env('DB_PASS', DB_PASS_DEFAULT);

        try {
            if (DB_DRIVER === 'pgsql') {
                $dsn = "pgsql:host=$host;port=$port;dbname=$name;sslmode=require";
            } else {
                $dsn = "mysql:host=$host;port=$port;dbname=$name;charset=utf8mb4";
            }
            $pdo = new PDO($dsn, $user, $pass, [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            ]);
        } catch (PDOException $e) {
            json_fail('Koneksi database gagal. Periksa kredensial dan status server database. (' . $e->getMessage() . ')', 500);
        }
    }
    return $pdo;
}

function json_out($data, int $code = 200): void {
    http_response_code($code);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

function json_ok($data = []): void {
    json_out(array_merge(['success' => true], is_array($data) ? $data : ['data' => $data]));
}

function json_fail(string $message, int $code = 400): void {
    json_out(['success' => false, 'message' => $message], $code);
}

function body(): array {
    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true);
    return is_array($data) ? $data : [];
}

function current_user(): ?array {
    return $_SESSION['user'] ?? null;
}

function require_login(): array {
    $user = current_user();
    if (!$user) {
        json_fail('Sesi berakhir, silakan login kembali.', 401);
    }
    return $user;
}

function method(): string {
    return $_SERVER['REQUEST_METHOD'];
}
