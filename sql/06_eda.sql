-- ============================================================
-- File   : sql/06_eda.sql
-- Tujuan : Tahap 7 — EDA: eksplorasi pola data sebelum dimensional
--          modeling. Pakai definisi Analytical Population dari
--          Tahap 6 (Total/Completed/Cancelled/In-Progress Orders).
-- Prasyarat : sql/05_data_validation.sql sudah dijalankan (table sales ada)
-- ============================================================

-- ------------------------------------------------------------
-- 1. Overview KPI ringkas
-- ------------------------------------------------------------
SELECT
  COUNT(*) AS total_orders,
  SUM(CASE WHEN status_pesanan = 'Selesai' THEN 1 ELSE 0 END) AS completed_orders,
  SUM(CASE WHEN status_pesanan = 'Batal' THEN 1 ELSE 0 END) AS cancelled_orders,
  ROUND(100.0 * SUM(CASE WHEN status_pesanan = 'Batal' THEN 1 ELSE 0 END) / COUNT(*), 2) AS cancellation_rate_pct,
  ROUND(SUM(CASE WHEN status_pesanan = 'Selesai' THEN total_pembayaran ELSE 0 END), 0) AS revenue_completed,
  ROUND(SUM(CASE WHEN status_pesanan = 'Selesai' THEN total_pembayaran ELSE 0 END)
        / NULLIF(SUM(CASE WHEN status_pesanan = 'Selesai' THEN 1 ELSE 0 END), 0), 0) AS aov_proxy,
  SUM(CASE WHEN status_pesanan = 'Selesai' AND total_returned_qty > 0 THEN 1 ELSE 0 END) AS completed_with_return,
  ROUND(100.0 * SUM(CASE WHEN status_pesanan = 'Selesai' AND total_returned_qty > 0 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN status_pesanan = 'Selesai' THEN 1 ELSE 0 END), 0), 2) AS return_rate_pct
FROM sales;

-- ------------------------------------------------------------
-- 2. Tren bulanan — order count & revenue (missing period tetap tampil 0)
-- ------------------------------------------------------------
SELECT
  strftime(order_month, '%Y-%m') AS bulan,
  COUNT(*) AS jumlah_order,
  ROUND(SUM(CASE WHEN status_pesanan = 'Selesai' THEN total_pembayaran ELSE 0 END), 0) AS revenue_completed
FROM sales
GROUP BY 1
ORDER BY 1;

-- ------------------------------------------------------------
-- 3. Revenue & cancellation rate per Status Pesanan
-- ------------------------------------------------------------
SELECT
  status_pesanan,
  COUNT(*) AS jumlah_order,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_order,
  ROUND(SUM(total_pembayaran), 0) AS total_revenue
FROM sales
GROUP BY 1
ORDER BY jumlah_order DESC;

-- ------------------------------------------------------------
-- 4. Revenue & cancellation rate per Metode Pembayaran
-- ------------------------------------------------------------
SELECT
  metode_pembayaran,
  COUNT(*) AS jumlah_order,
  SUM(CASE WHEN status_pesanan = 'Batal' THEN 1 ELSE 0 END) AS jumlah_batal,
  ROUND(100.0 * SUM(CASE WHEN status_pesanan = 'Batal' THEN 1 ELSE 0 END) / COUNT(*), 2) AS cancellation_rate_pct,
  ROUND(SUM(CASE WHEN status_pesanan = 'Selesai' THEN total_pembayaran ELSE 0 END), 0) AS revenue_completed
FROM sales
GROUP BY 1
ORDER BY jumlah_order DESC;

-- ------------------------------------------------------------
-- 5. Top 10 Provinsi by order & revenue (Completed Orders)
-- ------------------------------------------------------------
SELECT
  provinsi,
  COUNT(*) AS jumlah_order,
  SUM(CASE WHEN status_pesanan = 'Selesai' THEN 1 ELSE 0 END) AS completed_orders,
  ROUND(SUM(CASE WHEN status_pesanan = 'Selesai' THEN total_pembayaran ELSE 0 END), 0) AS revenue_completed,
  ROUND(100.0 * SUM(CASE WHEN status_pesanan = 'Batal' THEN 1 ELSE 0 END) / COUNT(*), 2) AS cancellation_rate_pct
FROM sales
GROUP BY 1
ORDER BY jumlah_order DESC
LIMIT 10;

-- ------------------------------------------------------------
-- 6. Distribusi num_product_categories — single vs multi-category order
-- ------------------------------------------------------------
SELECT
  num_product_categories,
  COUNT(*) AS jumlah_order,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_order,
  ROUND(AVG(total_qty), 2) AS avg_qty_per_order
FROM sales
WHERE num_product_categories IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- ------------------------------------------------------------
-- 7. Pola grosir — rata-rata & percentile total_qty per bucket kategori
-- ------------------------------------------------------------
SELECT
  CASE
    WHEN total_qty IS NULL THEN 'Unknown'
    WHEN total_qty <= 2 THEN '1-2 (retail kecil)'
    WHEN total_qty <= 5 THEN '3-5'
    WHEN total_qty <= 10 THEN '6-10'
    ELSE '11+ (indikasi grosir)'
  END AS qty_bucket,
  COUNT(*) AS jumlah_order,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_order
FROM sales
GROUP BY 1
ORDER BY jumlah_order DESC;

-- ------------------------------------------------------------
-- 8. Shipping: distribusi opsi pengiriman (top 15) + rata-rata ongkir
-- ------------------------------------------------------------
SELECT
  opsi_pengiriman,
  COUNT(*) AS jumlah_order,
  ROUND(AVG(ongkir_dibayar_pembeli), 0) AS avg_ongkir_dibayar_pembeli,
  ROUND(AVG(perkiraan_ongkos_kirim), 0) AS avg_perkiraan_ongkos_kirim
FROM sales
GROUP BY 1
ORDER BY jumlah_order DESC
LIMIT 15;

-- ------------------------------------------------------------
-- 9. Hubungan ongkir dibayar pembeli vs total pembayaran (deskriptif, non-causal)
-- ------------------------------------------------------------
SELECT
  ROUND(CORR(ongkir_dibayar_pembeli, total_pembayaran), 4) AS korelasi_ongkir_vs_total_pembayaran
FROM sales
WHERE ongkir_dibayar_pembeli IS NOT NULL AND total_pembayaran IS NOT NULL;

-- Bucket total_pembayaran, lihat rata-rata ongkir per bucket
SELECT
  CASE
    WHEN total_pembayaran < 50000 THEN '< 50rb'
    WHEN total_pembayaran < 150000 THEN '50rb - 150rb'
    WHEN total_pembayaran < 300000 THEN '150rb - 300rb'
    WHEN total_pembayaran < 500000 THEN '300rb - 500rb'
    ELSE '>= 500rb'
  END AS bucket_total_pembayaran,
  COUNT(*) AS jumlah_order,
  ROUND(AVG(ongkir_dibayar_pembeli), 0) AS avg_ongkir_dibayar_pembeli
FROM sales
WHERE total_pembayaran IS NOT NULL
GROUP BY 1
ORDER BY MIN(total_pembayaran);

-- ------------------------------------------------------------
-- 10. Ringkasan distribusi (quantile) kolom numerik utama
-- ------------------------------------------------------------
SELECT
  'total_qty' AS kolom,
  MIN(total_qty) AS min, QUANTILE_CONT(total_qty, 0.25) AS p25,
  QUANTILE_CONT(total_qty, 0.5) AS median, QUANTILE_CONT(total_qty, 0.75) AS p75,
  MAX(total_qty) AS max
FROM sales
UNION ALL
SELECT
  'total_pembayaran',
  MIN(total_pembayaran), QUANTILE_CONT(total_pembayaran, 0.25),
  QUANTILE_CONT(total_pembayaran, 0.5), QUANTILE_CONT(total_pembayaran, 0.75),
  MAX(total_pembayaran)
FROM sales
UNION ALL
SELECT
  'ongkir_dibayar_pembeli',
  MIN(ongkir_dibayar_pembeli), QUANTILE_CONT(ongkir_dibayar_pembeli, 0.25),
  QUANTILE_CONT(ongkir_dibayar_pembeli, 0.5), QUANTILE_CONT(ongkir_dibayar_pembeli, 0.75),
  MAX(ongkir_dibayar_pembeli)
FROM sales;
