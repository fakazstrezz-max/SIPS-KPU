<?php
declare(strict_types=1);
require __DIR__ . '/config.php';
$user = require_login();
$pdo = db();

if (method() === 'GET') {
    $where = [];
    $params = [];

    if (!empty($_GET['jenis'])) {
        $where[] = 'k.kode_klasifikasi = ?';
        $params[] = $_GET['jenis'];
    }
    if (!empty($_GET['q'])) {
        $where[] = 'sm.perihal LIKE ?';
        $params[] = '%' . $_GET['q'] . '%';
    }
    $sql = 'SELECT sm.id_surat_masuk AS id, sm.kode_arsip AS kode, sm.perihal,
                   k.kode_klasifikasi AS kode_jenis, k.nama_klasifikasi AS nama_jenis,
                   b.kode_bagian, b.nama_bagian,
                   sm.tanggal_diterima AS tanggal, sm.asal_surat AS tujuan,
                   u.nama_lengkap AS dicatat_oleh, sm.created_at
            FROM tb_surat_masuk sm
            JOIN tb_klasifikasi k ON k.id_klasifikasi = sm.id_klasifikasi
            JOIN tb_bagian b ON b.id_bagian = sm.id_bagian
            JOIN tb_user u ON u.id_user = sm.dicatat_oleh';
    if ($where) {
        $sql .= ' WHERE ' . implode(' AND ', $where);
    }
    $sql .= ' ORDER BY sm.id_surat_masuk DESC';

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    json_ok(['data' => $stmt->fetchAll()]);
}

if (method() === 'POST') {
    $in = body();
    $perihal = trim((string)($in['perihal'] ?? ''));
    $id_klasifikasi = (int)($in['id_klasifikasi'] ?? 0);
    $id_bagian = (int)($in['id_bagian'] ?? 0);
    $tanggal = (string)($in['tanggal_diterima'] ?? '');
    $asal = trim((string)($in['asal_surat'] ?? ''));
    $kodeArsip = trim((string)($in['kode_arsip'] ?? ''));

    if ($perihal === '' || $asal === '' || !$id_klasifikasi || !$id_bagian || !$tanggal) {
        json_fail('Semua kolom wajib diisi.');
    }

    if ($kodeArsip === '') {
        $count = (int)$pdo->query('SELECT COUNT(*) FROM tb_surat_masuk')->fetchColumn() + 1;
        $kodeArsip = sprintf('AG-%s-%03d', date('Y', strtotime($tanggal)), $count);
    }

    $insert = $pdo->prepare(
        'INSERT INTO tb_surat_masuk
            (kode_arsip, perihal, id_klasifikasi, id_bagian, asal_surat, tanggal_surat, tanggal_diterima, dicatat_oleh)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
    );
    $insert->execute([$kodeArsip, $perihal, $id_klasifikasi, $id_bagian, $asal, $tanggal, $tanggal, $user['id']]);
    $newId = (int)$pdo->lastInsertId();

    $pdo->prepare('INSERT INTO tb_log_aktivitas (id_user, aktivitas, referensi) VALUES (?, ?, ?)')
        ->execute([$user['id'], 'Mencatat surat masuk', $kodeArsip]);

    json_ok(['data' => ['id' => $newId, 'kode' => $kodeArsip]]);
}

if (method() === 'DELETE') {
    $id = (int)($_GET['id'] ?? 0);
    if (!$id) {
        json_fail('ID surat tidak valid.');
    }
    $pdo->prepare('DELETE FROM tb_surat_masuk WHERE id_surat_masuk = ?')->execute([$id]);
    json_ok();
}

json_fail('Metode tidak didukung.', 405);
