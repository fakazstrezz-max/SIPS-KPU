<?php
declare(strict_types=1);
require __DIR__ . '/config.php';
$user = require_login();

const ROMAWI = ['I','II','III','IV','V','VI','VII','VIII','IX','X','XI','XII'];

function nomor_ke_romawi(int $bulan): string {
    return ROMAWI[$bulan - 1] ?? 'I';
}

$pdo = db();

if (method() === 'GET') {
    $where = [];
    $params = [];

    if (!empty($_GET['jenis'])) {
        $where[] = 'k.kode_klasifikasi = ?';
        $params[] = $_GET['jenis'];
    }
    if (!empty($_GET['q'])) {
        $where[] = '(sk.perihal LIKE ? OR sk.nomor_surat LIKE ?)';
        $params[] = '%' . $_GET['q'] . '%';
        $params[] = '%' . $_GET['q'] . '%';
    }
    $sql = 'SELECT sk.id_surat_keluar AS id, sk.nomor_surat AS nomor, sk.perihal,
                   k.kode_klasifikasi AS kode_jenis, k.nama_klasifikasi AS nama_jenis,
                   b.kode_bagian, b.nama_bagian,
                   sk.tanggal_surat AS tanggal, sk.tujuan_surat AS tujuan,
                   u.nama_lengkap AS dibuat_oleh, sk.created_at
            FROM tb_surat_keluar sk
            JOIN tb_klasifikasi k ON k.id_klasifikasi = sk.id_klasifikasi
            JOIN tb_bagian b ON b.id_bagian = sk.id_bagian
            JOIN tb_user u ON u.id_user = sk.dibuat_oleh';
    if ($where) {
        $sql .= ' WHERE ' . implode(' AND ', $where);
    }
    $sql .= ' ORDER BY sk.id_surat_keluar DESC';

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    json_ok(['data' => $stmt->fetchAll()]);
}

if (method() === 'POST') {
    $in = body();
    $perihal = trim((string)($in['perihal'] ?? ''));
    $id_klasifikasi = (int)($in['id_klasifikasi'] ?? 0);
    $id_bagian = (int)($in['id_bagian'] ?? 0);
    $tanggal = (string)($in['tanggal_surat'] ?? '');
    $tujuan = trim((string)($in['tujuan_surat'] ?? ''));

    if ($perihal === '' || $tujuan === '' || !$id_klasifikasi || !$id_bagian || !$tanggal) {
        json_fail('Semua kolom wajib diisi.');
    }

    $ts = strtotime($tanggal);
    if ($ts === false) {
        json_fail('Format tanggal tidak valid.');
    }
    $tahun = (int)date('Y', $ts);
    $bulanRomawi = nomor_ke_romawi((int)date('n', $ts));

    try {
        $pdo->beginTransaction();

        // Kunci baris counter tahun berjalan agar aman dari race condition
        // saat dua admin menyimpan surat pada waktu bersamaan.
        $stmt = $pdo->prepare('SELECT nomor_terakhir FROM tb_counter_nomor WHERE tahun = ? FOR UPDATE');
        $stmt->execute([$tahun]);
        $row = $stmt->fetch();
        if ($row === false) {
            $pdo->prepare('INSERT INTO tb_counter_nomor (tahun, nomor_terakhir) VALUES (?, 0)')->execute([$tahun]);
            $urut = 0;
        } else {
            $urut = (int)$row['nomor_terakhir'];
        }
        $urut++;
        $pdo->prepare('UPDATE tb_counter_nomor SET nomor_terakhir = ? WHERE tahun = ?')->execute([$urut, $tahun]);

        $kode = $pdo->prepare('SELECT kode_klasifikasi FROM tb_klasifikasi WHERE id_klasifikasi = ?');
        $kode->execute([$id_klasifikasi]);
        $kodeKlasifikasi = $kode->fetchColumn();

        $kb = $pdo->prepare('SELECT kode_bagian FROM tb_bagian WHERE id_bagian = ?');
        $kb->execute([$id_bagian]);
        $kodeBagian = $kb->fetchColumn();

        if (!$kodeKlasifikasi || !$kodeBagian) {
            $pdo->rollBack();
            json_fail('Klasifikasi atau bagian tidak ditemukan.');
        }

        $nomorSurat = sprintf('%03d/%s/%s/%s/%d', $urut, $kodeKlasifikasi, $kodeBagian, $bulanRomawi, $tahun);

        $insert = $pdo->prepare(
            'INSERT INTO tb_surat_keluar
                (nomor_urut, nomor_surat, perihal, id_klasifikasi, id_bagian, tanggal_surat, tujuan_surat, dibuat_oleh)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
        );
        $insert->execute([$urut, $nomorSurat, $perihal, $id_klasifikasi, $id_bagian, $tanggal, $tujuan, $user['id']]);
        $newId = (int)$pdo->lastInsertId();

        $pdo->prepare('INSERT INTO tb_log_aktivitas (id_user, aktivitas, referensi) VALUES (?, ?, ?)')
            ->execute([$user['id'], 'Membuat surat keluar', $nomorSurat]);

        $pdo->commit();

        json_ok(['data' => ['id' => $newId, 'nomor' => $nomorSurat]]);
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        json_fail('Gagal menyimpan surat keluar: ' . $e->getMessage(), 500);
    }
}

if (method() === 'DELETE') {
    $id = (int)($_GET['id'] ?? 0);
    if (!$id) {
        json_fail('ID surat tidak valid.');
    }
    $pdo->prepare('DELETE FROM tb_surat_keluar WHERE id_surat_keluar = ?')->execute([$id]);
    json_ok();
}

json_fail('Metode tidak didukung.', 405);
