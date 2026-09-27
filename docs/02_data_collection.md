# 02 — Data Collection

## Input
- `data/raw/indonesia_ecommerce_sales_challenging.csv` (source of truth, read-only)
- Dijalankan via `sql/02_data_collection.sql`

## Proses Analisis
- Ingest CSV apa adanya ke DuckDB (`indo.duckdb`) sebagai table `sales_raw`, seluruh kolom dipaksa `VARCHAR` (`ALL_VARCHAR=TRUE`) supaya tidak ada type-inference otomatis yang menyembunyikan masalah data.
- Hitung total baris, total kolom, dan cek duplikat baris penuh.
- Inspeksi struktur kolom (`DESCRIBE`).

## Temuan
- Total baris: **18.868**
- Total kolom: **19**
- Duplikat baris penuh: **0**
- Struktur kolom campuran: sebagian snake_case Inggris (`order_id`, `total_qty`, `total_weight_gr`, `total_returned_qty`, `product_categories`, `num_product_categories`, `order_date`), sebagian nama Indonesia berspasi (`Total Diskon`, `Status Pesanan`, `Alasan Pembatalan`, `Opsi Pengiriman`, `Metode Pembayaran`, `Kota/Kabupaten`, `Provinsi`, `Ongkos Kirim Dibayar oleh Pembeli`, `Estimasi Potongan Biaya Pengiriman`, `Total Pembayaran`, `Perkiraan Ongkos Kirim`, `Waktu Pesanan Dibuat`) — kolom berspasi wajib di-quote `"..."` di query berikutnya.

## Output
- Table DuckDB `sales_raw` di `indo.duckdb` (19 kolom, semua `VARCHAR`, 18.868 baris)

## Assumptions
- CSV di `data/raw/` adalah versi final/tidak berubah selama proyek berjalan.
- Semua kolom sengaja diload sebagai `VARCHAR` dulu — casting ke tipe data asli dilakukan belakangan di Tahap 5 (Cleaning), bukan di tahap ini, supaya nilai mentah yang tidak bisa di-cast (mis. format angka/​tanggal aneh) tetap kelihatan dulu di Profiling.

## Kesimpulan
Data berhasil masuk utuh tanpa duplikat baris. Angka ini identik dengan referensi hasil eksekusi versi lama roadmap (18.868 baris, 19 kolom, 0 duplikat) — dataset dipastikan konsisten sebelum lanjut ke Profiling.
