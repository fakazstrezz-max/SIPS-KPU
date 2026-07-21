<?php
declare(strict_types=1);
require __DIR__ . '/config.php';
require_login();

$rows = db()->query('SELECT id_klasifikasi, kode_klasifikasi, nama_klasifikasi, keterangan FROM tb_klasifikasi ORDER BY nama_klasifikasi')->fetchAll();
json_ok(['data' => $rows]);
