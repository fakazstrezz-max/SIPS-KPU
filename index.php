<?php
// Railway/Railpack menjalankan proyek PHP lewat FrankenPHP dan mencari index.php
// sebagai pintu masuk. File ini hanya menampilkan isi index.html apa adanya,
// supaya aplikasi tetap bisa diakses langsung dari alamat utama (/) tanpa
// perlu mengetik /index.html secara manual.
readfile(__DIR__ . '/index.html');
