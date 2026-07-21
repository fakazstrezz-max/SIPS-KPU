<?php
declare(strict_types=1);
require __DIR__ . '/config.php';
require_login();
$pdo = db();

$year = (int)date('Y');

$skTahunIni = (int)$pdo->query("SELECT COUNT(*) FROM tb_surat_keluar WHERE EXTRACT(YEAR FROM tanggal_surat) = $year")->fetchColumn();
$skTotal = (int)$pdo->query('SELECT COUNT(*) FROM tb_surat_keluar')->fetchColumn();
$smTotal = (int)$pdo->query('SELECT COUNT(*) FROM tb_surat_masuk')->fetchColumn();

$distribusi = $pdo->query(
    "SELECT nama_klasifikasi, COUNT(*) AS jumlah FROM (
        SELECT id_klasifikasi FROM tb_surat_keluar
        UNION ALL
        SELECT id_klasifikasi FROM tb_surat_masuk
    ) gab
    JOIN tb_klasifikasi k ON k.id_klasifikasi = gab.id_klasifikasi
    GROUP BY nama_klasifikasi
    ORDER BY jumlah DESC"
)->fetchAll();

$terbaru = $pdo->query(
    'SELECT sk.nomor_surat AS nomor, sk.perihal, k.nama_klasifikasi AS jenis,
            b.nama_bagian AS bagian, sk.tanggal_surat AS tanggal, sk.tujuan_surat AS tujuan
     FROM tb_surat_keluar sk
     JOIN tb_klasifikasi k ON k.id_klasifikasi = sk.id_klasifikasi
     JOIN tb_bagian b ON b.id_bagian = sk.id_bagian
     ORDER BY sk.id_surat_keluar DESC LIMIT 5'
)->fetchAll();

json_ok([
    'stats' => [
        'surat_keluar_tahun_ini' => $skTahunIni,
        'surat_keluar_total' => $skTotal,
        'surat_masuk_total' => $smTotal,
        'kategori_terpakai' => count($distribusi),
    ],
    'distribusi' => $distribusi,
    'terbaru' => $terbaru,
]);
