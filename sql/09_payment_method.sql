-- ============================================================
-- File   : sql/09_payment_method.sql
-- Tujuan : Tahap 10 — Business Analysis: Payment Method Behavior
--          (descriptive & diagnostic). Fokus: adopsi, nilai order,
--          pergeseran mix dari waktu ke waktu, hubungan dengan ukuran
--          order, wilayah, ongkir, diskon, dan anomali pembayaran nol.
-- Prasyarat : sql/07_data_modeling.sql sudah dijalankan (star schema ada)
--
-- Catatan:
--  * Cancellation & return per metode pembayaran sudah dibahas di Tahap 9
--    (sql/08); di sini hanya dirangkum ulang di scorecard (bagian I).
--  * Order Batal punya total_pembayaran = 0, jadi analisis NILAI order
--    (revenue, AOV, bucket nilai, ongkir, diskon) memakai Completed Orders.
--  * Analisis KOMPOSISI (mix) memakai seluruh order kecuali dinyatakan lain.
-- ============================================================

-- ============================================================
-- A. Adopsi & nilai per metode pembayaran
-- ============================================================
WITH agg AS (
  SELECT
    pm.metode_pembayaran,
    pm.payment_group,
    COUNT(*) AS jumlah_order,
    SUM(CASE WHEN st.status_group = 'Completed' THEN 1 ELSE 0 END) AS completed_orders,
    SUM(CASE WHEN st.status_group = 'Completed' THEN f.total_pembayaran ELSE 0 END) AS revenue_completed,
    QUANTILE_CONT(CASE WHEN st.status_group = 'Completed' THEN f.total_pembayaran END, 0.5)
      AS median_nilai_order,
    AVG(CASE WHEN st.status_group = 'Completed' THEN f.total_qty END) AS avg_qty_completed
  FROM fact_orders f
  JOIN dim_status st ON st.status_key = f.status_key
  JOIN dim_payment_method pm ON pm.payment_key = f.payment_key
  GROUP BY 1, 2
)
SELECT
  metode_pembayaran,
  payment_group,
  jumlah_order,
  ROUND(100.0 * jumlah_order / SUM(jumlah_order) OVER (), 2) AS pct_order,
  completed_orders,
  ROUND(revenue_completed, 0) AS revenue_completed,
  ROUND(100.0 * revenue_completed / SUM(revenue_completed) OVER (), 2) AS pct_revenue_completed,
  ROUND(revenue_completed / NULLIF(completed_orders, 0), 0) AS aov_completed,
  ROUND(median_nilai_order, 0) AS median_nilai_order,
  ROUND(avg_qty_completed, 2) AS avg_qty_completed
FROM agg
ORDER BY jumlah_order DESC;

-- ============================================================
-- B. Ringkasan per kelompok pembayaran (payment_group)
-- ============================================================
WITH agg AS (
  SELECT
    pm.payment_group,
    COUNT(*) AS jumlah_order,
    SUM(CASE WHEN st.status_group = 'Completed' THEN 1 ELSE 0 END) AS completed_orders,
    SUM(CASE WHEN st.status_group = 'Completed' THEN f.total_pembayaran ELSE 0 END) AS revenue_completed
  FROM fact_orders f
  JOIN dim_status st ON st.status_key = f.status_key
  JOIN dim_payment_method pm ON pm.payment_key = f.payment_key
  GROUP BY 1
)
SELECT
  payment_group,
  jumlah_order,
  ROUND(100.0 * jumlah_order / SUM(jumlah_order) OVER (), 2) AS pct_order,
  ROUND(revenue_completed, 0) AS revenue_completed,
  ROUND(100.0 * revenue_completed / SUM(revenue_completed) OVER (), 2) AS pct_revenue_completed,
  ROUND(revenue_completed / NULLIF(completed_orders, 0), 0) AS aov_completed
FROM agg
ORDER BY jumlah_order DESC;

-- ============================================================
-- C. Pergeseran komposisi pembayaran per bulan (% order per kelompok)
--    Bulan missing period tidak muncul. Kolom pct_tidak_diketahui dipakai
--    untuk melihat apakah metode pembayaran NULL (283 baris) terkonsentrasi
--    di bulan tertentu.
-- ============================================================
SELECT
  d.year_month,
  COUNT(*) AS jumlah_order,
  ROUND(100.0 * SUM(CASE WHEN pm.payment_group = 'Cash on Delivery' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS pct_cod,
  ROUND(100.0 * SUM(CASE WHEN pm.payment_group = 'Ekosistem Shopee (Digital)' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS pct_shopee_digital,
  ROUND(100.0 * SUM(CASE WHEN pm.payment_group = 'Online / Kartu / Bank' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS pct_online_kartu_bank,
  ROUND(100.0 * SUM(CASE WHEN pm.payment_group = 'Gerai Retail' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS pct_gerai_retail,
  ROUND(100.0 * SUM(CASE WHEN pm.payment_group = 'Tidak Diketahui' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS pct_tidak_diketahui,
  ROUND(100.0 * SUM(CASE WHEN pm.payment_group = 'Lainnya' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS pct_lainnya
FROM fact_orders f
JOIN dim_date d ON d.date_key = f.date_key
JOIN dim_payment_method pm ON pm.payment_key = f.payment_key
GROUP BY 1
ORDER BY 1;

-- ============================================================
-- D. Metode pembayaran vs ukuran order
-- ============================================================

-- D1. Komposisi payment_group di tiap bucket qty (% dalam bucket; qty NULL dikeluarkan)
WITH b AS (
  SELECT
    CASE
      WHEN f.total_qty <= 2 THEN '1-2'
      WHEN f.total_qty <= 5 THEN '3-5'
      WHEN f.total_qty <= 10 THEN '6-10'
      ELSE '11+'
    END AS qty_bucket,
    CASE
      WHEN f.total_qty <= 2 THEN 1
      WHEN f.total_qty <= 5 THEN 2
      WHEN f.total_qty <= 10 THEN 3
      ELSE 4
    END AS bucket_order,
    pm.payment_group,
    COUNT(*) AS n
  FROM fact_orders f
  JOIN dim_payment_method pm ON pm.payment_key = f.payment_key
  WHERE f.total_qty IS NOT NULL
  GROUP BY 1, 2, 3
)
SELECT
  qty_bucket,
  payment_group,
  n AS jumlah_order,
  ROUND(100.0 * n / SUM(n) OVER (PARTITION BY qty_bucket), 2) AS pct_dalam_bucket
FROM b
ORDER BY bucket_order, n DESC;

-- D2. Komposisi payment_group di tiap bucket nilai order
--     (Completed Orders, tanpa 56 baris flag_selesai_bayar_nol)
WITH b AS (
  SELECT
    CASE
      WHEN f.total_pembayaran < 50000 THEN '< 50rb'
      WHEN f.total_pembayaran < 150000 THEN '50rb - 150rb'
      WHEN f.total_pembayaran < 300000 THEN '150rb - 300rb'
      WHEN f.total_pembayaran < 500000 THEN '300rb - 500rb'
      ELSE '>= 500rb'
    END AS bucket_nilai,
    CASE
      WHEN f.total_pembayaran < 50000 THEN 1
      WHEN f.total_pembayaran < 150000 THEN 2
      WHEN f.total_pembayaran < 300000 THEN 3
      WHEN f.total_pembayaran < 500000 THEN 4
      ELSE 5
    END AS bucket_order,
    pm.payment_group,
    COUNT(*) AS n
  FROM fact_orders f
  JOIN dim_status st ON st.status_key = f.status_key
  JOIN dim_payment_method pm ON pm.payment_key = f.payment_key
  WHERE st.status_group = 'Completed' AND NOT f.flag_selesai_bayar_nol
  GROUP BY 1, 2, 3
)
SELECT
  bucket_nilai,
  payment_group,
  n AS jumlah_order,
  ROUND(100.0 * n / SUM(n) OVER (PARTITION BY bucket_nilai), 2) AS pct_dalam_bucket
FROM b
ORDER BY bucket_order, n DESC;

-- ============================================================
-- E. Metode pembayaran per provinsi (provinsi dengan >= 200 order)
-- ============================================================
SELECT
  lo.provinsi,
  COUNT(*) AS jumlah_order,
  ROUND(100.0 * SUM(CASE WHEN pm.payment_group = 'Cash on Delivery' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS pct_cod,
  ROUND(100.0 * SUM(CASE WHEN pm.payment_group = 'Ekosistem Shopee (Digital)' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS pct_shopee_digital,
  ROUND(100.0 * SUM(CASE WHEN pm.payment_group = 'Online / Kartu / Bank' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS pct_online_kartu_bank,
  ROUND(100.0 * SUM(CASE WHEN pm.payment_group = 'Gerai Retail' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS pct_gerai_retail
FROM fact_orders f
JOIN dim_location lo ON lo.location_key = f.location_key
JOIN dim_payment_method pm ON pm.payment_key = f.payment_key
GROUP BY 1
HAVING COUNT(*) >= 200
ORDER BY pct_cod DESC;

-- ============================================================
-- F. Metode pembayaran vs pengiriman (Completed Orders)
-- ============================================================

-- F1. Ongkir per kelompok pembayaran
SELECT
  pm.payment_group,
  COUNT(*) AS completed_orders,
  ROUND(AVG(f.ongkir_dibayar_pembeli), 0) AS avg_ongkir_dibayar_pembeli,
  ROUND(AVG(f.perkiraan_ongkos_kirim), 0) AS avg_perkiraan_ongkos_kirim,
  ROUND(100.0 * SUM(CASE WHEN f.ongkir_dibayar_pembeli = 0 THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS pct_gratis_ongkir,
  ROUND(AVG(f.total_weight_gr), 0) AS avg_berat_gr
FROM fact_orders f
JOIN dim_status st ON st.status_key = f.status_key
JOIN dim_payment_method pm ON pm.payment_key = f.payment_key
WHERE st.status_group = 'Completed'
GROUP BY 1
ORDER BY completed_orders DESC;

-- F2. Porsi COD pada 10 opsi pengiriman terbanyak (seluruh order)
WITH top_opsi AS (
  SELECT sh.shipping_key, sh.opsi_pengiriman, COUNT(*) AS jumlah_order
  FROM fact_orders f
  JOIN dim_shipping sh ON sh.shipping_key = f.shipping_key
  GROUP BY 1, 2
  ORDER BY jumlah_order DESC
  LIMIT 10
)
SELECT
  t.opsi_pengiriman,
  t.jumlah_order,
  ROUND(100.0 * SUM(CASE WHEN pm.payment_group = 'Cash on Delivery' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS pct_cod
FROM fact_orders f
JOIN top_opsi t ON t.shipping_key = f.shipping_key
JOIN dim_payment_method pm ON pm.payment_key = f.payment_key
GROUP BY 1, 2
ORDER BY t.jumlah_order DESC;

-- ============================================================
-- G. Penggunaan diskon per kelompok pembayaran (Completed Orders)
-- ============================================================
SELECT
  pm.payment_group,
  COUNT(*) AS completed_orders,
  SUM(CASE WHEN f.total_diskon > 0 THEN 1 ELSE 0 END) AS order_dengan_diskon,
  ROUND(100.0 * SUM(CASE WHEN f.total_diskon > 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_order_dengan_diskon,
  ROUND(AVG(CASE WHEN f.total_diskon > 0 THEN f.total_diskon END), 0) AS avg_diskon_saat_ada_diskon
FROM fact_orders f
JOIN dim_status st ON st.status_key = f.status_key
JOIN dim_payment_method pm ON pm.payment_key = f.payment_key
WHERE st.status_group = 'Completed'
GROUP BY 1
ORDER BY completed_orders DESC;

-- ============================================================
-- H. Anomali pembayaran nol pada order yang tidak batal
--    (termasuk 56 baris flag_selesai_bayar_nol dan metode "Pembayaran dibebaskan")
-- ============================================================
SELECT
  pm.metode_pembayaran,
  st.status_group,
  COUNT(*) AS order_bayar_nol
FROM fact_orders f
JOIN dim_status st ON st.status_key = f.status_key
JOIN dim_payment_method pm ON pm.payment_key = f.payment_key
WHERE f.total_pembayaran = 0 AND st.status_group <> 'Cancelled'
GROUP BY 1, 2
ORDER BY order_bayar_nol DESC;

-- ============================================================
-- I. Scorecard per metode pembayaran (rangkuman untuk dashboard)
-- ============================================================
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
