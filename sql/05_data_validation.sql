-- ============================================================
-- File   : sql/05_data_validation.sql
-- Tujuan : Tahap 6 — Data Validation: validasi analytical population
--          pasca cleaning, reconciliation raw vs clean, konsistensi
--          logika bisnis, dan definisi population yang dipakai di
--          seluruh tahap analisis berikutnya
-- Prasyarat : sql/04_data_cleaning.sql sudah dijalankan (table sales ada)
-- ============================================================

-- ------------------------------------------------------------
-- 1. Reconciliation: raw vs clean
-- ------------------------------------------------------------

-- Row count harus identik
SELECT
  (SELECT COUNT(*) FROM sales_raw) AS rows_raw,
  (SELECT COUNT(*) FROM sales)     AS rows_clean;

-- Revenue reconciliation: SUM Total Pembayaran raw (setelah cast) vs clean
SELECT
  (SELECT SUM(TRY_CAST("Total Pembayaran" AS DOUBLE)) FROM sales_raw) AS revenue_raw,
  (SELECT SUM(total_pembayaran) FROM sales) AS revenue_clean;

-- Order ID harus tetap unik (tidak ada order_id yang hilang/duplikat gara-gara cleaning)
SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT order_id) AS distinct_order_id
FROM sales;

-- ------------------------------------------------------------
-- 2. Analytical Population — definisi denominator untuk KPI berikutnya
-- ------------------------------------------------------------

SELECT
  COUNT(*) AS total_orders,
  SUM(CASE WHEN status_pesanan = 'Selesai' THEN 1 ELSE 0 END) AS completed_orders,
  SUM(CASE WHEN status_pesanan = 'Batal' THEN 1 ELSE 0 END) AS cancelled_orders,
  SUM(CASE WHEN status_pesanan NOT IN ('Selesai', 'Batal') THEN 1 ELSE 0 END) AS in_progress_orders
FROM sales;

-- ------------------------------------------------------------
-- 3. Konsistensi logika bisnis
-- ------------------------------------------------------------

-- Setiap baris Batal harus punya alasan_pembatalan != 'Tidak dibatalkan', dan sebaliknya
SELECT
  SUM(CASE WHEN status_pesanan = 'Batal' AND alasan_pembatalan = 'Tidak dibatalkan' THEN 1 ELSE 0 END)
    AS batal_tanpa_alasan_flag,
  SUM(CASE WHEN status_pesanan != 'Batal' AND alasan_pembatalan != 'Tidak dibatalkan' THEN 1 ELSE 0 END)
    AS ada_alasan_tapi_bukan_batal
FROM sales;

-- flag_selesai_bayar_nol harus SELALU dalam status Selesai (by construction di Tahap 5,
-- ini query untuk membuktikan invariant-nya, bukan menemukan hal baru)
SELECT COUNT(*) AS flag_di_luar_status_selesai
FROM sales
WHERE flag_selesai_bayar_nol = TRUE AND status_pesanan != 'Selesai';

-- total_returned_qty tidak boleh melebihi total_qty (baris dengan qty tidak NULL)
SELECT COUNT(*) AS returned_qty_melebihi_total_qty
FROM sales
WHERE total_qty IS NOT NULL
  AND total_returned_qty IS NOT NULL
  AND total_returned_qty > total_qty;

-- num_product_categories vs jumlah kategori aktual di product_categories (dipisah koma)
SELECT COUNT(*) AS mismatch_num_product_categories
FROM sales
WHERE num_product_categories IS NOT NULL
  AND product_categories IS NOT NULL
  AND num_product_categories != (LENGTH(product_categories) - LENGTH(REPLACE(product_categories, ',', '')) + 1);

-- ------------------------------------------------------------
-- 4. Cek nilai negatif di kolom numerik (tidak boleh ada)
-- ------------------------------------------------------------
SELECT
  SUM(CASE WHEN total_qty < 0 THEN 1 ELSE 0 END)              AS neg_total_qty,
  SUM(CASE WHEN total_weight_gr < 0 THEN 1 ELSE 0 END)        AS neg_total_weight_gr,
  SUM(CASE WHEN total_returned_qty < 0 THEN 1 ELSE 0 END)     AS neg_total_returned_qty,
  SUM(CASE WHEN total_diskon < 0 THEN 1 ELSE 0 END)           AS neg_total_diskon,
  SUM(CASE WHEN ongkir_dibayar_pembeli < 0 THEN 1 ELSE 0 END) AS neg_ongkir_dibayar_pembeli,
  SUM(CASE WHEN total_pembayaran < 0 THEN 1 ELSE 0 END)       AS neg_total_pembayaran,
  SUM(CASE WHEN perkiraan_ongkos_kirim < 0 THEN 1 ELSE 0 END) AS neg_perkiraan_ongkos_kirim
FROM sales;

-- ------------------------------------------------------------
-- 5. Cek konsistensi kategori teks (kandidat duplikat karena kapitalisasi/spasi)
-- ------------------------------------------------------------
SELECT provinsi, COUNT(*) AS jumlah
FROM sales GROUP BY 1 ORDER BY 1;

SELECT COUNT(*) AS kota_null, COUNT(*) FILTER (WHERE kota_kabupaten IS NULL) AS jumlah_null
FROM sales;

-- ------------------------------------------------------------
-- 6. Sanity check rentang tanggal
-- ------------------------------------------------------------
SELECT MIN(order_date_clean) AS tanggal_paling_awal, MAX(order_date_clean) AS tanggal_paling_akhir
FROM sales;
