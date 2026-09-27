# 03 — Data Profiling

## Input
- Table `sales_raw` (hasil Tahap 3, lihat `docs/02_data_collection.md`)
- Dijalankan via `sql/03_data_profiling.sql`

## Proses Analisis
1. Intip sample nilai `order_date` dan `Waktu Pesanan Dibuat` untuk cek format tanggal sebelum di-cast.
2. Hitung missing value per kolom.
3. Cek overlap missing antara `total_qty` dan `Metode Pembayaran`.
4. Generate seluruh bulan dari min–max tanggal, cek bulan mana yang 0 baris total (missing period, bukan sekadar 0 transaksi).
5. Distribusi kolom kategorikal: `Status Pesanan`, `Alasan Pembatalan`, `Metode Pembayaran`, `Opsi Pengiriman`, `Provinsi`.
6. Cek anomali `flag_selesai_bayar_nol` (`Status Pesanan = 'Selesai'` tapi `Total Pembayaran = 0`).
7. Cek outlier kasar `total_qty` (min/max/avg/median).

## Temuan
- **Missing value:** `total_qty` 283, `Metode Pembayaran` 283, overlap keduanya 3 baris (independen). `order_date` 188 missing — **temuan baru**, tidak ada di referensi lama.
- **Format tanggal:** `order_date` = `DD/MM/YYYY` (ambigu untuk hari ≤12, DuckDB bisa salah interpretasi jadi `MM/DD/YYYY`). `Waktu Pesanan Dibuat` = timestamp ISO `yyyy-mm-dd HH:MM`, **0 missing**, tidak ambigu.
- **Missing period:** Desember 2024 dan Juli 2025 = 0 baris total, terkonfirmasi (24 bulan dicek, hanya 2 bulan itu yang kosong).
- **Status Pesanan:** 11 nilai unik, didominasi `Selesai` (85,04%) dan `Batal` (13,64%). 6 varian teks "Pesanan diterima, namun ... hingga tanggal X" (total 161 baris) — tanggal deadline retur berbeda-beda tercatat sebagai status terpisah.
- **Alasan Pembatalan:** 19 nilai unik, jumlah baris dengan alasan ≠ "Tidak dibatalkan" = 2.573, cocok persis dengan jumlah `Status Pesanan = 'Batal'`.
- **Metode Pembayaran:** 20 nilai unik dengan banyak duplikat varian kapitalisasi/spasi (COD punya 3 varian, ShopeePay 3 varian, Online Payment 3 varian, SPayLater 2 varian).
- **Opsi Pengiriman:** 45 nilai unik, granular (gabungan tier layanan + kurir).
- **Provinsi:** Jawa Barat penyumbang order terbanyak (6.078), diikuti Banten (3.281) dan DKI Jakarta (2.667).
- **flag_selesai_bayar_nol:** 56 baris — cocok dengan referensi lama.
- **Outlier total_qty:** min 1, max 256, median 1, rata-rata 2,57.

## Output
- Tidak ada table baru — seluruhnya query eksploratif (read-only) terhadap `sales_raw`.

## Assumptions
- Kolom `Waktu Pesanan Dibuat` diasumsikan sebagai sumber tanggal yang lebih andal dibanding `order_date` untuk seluruh analisis time-series berikutnya, karena formatnya tidak ambigu dan tanpa missing value.
- Missing period (Des 2024, Jul 2025) diasumsikan struktural pada dataset (bukan error ingestion), mengikuti keputusan yang sudah dikunci di `docs/business_understanding.md`.

## Kesimpulan
Semua angka utama (missing value, missing period, flag_selesai_bayar_nol) konsisten dengan referensi lama — data terverifikasi ulang. Namun profiling ini menemukan 3 hal baru yang harus ditangani di Tahap 5 (Cleaning): (1) `order_date` punya 188 missing dan format ambigu → pakai `Waktu Pesanan Dibuat` sebagai source tanggal utama, (2) `Metode Pembayaran` perlu dinormalisasi (banyak varian duplikat), (3) 6 varian status "window retur" perlu dikonsolidasi jadi satu kategori.
