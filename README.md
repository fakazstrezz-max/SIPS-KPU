# SIPS — Sistem Penomoran Surat Otomatis
Studi Kasus: KPU Provinsi Maluku — dengan integrasi database MySQL

Paket ini berisi aplikasi web lengkap (frontend + backend PHP + skema
database) yang sudah diuji berjalan penuh: login, penomoran surat
otomatis, klasifikasi dokumen, dan pencatatan surat masuk, semuanya
tersimpan di MySQL — bukan lagi di penyimpanan browser.

## Struktur Folder

```
sips-app/
├─ index.html          ← tampilan aplikasi (dibuka lewat server PHP, bukan dobel klik)
├─ api/
│  ├─ config.php        koneksi database & helper bersama
│  ├─ auth.php           login / logout / cek sesi
│  ├─ bagian.php         daftar bagian/divisi
│  ├─ klasifikasi.php    daftar klasifikasi surat
│  ├─ surat_keluar.php   list, buat (generate nomor otomatis), hapus
│  ├─ surat_masuk.php    list, buat, hapus
│  └─ dashboard.php      statistik ringkasan
database_sips.sql     ← skema database MySQL lengkap + data awal
```

## Kebutuhan

- PHP 8.1+ dengan ekstensi **pdo_mysql** (untuk MySQL) atau **pdo_pgsql**
  (untuk Supabase/PostgreSQL) — cek dengan `php -m | grep pdo`
- MySQL/MariaDB (opsi lokal) **atau** akun Supabase (opsi online)
- (Opsional) XAMPP / Laragon jika dijalankan di Windows secara lokal

## Dua Cara Menjalankan

| | **A. Lokal (untuk pengembangan)** | **B. Online (untuk demo/sidang)** |
|---|---|---|
| Database | MySQL/MariaDB di komputer sendiri | Supabase (PostgreSQL, gratis) |
| Kode aplikasi | `php -S` atau XAMPP di komputer sendiri | Railway / hosting PHP lain |
| Bisa diakses dari mana | Hanya komputer sendiri | Dari mana saja lewat internet |
| File skema dipakai | `database_sips.sql` | `database_sips_supabase.sql` |

### A. Menjalankan Secara Lokal

**1. Buat database dan import skema**

```bash
mysql -u root -p < database_sips.sql
```

Perintah ini otomatis:
- membuat database `db_sips` beserta 7 tabel dan 2 view
- mengisi data awal klasifikasi surat & bagian/divisi
- membuat akun login demo: **admin / admin123**
- membuat user database `sips_app` (bukan root) yang dipakai backend

**2. Jalankan aplikasi**

```bash
cd sips-app
php -S 127.0.0.1:8000
```

Buka `http://127.0.0.1:8000/index.html`, login `admin` / `admin123`.

Atau taruh folder `sips-app` di `htdocs` (XAMPP) / `www` (Laragon) dan
akses lewat `http://localhost/sips-app/`.

### B. Menjalankan Online (Supabase + Railway)

Ini cara mem-publish SIPS supaya bisa diakses dosen penguji atau staf
KPU dari mana saja, tanpa perlu komputer Anda tetap menyala.

**Langkah 1 — Buat database di Supabase**

1. Daftar/masuk ke [supabase.com](https://supabase.com), buat *New Project*.
2. Catat *Database Password* yang Anda buat saat itu — hanya muncul sekali.
3. Buka menu **SQL Editor** di sidebar kiri, klik *New query*.
4. Tempel seluruh isi file `database_sips_supabase.sql`, klik **Run**.
5. Buka **Project Settings → Database → Connection string**, salin bagian
   *Host*, *Port* (biasanya `5432`, atau `6543` jika memakai *Connection
   Pooling* — disarankan untuk hosting seperti Railway), *Database name*
   (`postgres`), dan *User* (`postgres.xxxxxxxxxxxx`).

**Langkah 2 — Deploy kode ke Railway**

1. Unggah folder `sips-app` ke repository GitHub baru.
2. Daftar/masuk ke [railway.com](https://railway.com) dengan akun GitHub.
3. *New Project* → *Deploy from GitHub repo* → pilih repo tadi.
4. Railway otomatis mengenali proyek PHP. Di tab **Variables**,
   tambahkan environment variable berikut (nilainya dari Langkah 1):

   | Variable | Nilai |
   |---|---|
   | `DB_DRIVER` | `pgsql` |
   | `DB_HOST` | host Supabase Anda |
   | `DB_PORT` | `6543` (pooler) atau `5432` |
   | `DB_NAME` | `postgres` |
   | `DB_USER` | user Supabase Anda (`postgres.xxxxxxxxxxxx`) |
   | `DB_PASS` | password Supabase Anda |

5. Buka tab **Settings → Networking → Generate Domain** untuk mendapat
   URL publik (`https://nama-proyek.up.railway.app`).
6. Akses `https://nama-proyek.up.railway.app/index.html`, login dengan
   `admin` / `admin123`.

Tidak ada satu baris kode pun yang perlu diedit untuk pindah dari
lokal (MySQL) ke online (Supabase) — `api/config.php` sudah dibuat
untuk membaca semua kredensial dari environment variable di atas.
Kalau env var tidak diisi, aplikasi otomatis memakai nilai default
untuk pengembangan lokal.

**Alternatif lebih sederhana (gratis, umum dipakai untuk demo skripsi):**
Kalau tidak ingin memakai Supabase, folder `sips-app` beserta
`database_sips.sql` (versi MySQL) juga bisa langsung diunggah ke
hosting cPanel gratis seperti InfinityFree atau 000webhost — tinggal
import `.sql` lewat phpMyAdmin bawaan mereka dan sesuaikan
`DB_HOST`/`DB_USER`/`DB_PASS` lewat env var atau langsung di
`api/config.php`.

## Cara Kerja Integrasi

- Frontend (`index.html`) **tidak menyimpan data apa pun di browser**.
  Setiap aksi (login, buat surat, hapus, dsb.) memanggil `fetch()` ke
  file PHP di folder `api/`.
- Sesi login memakai PHP session (cookie), sehingga refresh halaman
  tidak perlu login ulang selama sesi masih aktif.
- Nomor surat keluar dibuat di dalam **transaksi database**
  (`SELECT ... FOR UPDATE`) supaya tidak pernah bentrok walau dua
  admin menyimpan surat pada detik yang sama — lihat komentar di
  `api/surat_keluar.php`.
- Statistik dashboard dihitung langsung dengan query `COUNT()` dan
  `JOIN` ke tabel, bukan dihitung ulang di JavaScript.

## Untuk Bab Pengujian Skripsi

Beberapa hal yang sudah terverifikasi dan bisa dilaporkan sebagai
hasil pengujian black-box:

| Pengujian | Hasil |
|---|---|
| Login dengan kredensial salah | Ditolak, pesan error ditampilkan |
| Login dengan kredensial benar | Berhasil, sesi tersimpan |
| Buat surat keluar | Nomor ter-generate otomatis dan unik |
| Buat surat keluar kedua di tahun sama | Nomor urut bertambah otomatis (001 → 002) |
| Pencarian & filter klasifikasi | Hasil sesuai kata kunci/kategori |
| Hapus surat | Data hilang dari daftar dan database |
| Logout | Sesi berakhir, endpoint terproteksi menolak akses |

## Catatan Keamanan (untuk dijelaskan di bab pembahasan)

- Password pengguna disimpan sebagai hash bcrypt (`password_hash`),
  bukan plain text seperti rancangan tabel login awal.
- Backend memakai *prepared statements* (PDO) di semua query,
  sehingga aman dari SQL Injection.
- Aplikasi memakai user database dengan hak akses terbatas, bukan
  root, mengikuti prinsip *least privilege*.
