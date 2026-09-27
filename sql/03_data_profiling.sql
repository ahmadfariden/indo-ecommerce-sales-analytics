-- ============================================================
-- File   : sql/03_data_profiling.sql
-- Tujuan : Tahap 4 — Data Profiling: missing value, missing period,
--          distribusi kolom kategorikal, cek anomali revenue-zero
-- Status : eksekusi ulang dari Fase 0, verifikasi angka terhadap referensi
-- Prasyarat : sql/02_data_collection.sql sudah dijalankan (table sales_raw ada)
-- ============================================================

-- ------------------------------------------------------------
-- 0. Intip format kolom tanggal dulu (sebelum di-cast)
--    order_date vs "Waktu Pesanan Dibuat" — cek mana yang date murni
--    dan mana yang timestamp, serta format pemisahnya.
-- ------------------------------------------------------------
SELECT DISTINCT order_date FROM sales_raw ORDER BY 1 LIMIT 5;
SELECT DISTINCT "Waktu Pesanan Dibuat" FROM sales_raw ORDER BY 1 LIMIT 5;

-- ------------------------------------------------------------
-- 1. Missing value per kolom
-- ------------------------------------------------------------
SELECT 'order_id' AS column_name, COUNT(*) - COUNT(order_id) AS missing_count FROM sales_raw
UNION ALL SELECT 'total_qty', COUNT(*) - COUNT(total_qty) FROM sales_raw
UNION ALL SELECT 'total_weight_gr', COUNT(*) - COUNT(total_weight_gr) FROM sales_raw
UNION ALL SELECT 'total_returned_qty', COUNT(*) - COUNT(total_returned_qty) FROM sales_raw
UNION ALL SELECT 'Total Diskon', COUNT(*) - COUNT("Total Diskon") FROM sales_raw
UNION ALL SELECT 'product_categories', COUNT(*) - COUNT(product_categories) FROM sales_raw
UNION ALL SELECT 'num_product_categories', COUNT(*) - COUNT(num_product_categories) FROM sales_raw
UNION ALL SELECT 'Status Pesanan', COUNT(*) - COUNT("Status Pesanan") FROM sales_raw
UNION ALL SELECT 'Alasan Pembatalan', COUNT(*) - COUNT("Alasan Pembatalan") FROM sales_raw
UNION ALL SELECT 'Opsi Pengiriman', COUNT(*) - COUNT("Opsi Pengiriman") FROM sales_raw
UNION ALL SELECT 'Metode Pembayaran', COUNT(*) - COUNT("Metode Pembayaran") FROM sales_raw
UNION ALL SELECT 'Kota/Kabupaten', COUNT(*) - COUNT("Kota/Kabupaten") FROM sales_raw
UNION ALL SELECT 'Provinsi', COUNT(*) - COUNT("Provinsi") FROM sales_raw
UNION ALL SELECT 'Ongkos Kirim Dibayar oleh Pembeli', COUNT(*) - COUNT("Ongkos Kirim Dibayar oleh Pembeli") FROM sales_raw
UNION ALL SELECT 'Estimasi Potongan Biaya Pengiriman', COUNT(*) - COUNT("Estimasi Potongan Biaya Pengiriman") FROM sales_raw
UNION ALL SELECT 'Total Pembayaran', COUNT(*) - COUNT("Total Pembayaran") FROM sales_raw
UNION ALL SELECT 'Perkiraan Ongkos Kirim', COUNT(*) - COUNT("Perkiraan Ongkos Kirim") FROM sales_raw
UNION ALL SELECT 'Waktu Pesanan Dibuat', COUNT(*) - COUNT("Waktu Pesanan Dibuat") FROM sales_raw
UNION ALL SELECT 'order_date', COUNT(*) - COUNT(order_date) FROM sales_raw
ORDER BY missing_count DESC;

-- ------------------------------------------------------------
-- 2. Overlap missing antara total_qty & Metode Pembayaran
--    (referensi: 283 baris masing-masing, overlap cuma 3 baris -> independen)
-- ------------------------------------------------------------
SELECT
  SUM(CASE WHEN total_qty IS NULL THEN 1 ELSE 0 END) AS missing_total_qty,
  SUM(CASE WHEN "Metode Pembayaran" IS NULL THEN 1 ELSE 0 END) AS missing_metode_pembayaran,
  SUM(CASE WHEN total_qty IS NULL AND "Metode Pembayaran" IS NULL THEN 1 ELSE 0 END) AS overlap_both_missing
FROM sales_raw;

-- ------------------------------------------------------------
-- 3. Missing period check — bulan mana yang 0 baris total
--    (referensi: Desember 2024 & Juli 2025 harus hilang total)
--    NOTE: sesuaikan TRY_CAST/STRPTIME di bawah kalau hasil section 0
--    menunjukkan order_date bukan format ISO (yyyy-mm-dd).
-- ------------------------------------------------------------
WITH parsed AS (
  SELECT TRY_CAST(order_date AS DATE) AS order_date_parsed
  FROM sales_raw
),
month_range AS (
  SELECT
    date_trunc('month', MIN(order_date_parsed)) AS min_month,
    date_trunc('month', MAX(order_date_parsed)) AS max_month
  FROM parsed
),
all_months AS (
  SELECT unnest(generate_series(
    (SELECT min_month FROM month_range),
    (SELECT max_month FROM month_range),
    INTERVAL 1 MONTH
  )) AS month_start
),
actual_counts AS (
  SELECT date_trunc('month', order_date_parsed) AS month_start, COUNT(*) AS row_count
  FROM parsed
  WHERE order_date_parsed IS NOT NULL
  GROUP BY 1
)
SELECT
  strftime(m.month_start, '%Y-%m') AS bulan,
  COALESCE(a.row_count, 0) AS jumlah_baris,
  CASE WHEN a.row_count IS NULL THEN 'MISSING PERIOD' ELSE 'ada data' END AS status
FROM all_months m
LEFT JOIN actual_counts a ON m.month_start = a.month_start
ORDER BY m.month_start;

-- ------------------------------------------------------------
-- 4. Distribusi kolom kategorikal utama
-- ------------------------------------------------------------
SELECT "Status Pesanan", COUNT(*) AS jumlah, ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM sales_raw GROUP BY 1 ORDER BY jumlah DESC;

SELECT "Alasan Pembatalan", COUNT(*) AS jumlah
FROM sales_raw WHERE "Alasan Pembatalan" IS NOT NULL
GROUP BY 1 ORDER BY jumlah DESC;

SELECT "Metode Pembayaran", COUNT(*) AS jumlah, ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM sales_raw GROUP BY 1 ORDER BY jumlah DESC;

SELECT "Opsi Pengiriman", COUNT(*) AS jumlah
FROM sales_raw GROUP BY 1 ORDER BY jumlah DESC;

SELECT "Provinsi", COUNT(*) AS jumlah
FROM sales_raw GROUP BY 1 ORDER BY jumlah DESC LIMIT 15;

-- ------------------------------------------------------------
-- 5. Anomali flag_selesai_bayar_nol
--    (referensi: 56 baris Status = Selesai tapi Total Pembayaran = 0)
-- ------------------------------------------------------------
SELECT COUNT(*) AS flag_selesai_bayar_nol
FROM sales_raw
WHERE "Status Pesanan" = 'Selesai'
  AND TRY_CAST("Total Pembayaran" AS DOUBLE) = 0;

-- ------------------------------------------------------------
-- 6. Outlier check kasar untuk total_qty (referensi: outlier di-retain, didokumentasikan)
-- ------------------------------------------------------------
SELECT
  MIN(TRY_CAST(total_qty AS DOUBLE)) AS min_qty,
  MAX(TRY_CAST(total_qty AS DOUBLE)) AS max_qty,
  AVG(TRY_CAST(total_qty AS DOUBLE)) AS avg_qty,
  MEDIAN(TRY_CAST(total_qty AS DOUBLE)) AS median_qty
FROM sales_raw;
