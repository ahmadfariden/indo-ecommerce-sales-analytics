# 04 — Data Cleaning

## Input
- Table `sales_raw` (hasil Tahap 3)
- Temuan Tahap 4 (lihat `docs/03_data_profiling.md`)
- Dijalankan via `sql/04_data_cleaning.sql`

## Proses Analisis
1. Casting seluruh kolom numerik dari `VARCHAR` ke tipe data asli (`TRY_CAST`, bukan `CAST`, supaya nilai yang gagal di-cast jadi `NULL` alih-alih error).
2. Konsolidasi 6 varian teks `Status Pesanan` ("Pesanan diterima, namun ... hingga tanggal X") jadi satu kategori `Diterima (window retur)`.
3. Normalisasi `Metode Pembayaran` — 20 varian mentah dipetakan ke kategori kanonik (COD, ShopeePay, Online Payment, SPayLater, Kartu Kredit/Debit, dll), `NULL` dipetakan eksplisit ke `'Tidak Diketahui'`.
4. Ganti source tanggal dari `order_date` (ambigu, 188 missing) ke `Waktu Pesanan Dibuat` → hasilkan `waktu_pesanan_dibuat`, `order_date_clean`, `order_month`.
5. Tandai (bukan hapus) baris anomali dengan dua kolom flag: `flag_qty_missing` dan `flag_selesai_bayar_nol`.
6. Rename seluruh kolom berspasi ke snake_case.
7. Validasi pasca cleaning: row count, distribusi kategori baru, jumlah flag, missing `order_date_clean`, dan re-check missing period pakai kolom tanggal baru.

## Temuan
- Row count tetap **18.868** setelah cleaning — tidak ada baris hilang/bertambah.
- `order_date_clean` (dari `Waktu Pesanan Dibuat`) **0 missing** — berhasil menutup gap 188 missing yang ada di `order_date` lama.
- Re-check missing period pakai `order_month` yang baru tetap menunjukkan Desember 2024 dan Juli 2025 = 0 baris — konsisten dengan Tahap 4, sekaligus jadi bukti tambahan bahwa `order_date` lama tidak salah menggeser bulan secara sistematis untuk kasus ini.
- Jumlah `flag_qty_missing` = 283 dan `flag_selesai_bayar_nol` = 56 — cocok dengan angka profiling.
- Kategori `Metode Pembayaran` menyusut dari 20 nilai unik jadi kategori kanonik yang jauh lebih sedikit.
- Kategori `Status Pesanan` menyusut dari 11 nilai unik jadi kategori yang lebih rapi, dengan `Diterima (window retur)` = 161 baris (gabungan 6 varian lama: 38+34+34+25+22+6+2).
- **Validasi tambahan (penting):** total baris per-bulan dari `order_month` (baru) berjumlah 18.868, sementara total dari distribusi bulanan lama (`order_date`, Tahap 4) hanya 18.275 — selisih **593 baris**, jauh lebih besar dari 188 baris yang dulu murni missing. Ini mengindikasikan sekitar 405 baris lain dulu ter-bucket ke bulan yang salah akibat ambiguitas format `DD/MM/YYYY` di `order_date`. Temuan ini memperkuat keputusan memakai `Waktu Pesanan Dibuat` sebagai source tanggal tunggal — tren bulanan dari `order_date` lama tidak boleh dipakai lagi di analisis manapun.

## Output
- Table DuckDB `sales` (bersih, tipe data sudah benar, 18.868 baris, siap dipakai Tahap 6 Validation & Tahap 7 EDA)

## Assumptions
- `Waktu Pesanan Dibuat` dianggap 100% akurat sebagai waktu order dibuat; `order_date` lama tidak dipakai lagi di analisis manapun setelah tahap ini (tidak di-drop dari `sales_raw`, tapi tidak dibawa ke `sales`).
- Baris dengan `total_qty` NULL **tidak** diisi (imputasi) dengan 0 atau median — dibiarkan NULL dan ditandai `flag_qty_missing`, supaya agregasi qty (SUM/AVG) secara otomatis mengecualikannya tanpa keputusan tersembunyi.
- Baris `flag_selesai_bayar_nol` (56 baris) tetap dihitung sebagai order Selesai dengan revenue 0 — bukan di-exclude dari count order, sesuai keputusan yang sudah dikunci sebelumnya (lihat Ringkasan Adaptasi di roadmap).
- Normalisasi `Metode Pembayaran` menggabungkan `Kartu Kredit/Debit` dan `Cicilan Kartu Kredit` jadi satu kategori karena `Cicilan Kartu Kredit` cuma 3 baris — keputusan simplifikasi, didokumentasikan di sini supaya bisa di-split lagi kalau ternyata dibutuhkan analisis terpisah nanti.
- Kolom `Opsi Pengiriman` (45 nilai unik) **belum** diparsing/disederhanakan di tahap ini — dibiarkan granular apa adanya, karena parsing tier layanan vs kurir lebih tepat dilakukan nanti di Tahap 13 (Shipping Behavior) supaya konteks bisnisnya jelas.

## Kesimpulan
Table `sales` berhasil dibentuk dari `sales_raw` tanpa kehilangan baris, dengan seluruh anomali yang ditemukan di profiling ditangani lewat normalisasi kategori dan flag eksplisit (bukan penghapusan diam-diam). Table ini sudah siap dipakai sebagai basis untuk Tahap 6 (Data Validation) dan seluruh analisis bisnis di Part 2 dan seterusnya.
