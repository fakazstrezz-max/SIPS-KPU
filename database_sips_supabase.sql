-- =====================================================================
-- SIPS — Sistem Informasi Penomoran Surat Otomatis
-- Studi Kasus: KPU Provinsi Maluku
-- Skema Database — VERSI POSTGRESQL / SUPABASE
--
-- Ini adalah hasil konversi dari database_sips.sql (MySQL) ke dialek
-- PostgreSQL, karena Supabase menjalankan PostgreSQL, bukan MySQL.
-- Tempel seluruh isi file ini ke Supabase SQL Editor lalu klik Run.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. tb_user
-- ---------------------------------------------------------------------
CREATE TABLE tb_user (
  id_user       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  username      VARCHAR(25)     NOT NULL UNIQUE,
  password      VARCHAR(255)    NOT NULL,
  nama_lengkap  VARCHAR(100)    NOT NULL,
  role          VARCHAR(20)     NOT NULL DEFAULT 'staf_tu'
                  CHECK (role IN ('admin','staf_tu','kepala_seksi')),
  status_aktif  BOOLEAN         NOT NULL DEFAULT true,
  created_at    TIMESTAMP       NOT NULL DEFAULT now(),
  updated_at    TIMESTAMP       NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- 2. tb_bagian
-- ---------------------------------------------------------------------
CREATE TABLE tb_bagian (
  id_bagian     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  kode_bagian   VARCHAR(10)     NOT NULL UNIQUE,
  nama_bagian   VARCHAR(100)    NOT NULL
);

-- ---------------------------------------------------------------------
-- 3. tb_klasifikasi
-- ---------------------------------------------------------------------
CREATE TABLE tb_klasifikasi (
  id_klasifikasi   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  kode_klasifikasi VARCHAR(10)    NOT NULL UNIQUE,
  nama_klasifikasi VARCHAR(100)   NOT NULL,
  keterangan       VARCHAR(255)
);

-- ---------------------------------------------------------------------
-- 4. tb_counter_nomor
-- ---------------------------------------------------------------------
CREATE TABLE tb_counter_nomor (
  tahun            SMALLINT       PRIMARY KEY,
  nomor_terakhir   INT            NOT NULL DEFAULT 0
);

-- ---------------------------------------------------------------------
-- 5. tb_surat_masuk
-- ---------------------------------------------------------------------
CREATE TABLE tb_surat_masuk (
  id_surat_masuk   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  kode_arsip       VARCHAR(30)     NOT NULL,
  perihal          VARCHAR(150)    NOT NULL,
  id_klasifikasi   BIGINT          NOT NULL REFERENCES tb_klasifikasi (id_klasifikasi),
  id_bagian        BIGINT          NOT NULL REFERENCES tb_bagian (id_bagian),
  asal_surat       VARCHAR(100)    NOT NULL,
  tanggal_surat    DATE            NOT NULL,
  tanggal_diterima DATE            NOT NULL,
  file_lampiran    VARCHAR(255),
  dicatat_oleh     BIGINT          NOT NULL REFERENCES tb_user (id_user),
  created_at       TIMESTAMP       NOT NULL DEFAULT now()
);
CREATE INDEX idx_sm_klasifikasi ON tb_surat_masuk (id_klasifikasi);
CREATE INDEX idx_sm_bagian      ON tb_surat_masuk (id_bagian);
CREATE INDEX idx_sm_tanggal     ON tb_surat_masuk (tanggal_diterima);

-- ---------------------------------------------------------------------
-- 6. tb_surat_keluar
-- ---------------------------------------------------------------------
CREATE TABLE tb_surat_keluar (
  id_surat_keluar  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nomor_urut       INT             NOT NULL,
  nomor_surat      VARCHAR(60)     NOT NULL UNIQUE,
  perihal          VARCHAR(150)    NOT NULL,
  id_klasifikasi   BIGINT          NOT NULL REFERENCES tb_klasifikasi (id_klasifikasi),
  id_bagian        BIGINT          NOT NULL REFERENCES tb_bagian (id_bagian),
  tanggal_surat    DATE            NOT NULL,
  tujuan_surat     VARCHAR(150)    NOT NULL,
  status           VARCHAR(10)     NOT NULL DEFAULT 'terbit'
                     CHECK (status IN ('draft','terbit')),
  file_cetak       VARCHAR(255),
  dibuat_oleh      BIGINT          NOT NULL REFERENCES tb_user (id_user),
  created_at       TIMESTAMP       NOT NULL DEFAULT now()
);
CREATE INDEX idx_sk_klasifikasi ON tb_surat_keluar (id_klasifikasi);
CREATE INDEX idx_sk_bagian      ON tb_surat_keluar (id_bagian);
CREATE INDEX idx_sk_tanggal     ON tb_surat_keluar (tanggal_surat);

-- ---------------------------------------------------------------------
-- 7. tb_log_aktivitas
-- ---------------------------------------------------------------------
CREATE TABLE tb_log_aktivitas (
  id_log        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_user       BIGINT          NOT NULL REFERENCES tb_user (id_user),
  aktivitas     VARCHAR(255)    NOT NULL,
  referensi     VARCHAR(60),
  created_at    TIMESTAMP       NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- Trigger pengganti "ON UPDATE CURRENT_TIMESTAMP" milik MySQL
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tb_user_updated_at
BEFORE UPDATE ON tb_user
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =====================================================================
-- DATA AWAL (SEED)
-- =====================================================================

-- Password akun ini adalah: admin123 (hash bcrypt, kompatibel dipakai lagi oleh PHP password_verify()).
INSERT INTO tb_user (username, password, nama_lengkap, role) VALUES
  ('admin', '$2y$10$IIO/qG4wPxFpbRKnHjEtGuF0e27WgPdo6c.nDubImkmOHhOjzXl32', 'Administrator Sistem', 'admin');

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
  (EXTRACT(YEAR FROM CURRENT_DATE)::SMALLINT, 0);

-- =====================================================================
-- VIEW BANTUAN UNTUK LAPORAN
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
JOIN tb_user u         ON u.id_user = sk.dibuat_oleh;

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
JOIN tb_user u         ON u.id_user = sm.dicatat_oleh;

-- =====================================================================
-- ROW LEVEL SECURITY
-- Supabase mengaktifkan akses lewat API secara default, sehingga RLS
-- WAJIB diaktifkan agar tabel tidak bisa diakses publik lewat REST/anon
-- key. Karena aplikasi ini memakai backend PHP dengan koneksi langsung
-- (bukan lewat Supabase client-side API), kita kunci total dari sisi
-- anon/public dan sisakan akses hanya lewat service_role (dipakai
-- backend). Jika nanti ingin mengakses dari JS di browser langsung ke
-- Supabase, policy di bawah perlu ditulis ulang sesuai kebutuhan.
-- =====================================================================
ALTER TABLE tb_user            ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_bagian           ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_klasifikasi      ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_counter_nomor    ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_surat_masuk      ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_surat_keluar     ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_log_aktivitas    ENABLE ROW LEVEL SECURITY;
-- (Tidak ada policy dibuat untuk anon/authenticated → otomatis semua
--  akses lewat REST API publik ditolak. service_role tetap bisa akses
--  penuh karena service_role melewati RLS.)
