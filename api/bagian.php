<?php
declare(strict_types=1);
require __DIR__ . '/config.php';
require_login();

$rows = db()->query('SELECT id_bagian, kode_bagian, nama_bagian FROM tb_bagian ORDER BY nama_bagian')->fetchAll();
json_ok(['data' => $rows]);
