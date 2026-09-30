-- ============================================================
-- File   : sql/13_marts.sql
-- Tujuan : Tahap 14 — Data Mart: rangkum temuan Tahap 9-13 jadi
--          table siap pakai untuk dashboard Power BI. Setiap mart
--          denormalized (nama, bukan cuma key) supaya Power BI tidak
--          perlu banyak relasi, dan sudah pre-agregat di grain yang
--          wajar untuk visual.
-- Prasyarat : sql/07_data_modeling.sql (star schema) dan
--             sql/10_regional_performance.sql (view v_orders_region,
--             untuk mart_regional_province) dan
--             sql/12_shipping_behavior.sql (view v_shipping_parsed,
--             untuk mart_shipping_*) sudah dijalankan.
--
-- Catatan yang dibawa dari tahap sebelumnya (jangan diubah tanpa alasan):
--  * Cancellation rate = Batal / Total Orders; return rate = Completed
--    dengan retur / Completed Orders (Tahap 6).
--  * November 2025 belum matang (250 order In-Progress, Tahap 9) ->
--    mart_monthly_trend punya flag is_incomplete_month.
--  * mart_category HANYA order single-category (92,76% order) supaya
--    revenue tidak dobel-hitung (Tahap 12); jangan dijumlah dengan
--    revenue lain sebagai "total revenue perusahaan".
-- ============================================================

.mode markdown

-- ============================================================
-- 1. mart_overview_kpi — scorecard satu baris untuk halaman ringkasan
-- ============================================================
CREATE OR REPLACE TABLE mart_overview_kpi AS
SELECT
  COUNT(*) AS total_orders,
  SUM(CASE WHEN st.status_group = 'Completed' THEN 1 ELSE 0 END) AS completed_orders,
  SUM(CASE WHEN st.status_group = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_orders,
  SUM(CASE WHEN st.status_group = 'In-Progress' THEN 1 ELSE 0 END) AS in_progress_orders,
  ROUND(100.0 * SUM(CASE WHEN st.status_group = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS cancellation_rate_pct,
  ROUND(SUM(CASE WHEN st.status_group = 'Completed' THEN f.total_pembayaran ELSE 0 END), 0)
    AS revenue_completed,
  ROUND(SUM(CASE WHEN st.status_group = 'Completed' THEN f.total_pembayaran ELSE 0 END)
        / NULLIF(SUM(CASE WHEN st.status_group = 'Completed' THEN 1 ELSE 0 END), 0), 0) AS aov_completed,
  SUM(CASE WHEN st.status_group = 'Completed' AND f.total_returned_qty > 0 THEN 1 ELSE 0 END)
    AS completed_dengan_retur,
  ROUND(100.0 * SUM(CASE WHEN st.status_group = 'Completed' AND f.total_returned_qty > 0 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN st.status_group = 'Completed' THEN 1 ELSE 0 END), 0), 2) AS return_rate_pct,
  (SELECT MIN(full_date) FROM dim_date) AS periode_mulai,
  (SELECT MAX(full_date) FROM dim_date) AS periode_akhir
FROM fact_orders f
JOIN dim_status st ON st.status_key = f.status_key;

-- ============================================================
-- 2. mart_monthly_trend — tren bulanan untuk chart (Tahap 7 & 9)
--    is_incomplete_month = TRUE kalau bulan itu masih punya order In-Progress
--    (data-driven, bukan hardcode "November 2025")
-- ============================================================
CREATE OR REPLACE TABLE mart_monthly_trend AS
SELECT
  d.year_month,
  COUNT(*) AS jumlah_order,
  SUM(CASE WHEN st.status_group = 'Completed' THEN 1 ELSE 0 END) AS completed_orders,
  SUM(CASE WHEN st.status_group = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_orders,
  SUM(CASE WHEN st.status_group = 'In-Progress' THEN 1 ELSE 0 END) AS in_progress_orders,
  ROUND(SUM(CASE WHEN st.status_group = 'Completed' THEN f.total_pembayaran ELSE 0 END), 0)
    AS revenue_completed,
  ROUND(100.0 * SUM(CASE WHEN st.status_group = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS cancellation_rate_pct,
  ROUND(100.0 * SUM(CASE WHEN st.status_group = 'Completed' AND f.total_returned_qty > 0 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN st.status_group = 'Completed' THEN 1 ELSE 0 END), 0), 2) AS return_rate_pct,
  SUM(CASE WHEN st.status_group = 'In-Progress' THEN 1 ELSE 0 END) > 0 AS is_incomplete_month
FROM fact_orders f
JOIN dim_date d ON d.date_key = f.date_key
JOIN dim_status st ON st.status_key = f.status_key
GROUP BY 1
ORDER BY 1;

-- ============================================================
-- 3. mart_order_status — funnel status (Tahap 9)
-- ============================================================
CREATE OR REPLACE TABLE mart_order_status AS
SELECT
  st.status_pesanan,
  st.status_group,
  COUNT(*) AS jumlah_order,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_order,
  ROUND(SUM(f.total_pembayaran), 0) AS total_pembayaran
FROM fact_orders f
JOIN dim_status st ON st.status_key = f.status_key
GROUP BY 1, 2
ORDER BY jumlah_order DESC;

-- ============================================================
-- 4. mart_cancellation_reason — alasan pembatalan (Tahap 9)
-- ============================================================
CREATE OR REPLACE TABLE mart_cancellation_reason AS
SELECT
  cr.cancel_actor,
  cr.cancel_reason_group,
  COUNT(*) AS jumlah_order,
  ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM fact_orders f2
                             JOIN dim_status st2 ON st2.status_key = f2.status_key
                             WHERE st2.status_group = 'Cancelled'), 2) AS pct_dari_order_batal
FROM fact_orders f
JOIN dim_cancellation_reason cr ON cr.cancel_reason_key = f.cancel_reason_key
WHERE cr.cancel_actor <> 'Tidak Dibatalkan'
GROUP BY 1, 2
ORDER BY jumlah_order DESC;

-- ============================================================
-- 5. mart_payment_method — scorecard per metode (Tahap 10)
-- ============================================================
CREATE OR REPLACE TABLE mart_payment_method AS
SELECT
  pm.metode_pembayaran,
  pm.payment_group,
  COUNT(*) AS jumlah_order,
  SUM(CASE WHEN st.status_group = 'Completed' THEN 1 ELSE 0 END) AS completed_orders,
  ROUND(SUM(CASE WHEN st.status_group = 'Completed' THEN f.total_pembayaran ELSE 0 END), 0)
    AS revenue_completed,
  ROUND(SUM(CASE WHEN st.status_group = 'Completed' THEN f.total_pembayaran ELSE 0 END)
        / NULLIF(SUM(CASE WHEN st.status_group = 'Completed' THEN 1 ELSE 0 END), 0), 0) AS aov_completed,
  ROUND(100.0 * SUM(CASE WHEN st.status_group = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS cancellation_rate_pct,
  ROUND(100.0 * (SUM(CASE WHEN st.status_group = 'Cancelled' THEN 1 ELSE 0 END)
                 - SUM(CASE WHEN cr.cancel_reason_group = 'Pesanan belum dibayar' THEN 1 ELSE 0 END))
        / COUNT(*), 2) AS cancellation_rate_tanpa_belum_dibayar_pct,
  ROUND(100.0 * SUM(CASE WHEN st.status_group = 'Completed' AND f.total_returned_qty > 0 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN st.status_group = 'Completed' THEN 1 ELSE 0 END), 0), 2) AS return_rate_pct
FROM fact_orders f
JOIN dim_status st ON st.status_key = f.status_key
JOIN dim_cancellation_reason cr ON cr.cancel_reason_key = f.cancel_reason_key
JOIN dim_payment_method pm ON pm.payment_key = f.payment_key
GROUP BY 1, 2
ORDER BY jumlah_order DESC;

-- ============================================================
-- 6. mart_regional_province — semua provinsi (Tahap 11)
-- ============================================================
CREATE OR REPLACE TABLE mart_regional_province AS
SELECT
  provinsi,
  region_group,
  COUNT(*) AS jumlah_order,
  SUM(CASE WHEN status_group = 'Completed' THEN 1 ELSE 0 END) AS completed_orders,
  ROUND(SUM(CASE WHEN status_group = 'Completed' THEN total_pembayaran ELSE 0 END), 0) AS revenue_completed,
  ROUND(SUM(CASE WHEN status_group = 'Completed' THEN total_pembayaran ELSE 0 END)
        / NULLIF(SUM(CASE WHEN status_group = 'Completed' THEN 1 ELSE 0 END), 0), 0) AS aov_completed,
  ROUND(100.0 * SUM(CASE WHEN status_group = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS cancellation_rate_pct,
  ROUND(100.0 * SUM(CASE WHEN status_group = 'Completed' AND total_returned_qty > 0 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN status_group = 'Completed' THEN 1 ELSE 0 END), 0), 2) AS return_rate_pct,
  ROUND(100.0 * SUM(CASE WHEN payment_group = 'Cash on Delivery' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_cod
FROM v_orders_region
GROUP BY 1, 2
ORDER BY revenue_completed DESC;

-- ============================================================
-- 7. mart_regional_city — top 30 kota (Tahap 11)
-- ============================================================
CREATE OR REPLACE TABLE mart_regional_city AS
SELECT
  provinsi,
  kota_norm AS kota_kabupaten,
  COUNT(*) AS jumlah_order,
  SUM(CASE WHEN status_group = 'Completed' THEN 1 ELSE 0 END) AS completed_orders,
  ROUND(SUM(CASE WHEN status_group = 'Completed' THEN total_pembayaran ELSE 0 END), 0) AS revenue_completed,
  ROUND(SUM(CASE WHEN status_group = 'Completed' THEN total_pembayaran ELSE 0 END)
        / NULLIF(SUM(CASE WHEN status_group = 'Completed' THEN 1 ELSE 0 END), 0), 0) AS aov_completed,
  ROUND(100.0 * SUM(CASE WHEN status_group = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS cancellation_rate_pct,
  ROUND(100.0 * SUM(CASE WHEN payment_group = 'Cash on Delivery' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_cod
FROM v_orders_region
GROUP BY 1, 2
ORDER BY jumlah_order DESC
LIMIT 30;

-- ============================================================
-- 8. mart_category — HANYA order single-category (Tahap 12, B1)
-- ============================================================
CREATE OR REPLACE TABLE mart_category AS
WITH single_cat AS (
  SELECT f.order_id, f.total_pembayaran, f.total_qty, f.status_key, b.category_key
  FROM fact_orders f
  JOIN bridge_order_category b ON b.order_id = f.order_id
  WHERE f.num_product_categories = 1
)
SELECT
  c.category_name,
  COUNT(*) AS jumlah_order,
  SUM(CASE WHEN st.status_group = 'Completed' THEN 1 ELSE 0 END) AS completed_orders,
  ROUND(SUM(CASE WHEN st.status_group = 'Completed' THEN sc.total_pembayaran ELSE 0 END), 0)
    AS revenue_completed,
  ROUND(SUM(CASE WHEN st.status_group = 'Completed' THEN sc.total_pembayaran ELSE 0 END)
        / NULLIF(SUM(CASE WHEN st.status_group = 'Completed' THEN 1 ELSE 0 END), 0), 0) AS aov_completed,
  ROUND(100.0 * SUM(CASE WHEN st.status_group = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS cancellation_rate_pct,
  ROUND(AVG(sc.total_qty), 2) AS avg_qty
FROM single_cat sc
JOIN dim_category c ON c.category_key = sc.category_key
JOIN dim_status st ON st.status_key = sc.status_key
GROUP BY 1
ORDER BY revenue_completed DESC;

-- ============================================================
-- 9. mart_category_pair — top 20 pasangan co-occurrence (Tahap 12, D1)
-- ============================================================
CREATE OR REPLACE TABLE mart_category_pair AS
SELECT
  ca.category_name AS kategori_a,
  cb.category_name AS kategori_b,
  COUNT(*) AS jumlah_order_bersama
FROM bridge_order_category ba
JOIN bridge_order_category bb
  ON ba.order_id = bb.order_id AND ba.category_key < bb.category_key
JOIN dim_category ca ON ca.category_key = ba.category_key
JOIN dim_category cb ON cb.category_key = bb.category_key
GROUP BY 1, 2
ORDER BY jumlah_order_bersama DESC
LIMIT 20;

-- ============================================================
-- 10. mart_shipping_kurir — performa per kurir (Tahap 13, D & F)
-- ============================================================
CREATE OR REPLACE TABLE mart_shipping_kurir AS
SELECT
  v.kurir,
  COUNT(*) AS jumlah_order,
  SUM(CASE WHEN st.status_group = 'Completed' THEN 1 ELSE 0 END) AS completed_orders,
  ROUND(SUM(CASE WHEN st.status_group = 'Completed' THEN f.total_pembayaran ELSE 0 END), 0)
    AS revenue_completed,
  ROUND(SUM(CASE WHEN st.status_group = 'Completed' THEN f.total_pembayaran ELSE 0 END)
        / NULLIF(SUM(CASE WHEN st.status_group = 'Completed' THEN 1 ELSE 0 END), 0), 0) AS aov_completed,
  ROUND(100.0 * SUM(CASE WHEN st.status_group = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS cancellation_rate_pct,
  ROUND(100.0 * SUM(CASE WHEN st.status_group = 'Completed' AND f.total_returned_qty > 0 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN st.status_group = 'Completed' THEN 1 ELSE 0 END), 0), 2) AS return_rate_pct,
  ROUND(AVG(CASE WHEN st.status_group = 'Completed' THEN f.ongkir_dibayar_pembeli END), 0)
    AS avg_ongkir_dibayar,
  ROUND(100.0 * AVG(CASE WHEN st.status_group = 'Completed' THEN f.ongkir_dibayar_pembeli END)
        / NULLIF(AVG(CASE WHEN st.status_group = 'Completed' THEN f.perkiraan_ongkos_kirim END), 0), 2)
    AS pct_dibayar_dari_perkiraan,
  ROUND(AVG(CASE WHEN st.status_group = 'Completed' THEN f.total_weight_gr END), 0) AS avg_berat_gr
FROM fact_orders f
JOIN dim_status st ON st.status_key = f.status_key
JOIN v_shipping_parsed v ON v.shipping_key = f.shipping_key
GROUP BY 1
ORDER BY jumlah_order DESC;

-- ============================================================
-- 11. mart_shipping_region_failure — pengiriman gagal per kurir x wilayah
--     (Tahap 13, H; ambang >= 50 order dibawa dari analisis asal)
-- ============================================================
CREATE OR REPLACE TABLE mart_shipping_region_failure AS
SELECT
  vr.region_group,
  vs.kurir,
  COUNT(*) AS jumlah_order,
  SUM(CASE WHEN vr.cancel_reason_group = 'Pengiriman gagal' THEN 1 ELSE 0 END) AS pengiriman_gagal,
  ROUND(100.0 * SUM(CASE WHEN vr.cancel_reason_group = 'Pengiriman gagal' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS pct_pengiriman_gagal
FROM v_orders_region vr
JOIN fact_orders f ON f.order_id = vr.order_id
JOIN v_shipping_parsed vs ON vs.shipping_key = f.shipping_key
GROUP BY 1, 2
HAVING COUNT(*) >= 50
ORDER BY vr.region_group, jumlah_order DESC;

-- ============================================================
-- VALIDASI: setiap mart yang grain-nya "semua order" harus rekonsiliasi
-- dengan fact_orders (18.868). Mart yang scope-nya sengaja parsial
-- (single-category, top N, ambang minimum) TIDAK divalidasi ke 18.868.
-- ============================================================

SELECT 'mart_overview_kpi.total_orders' AS cek, total_orders AS nilai, 18868 AS ekspektasi
FROM mart_overview_kpi
UNION ALL
SELECT 'mart_monthly_trend SUM(jumlah_order)', SUM(jumlah_order), 18868 FROM mart_monthly_trend
UNION ALL
SELECT 'mart_order_status SUM(jumlah_order)', SUM(jumlah_order), 18868 FROM mart_order_status
UNION ALL
SELECT 'mart_payment_method SUM(jumlah_order)', SUM(jumlah_order), 18868 FROM mart_payment_method
UNION ALL
SELECT 'mart_regional_province SUM(jumlah_order)', SUM(jumlah_order), 18868 FROM mart_regional_province
UNION ALL
SELECT 'mart_shipping_kurir SUM(jumlah_order)', SUM(jumlah_order), 18868 FROM mart_shipping_kurir
UNION ALL
SELECT 'mart_cancellation_reason SUM(jumlah_order)', SUM(jumlah_order), 2573 FROM mart_cancellation_reason;

-- Jumlah baris tiap mart (konteks ukuran, bukan validasi benar/salah)
SELECT 'mart_overview_kpi' AS mart, COUNT(*) AS jumlah_baris FROM mart_overview_kpi
UNION ALL SELECT 'mart_monthly_trend', COUNT(*) FROM mart_monthly_trend
UNION ALL SELECT 'mart_order_status', COUNT(*) FROM mart_order_status
UNION ALL SELECT 'mart_cancellation_reason', COUNT(*) FROM mart_cancellation_reason
UNION ALL SELECT 'mart_payment_method', COUNT(*) FROM mart_payment_method
UNION ALL SELECT 'mart_regional_province', COUNT(*) FROM mart_regional_province
UNION ALL SELECT 'mart_regional_city', COUNT(*) FROM mart_regional_city
UNION ALL SELECT 'mart_category', COUNT(*) FROM mart_category
UNION ALL SELECT 'mart_category_pair', COUNT(*) FROM mart_category_pair
UNION ALL SELECT 'mart_shipping_kurir', COUNT(*) FROM mart_shipping_kurir
UNION ALL SELECT 'mart_shipping_region_failure', COUNT(*) FROM mart_shipping_region_failure;

.mode duckbox
