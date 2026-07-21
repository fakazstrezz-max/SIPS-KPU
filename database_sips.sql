-- =====================================================================
-- SIPS — Sistem Informasi Penomoran Surat Otomatis
-- Studi Kasus: KPU Provinsi Maluku
-- Skema Database MySQL
--
-- Dikembangkan dari rancangan Tabel Login, Tabel Surat Masuk, dan
-- Tabel Surat Keluar pada BAB III Perancangan Sistem Database,
-- dinormalisasi menjadi beberapa tabel referensi (master) agar kode
-- klasifikasi dan kode bagian tidak diulang-ulang (redundant) di
-- setiap baris surat, serta ditambah tabel penomor untuk menjamin
-- keunikan nomor surat keluar.
-- =====================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE DATABASE IF NOT EXISTS db_sips
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE db_sips;

-- ---------------------------------------------------------------------
-- 1. tb_user  (pengembangan dari "Tabel Login")
--    Menyimpan akun pengguna sistem. Password disimpan ter-hash
--    (bcrypt / password_hash PHP), bukan plain text seperti pada
--    rancangan awal varchar(25), demi keamanan.
-- ---------------------------------------------------------------------
CREATE TABLE tb_user (
  id_user       INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  username      VARCHAR(25)     NOT NULL,
  password      VARCHAR(255)    NOT NULL COMMENT 'hash bcrypt',
  nama_lengkap  VARCHAR(100)    NOT NULL,
  role          ENUM('admin','staf_tu','kepala_seksi') NOT NULL DEFAULT 'staf_tu',
  status_aktif  TINYINT(1)      NOT NULL DEFAULT 1,
  created_at    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id_user),
  UNIQUE KEY uq_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 2. tb_bagian  (tabel referensi — pecahan dari kolom "Department")
--    Daftar bagian/divisi struktural KPU Provinsi Maluku.
-- ---------------------------------------------------------------------
CREATE TABLE tb_bagian (
  id_bagian     INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  kode_bagian   VARCHAR(10)     NOT NULL,
  nama_bagian   VARCHAR(100)    NOT NULL,
  PRIMARY KEY (id_bagian),
  UNIQUE KEY uq_kode_bagian (kode_bagian)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 3. tb_klasifikasi  (tabel referensi — fitur klasifikasi dokumen)
--    Daftar jenis/kategori surat sesuai kode klasifikasi arsip.
-- ---------------------------------------------------------------------
CREATE TABLE tb_klasifikasi (
  id_klasifikasi   INT UNSIGNED   NOT NULL AUTO_INCREMENT,
  kode_klasifikasi VARCHAR(10)    NOT NULL,
  nama_klasifikasi VARCHAR(100)   NOT NULL,
  keterangan       VARCHAR(255)   NULL,
  PRIMARY KEY (id_klasifikasi),
  UNIQUE KEY uq_kode_klasifikasi (kode_klasifikasi)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 4. tb_counter_nomor
--    Penjamin nomor urut surat keluar tidak pernah dobel, walau
--    diakses banyak admin sekaligus. Satu baris per tahun berjalan.
-- ---------------------------------------------------------------------
CREATE TABLE tb_counter_nomor (
  tahun            YEAR(4)        NOT NULL,
  nomor_terakhir   INT UNSIGNED   NOT NULL DEFAULT 0,
  PRIMARY KEY (tahun)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 5. tb_surat_masuk  (pengembangan dari "Tabel Surat Masuk")
--    Dicatat dan diklasifikasikan; TIDAK diberi penomoran otomatis
--    (Batasan Masalah 1.3.3).
-- ---------------------------------------------------------------------
CREATE TABLE tb_surat_masuk (
  id_surat_masuk   INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  kode_arsip       VARCHAR(30)     NOT NULL COMMENT 'kode pencatatan manual/agenda',
  perihal          VARCHAR(150)    NOT NULL,
  id_klasifikasi   INT UNSIGNED    NOT NULL,
  id_bagian        INT UNSIGNED    NOT NULL COMMENT 'bagian tujuan disposisi',
  asal_surat       VARCHAR(100)    NOT NULL,
  tanggal_surat    DATE            NOT NULL COMMENT 'tanggal tertulis pada surat',
  tanggal_diterima DATE            NOT NULL COMMENT 'tanggal diterima KPU',
  file_lampiran    VARCHAR(255)    NULL COMMENT 'path hasil scan/upload',
  dicatat_oleh     INT UNSIGNED    NOT NULL,
  created_at       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_surat_masuk),
  KEY idx_sm_klasifikasi (id_klasifikasi),
  KEY idx_sm_bagian (id_bagian),
  KEY idx_sm_tanggal (tanggal_diterima),
  CONSTRAINT fk_sm_klasifikasi FOREIGN KEY (id_klasifikasi) REFERENCES tb_klasifikasi (id_klasifikasi)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_sm_bagian FOREIGN KEY (id_bagian) REFERENCES tb_bagian (id_bagian)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_sm_user FOREIGN KEY (dicatat_oleh) REFERENCES tb_user (id_user)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 6. tb_surat_keluar  (pengembangan dari "Tabel Surat Keluar")
--    Nomor surat dibuat otomatis oleh sistem: format
--    {urut}/{kode_klasifikasi}/{kode_bagian}/{bulan_romawi}/{tahun}
-- ---------------------------------------------------------------------
CREATE TABLE tb_surat_keluar (
  id_surat_keluar  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  nomor_urut       INT UNSIGNED    NOT NULL COMMENT 'bagian urut dari nomor_surat, per tahun',
  nomor_surat      VARCHAR(60)     NOT NULL COMMENT 'nomor surat lengkap hasil generate otomatis',
  perihal          VARCHAR(150)    NOT NULL,
  id_klasifikasi   INT UNSIGNED    NOT NULL,
  id_bagian        INT UNSIGNED    NOT NULL,
  tanggal_surat    DATE            NOT NULL,
  tujuan_surat     VARCHAR(150)    NOT NULL,
  status           ENUM('draft','terbit') NOT NULL DEFAULT 'terbit',
  file_cetak       VARCHAR(255)    NULL COMMENT 'path PDF hasil cetak, jika disimpan',
  dibuat_oleh      INT UNSIGNED    NOT NULL,
  created_at       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_surat_keluar),
  UNIQUE KEY uq_nomor_surat (nomor_surat),
  KEY idx_sk_klasifikasi (id_klasifikasi),
  KEY idx_sk_bagian (id_bagian),
  KEY idx_sk_tanggal (tanggal_surat),
  CONSTRAINT fk_sk_klasifikasi FOREIGN KEY (id_klasifikasi) REFERENCES tb_klasifikasi (id_klasifikasi)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_sk_bagian FOREIGN KEY (id_bagian) REFERENCES tb_bagian (id_bagian)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_sk_user FOREIGN KEY (dibuat_oleh) REFERENCES tb_user (id_user)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 7. tb_log_aktivitas  (opsional — jejak audit sederhana)
--    Berguna untuk BAB IV bagian pengujian: membuktikan setiap surat
--    tercatat oleh siapa dan kapan, mendukung akuntabilitas admin.
-- ---------------------------------------------------------------------
CREATE TABLE tb_log_aktivitas (
  id_log        INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  id_user       INT UNSIGNED    NOT NULL,
  aktivitas     VARCHAR(255)    NOT NULL,
  referensi     VARCHAR(60)     NULL COMMENT 'mis. nomor_surat atau kode_arsip terkait',
  created_at    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_log),
  CONSTRAINT fk_log_user FOREIGN KEY (id_user) REFERENCES tb_user (id_user)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
-- USER DATABASE UNTUK APLIKASI (bukan root — praktik keamanan yang baik)
-- Kredensial ini dipakai oleh api/config.php pada backend PHP.
-- Ganti 'sips_pass123' dengan password yang lebih kuat saat produksi.
-- =====================================================================
CREATE USER IF NOT EXISTS 'sips_app'@'127.0.0.1' IDENTIFIED BY 'sips_pass123';
CREATE USER IF NOT EXISTS 'sips_app'@'localhost' IDENTIFIED BY 'sips_pass123';
GRANT SELECT, INSERT, UPDATE, DELETE ON db_sips.* TO 'sips_app'@'127.0.0.1';
GRANT SELECT, INSERT, UPDATE, DELETE ON db_sips.* TO 'sips_app'@'localhost';
FLUSH PRIVILEGES;

-- =====================================================================
-- DATA AWAL (SEED) — sesuai daftar klasifikasi & bagian pada prototipe
-- =====================================================================

INSERT INTO tb_user (username, password, nama_lengkap, role) VALUES
  ('admin', '$2y$10$IIO/qG4wPxFpbRKnHjEtGuF0e27WgPdo6c.nDubImkmOHhOjzXl32', 'Administrator Sistem', 'admin');
-- Password akun ini adalah: admin123 (sudah di-hash dengan password_hash(..., PASSWORD_BCRYPT)).
-- Ganti/tambahkan akun lain melalui aplikasi atau query INSERT serupa dengan hash baru.

INSERT INTO tb_bagian (kode_bagian, nama_bagian) VALUES
  ('SEKR', 'Sekretariat'),
  ('TEK',  'Divisi Teknis Penyelenggaraan'),
  ('HUK',  'Divisi Hukum'),
  ('PDI',  'Divisi Perencanaan, Data & Informasi'),
  ('SDM',  'Divisi SDM & Organisasi'),
  ('KEU',  'Divisi Keuangan, Umum & Logistik'),
  ('SOS',  'Divisi Sosialisasi & Partisipasi Masyarakat');

INSERT INTO tb_klasifikasi (kode_klasifikasi, nama_klasifikasi, keterangan) VALUES
  ('UND',  'Undangan',        'Surat undangan rapat/kegiatan'),
  ('KPT',  'Keputusan',       'Surat keputusan resmi pimpinan'),
  ('PENG', 'Pengumuman',      'Pengumuman internal/eksternal'),
  ('DISP', 'Disposisi',       'Lembar disposisi tindak lanjut surat masuk'),
  ('LAP',  'Laporan',         'Laporan kegiatan/pertanggungjawaban'),
  ('PEMB', 'Pemberitahuan',   'Surat pemberitahuan umum'),
  ('ST',   'Surat Tugas',     'Penugasan pegawai/tim'),
  ('ND',   'Nota Dinas',      'Komunikasi internal antar bagian');

INSERT INTO tb_counter_nomor (tahun, nomor_terakhir) VALUES
  (YEAR(CURDATE()), 0);

-- =====================================================================
-- CONTOH QUERY: PEMBUATAN NOMOR SURAT KELUAR OTOMATIS
-- (dipanggil dari backend PHP/Laravel dalam satu transaksi, agar
--  UPDATE...SELECT pada tb_counter_nomor bersifat atomik / aman dari
--  race condition ketika dua admin menyimpan surat bersamaan)
-- =====================================================================
-- START TRANSACTION;
-- SELECT nomor_terakhir INTO @urut FROM tb_counter_nomor WHERE tahun = YEAR(CURDATE()) FOR UPDATE;
-- SET @urut = @urut + 1;
-- UPDATE tb_counter_nomor SET nomor_terakhir = @urut WHERE tahun = YEAR(CURDATE());
-- -- @nomor_surat dirakit di aplikasi: {urut 3 digit}/{kode_klasifikasi}/{kode_bagian}/{bulan_romawi}/{tahun}
-- INSERT INTO tb_surat_keluar (nomor_urut, nomor_surat, perihal, id_klasifikasi, id_bagian, tanggal_surat, tujuan_surat, dibuat_oleh)
--   VALUES (@urut, @nomor_surat, 'Undangan Rapat Koordinasi', 1, 2, CURDATE(), 'Seluruh Anggota KPU Kab/Kota', 1);
-- COMMIT;

-- =====================================================================
-- VIEW BANTUAN UNTUK LAPORAN (BAB IV — hasil dan pembahasan)
-- =====================================================================
CREATE OR REPLACE VIEW v_surat_keluar_lengkap AS
SELECT
  sk.id_surat_keluar,
  sk.nomor_surat,
  sk.perihal,
  k.nama_klasifikasi,
  b.nama_bagian,
  sk.tanggal_surat,
  sk.tujuan_surat,
  u.nama_lengkap AS dibuat_oleh,
  sk.created_at
FROM tb_surat_keluar sk
JOIN tb_klasifikasi k ON k.id_klasifikasi = sk.id_klasifikasi
JOIN tb_bagian b       ON b.id_bagian = sk.id_bagian
JOIN tb_user u          ON u.id_user = sk.dibuat_oleh;

CREATE OR REPLACE VIEW v_surat_masuk_lengkap AS
SELECT
  sm.id_surat_masuk,
  sm.kode_arsip,
  sm.perihal,
  k.nama_klasifikasi,
  b.nama_bagian,
  sm.asal_surat,
  sm.tanggal_diterima,
  u.nama_lengkap AS dicatat_oleh,
  sm.created_at
FROM tb_surat_masuk sm
JOIN tb_klasifikasi k ON k.id_klasifikasi = sm.id_klasifikasi
JOIN tb_bagian b       ON b.id_bagian = sm.id_bagian
JOIN tb_user u          ON u.id_user = sm.dicatat_oleh;
