-- ============================================================
-- File   : sql/08_order_status_cancellation_return.sql
-- Tujuan : Tahap 9 — Business Analysis: Order Status, Cancellation
--          & Return Behavior (descriptive & diagnostic)
-- Menjawab Business Questions: Q2 (payment vs pembatalan),
--          Q3 (alasan pembatalan), Q7 (return rate & polanya)
-- Prasyarat : sql/07_data_modeling.sql sudah dijalankan (star schema ada)
-- Aturan denominator (Tahap 6):
--   * Cancellation rate = order Batal / Total Orders
--   * Return rate       = order Selesai dengan total_returned_qty > 0
--                         / Completed Orders (BUKAN Total Orders)
-- ============================================================

-- ============================================================
-- A. ORDER STATUS
-- ============================================================

-- A1. Funnel status: jumlah order, porsi, dan revenue per status
SELECT
  st.status_group,
  st.status_pesanan,
  COUNT(*) AS jumlah_order,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_order,
  ROUND(SUM(f.total_pembayaran), 0) AS total_pembayaran
FROM fact_orders f
JOIN dim_status st ON st.status_key = f.status_key
GROUP BY 1, 2
ORDER BY jumlah_order DESC;

-- ============================================================
-- B. CANCELLATION
-- ============================================================

-- B1. Cancellation berdasarkan pihak yang membatalkan (actor)
WITH by_actor AS (
  SELECT cr.cancel_actor, COUNT(*) AS jumlah_order
  FROM fact_orders f
  JOIN dim_cancellation_reason cr ON cr.cancel_reason_key = f.cancel_reason_key
  GROUP BY 1
)
SELECT
  cancel_actor,
  jumlah_order,
  ROUND(100.0 * jumlah_order / (SELECT COUNT(*) FROM fact_orders), 2) AS pct_dari_total_order,
  CASE
    WHEN cancel_actor = 'Tidak Dibatalkan' THEN NULL
    ELSE ROUND(100.0 * jumlah_order
               / (SELECT SUM(jumlah_order) FROM by_actor WHERE cancel_actor <> 'Tidak Dibatalkan'), 2)
  END AS pct_dari_order_batal
FROM by_actor
ORDER BY jumlah_order DESC;

-- B2. Alasan pembatalan (grup) x actor — jawaban Q3
SELECT
  cr.cancel_reason_group,
  cr.cancel_actor,
  COUNT(*) AS jumlah_order,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_dari_order_batal
FROM fact_orders f
JOIN dim_cancellation_reason cr ON cr.cancel_reason_key = f.cancel_reason_key
WHERE cr.cancel_actor <> 'Tidak Dibatalkan'
GROUP BY 1, 2
ORDER BY jumlah_order DESC;

-- B3. Cancellation per metode pembayaran + dekomposisi alasan — jawaban Q2
--     Fokus: apakah cancellation rate Online Payment yang tinggi (EDA: 18,68%)
--     didorong oleh auto-cancel "Pesanan belum dibayar"?
SELECT
  pm.metode_pembayaran,
  pm.payment_group,
  COUNT(*) AS jumlah_order,
  SUM(CASE WHEN st.status_group = 'Cancelled' THEN 1 ELSE 0 END) AS jumlah_batal,
  ROUND(100.0 * SUM(CASE WHEN st.status_group = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS cancellation_rate_pct,
  SUM(CASE WHEN cr.cancel_actor = 'Pembeli' THEN 1 ELSE 0 END) AS batal_oleh_pembeli,
  SUM(CASE WHEN cr.cancel_actor = 'Sistem'  THEN 1 ELSE 0 END) AS batal_oleh_sistem,
  SUM(CASE WHEN cr.cancel_actor = 'Penjual' THEN 1 ELSE 0 END) AS batal_oleh_penjual,
  SUM(CASE WHEN cr.cancel_reason_group = 'Pesanan belum dibayar' THEN 1 ELSE 0 END) AS batal_belum_dibayar,
  ROUND(100.0 * (SUM(CASE WHEN st.status_group = 'Cancelled' THEN 1 ELSE 0 END)
                 - SUM(CASE WHEN cr.cancel_reason_group = 'Pesanan belum dibayar' THEN 1 ELSE 0 END))
        / COUNT(*), 2) AS cancellation_rate_tanpa_belum_dibayar_pct
FROM fact_orders f
JOIN dim_status st ON st.status_key = f.status_key
JOIN dim_cancellation_reason cr ON cr.cancel_reason_key = f.cancel_reason_key
JOIN dim_payment_method pm ON pm.payment_key = f.payment_key
GROUP BY 1, 2
ORDER BY jumlah_order DESC;

-- B4. Alasan pembatalan (grup) per payment_group — pola alasan tiap kelompok pembayaran
SELECT
  pm.payment_group,
  cr.cancel_reason_group,
  COUNT(*) AS jumlah_order
FROM fact_orders f
JOIN dim_cancellation_reason cr ON cr.cancel_reason_key = f.cancel_reason_key
JOIN dim_payment_method pm ON pm.payment_key = f.payment_key
WHERE cr.cancel_actor <> 'Tidak Dibatalkan'
GROUP BY 1, 2
ORDER BY 1, jumlah_order DESC;

-- B5. Tren cancellation rate bulanan (bulan missing period tidak muncul)
SELECT
  d.year_month,
  COUNT(*) AS jumlah_order,
  SUM(CASE WHEN st.status_group = 'Cancelled' THEN 1 ELSE 0 END) AS jumlah_batal,
  ROUND(100.0 * SUM(CASE WHEN st.status_group = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS cancellation_rate_pct
FROM fact_orders f
JOIN dim_date d ON d.date_key = f.date_key
JOIN dim_status st ON st.status_key = f.status_key
GROUP BY 1
ORDER BY 1;

-- B6. Cancellation per bucket qty (retail vs indikasi grosir); qty NULL dipisah
SELECT
  CASE
    WHEN f.total_qty IS NULL THEN 'Unknown'
    WHEN f.total_qty <= 2 THEN '1-2'
    WHEN f.total_qty <= 5 THEN '3-5'
    WHEN f.total_qty <= 10 THEN '6-10'
    ELSE '11+'
  END AS qty_bucket,
  COUNT(*) AS jumlah_order,
  SUM(CASE WHEN st.status_group = 'Cancelled' THEN 1 ELSE 0 END) AS jumlah_batal,
  ROUND(100.0 * SUM(CASE WHEN st.status_group = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS cancellation_rate_pct
FROM fact_orders f
JOIN dim_status st ON st.status_key = f.status_key
GROUP BY 1
ORDER BY MIN(COALESCE(f.total_qty, 0));

-- ============================================================
-- C. RETURN (denominator: Completed Orders)
-- ============================================================

-- C1. Cek definisi: order dengan total_returned_qty > 0 tersebar di status mana saja?
SELECT
  st.status_group,
  COUNT(*) AS jumlah_order,
  SUM(CASE WHEN f.total_returned_qty > 0 THEN 1 ELSE 0 END) AS order_dengan_retur
FROM fact_orders f
JOIN dim_status st ON st.status_key = f.status_key
GROUP BY 1
ORDER BY jumlah_order DESC;

-- C2. Return overview (Completed Orders): berbasis order dan berbasis qty
SELECT
  COUNT(*) AS completed_orders,
  SUM(CASE WHEN f.total_returned_qty > 0 THEN 1 ELSE 0 END) AS completed_dengan_retur,
  ROUND(100.0 * SUM(CASE WHEN f.total_returned_qty > 0 THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS return_rate_order_pct,
  SUM(CASE WHEN f.total_qty IS NOT NULL THEN f.total_qty ELSE 0 END) AS total_qty_completed,
  SUM(f.total_returned_qty) AS total_returned_qty,
  ROUND(100.0 * SUM(f.total_returned_qty)
        / NULLIF(SUM(CASE WHEN f.total_qty IS NOT NULL THEN f.total_qty ELSE 0 END), 0), 2)
    AS return_rate_qty_pct
FROM fact_orders f
JOIN dim_status st ON st.status_key = f.status_key
WHERE st.status_group = 'Completed';

-- C3. Retur penuh vs sebagian (order Completed yang ada retur, qty tidak NULL)
SELECT
  CASE
    WHEN f.total_returned_qty >= f.total_qty THEN 'Retur penuh'
    ELSE 'Retur sebagian'
  END AS tipe_retur,
  COUNT(*) AS jumlah_order
FROM fact_orders f
JOIN dim_status st ON st.status_key = f.status_key
WHERE st.status_group = 'Completed'
  AND f.total_returned_qty > 0
  AND f.total_qty IS NOT NULL
GROUP BY 1
ORDER BY jumlah_order DESC;

-- C4. Return rate per payment_group (Completed Orders)
SELECT
  pm.payment_group,
  COUNT(*) AS completed_orders,
  SUM(CASE WHEN f.total_returned_qty > 0 THEN 1 ELSE 0 END) AS completed_dengan_retur,
  ROUND(100.0 * SUM(CASE WHEN f.total_returned_qty > 0 THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS return_rate_pct
FROM fact_orders f
JOIN dim_status st ON st.status_key = f.status_key
JOIN dim_payment_method pm ON pm.payment_key = f.payment_key
WHERE st.status_group = 'Completed'
GROUP BY 1
ORDER BY completed_orders DESC;

-- C5. Return rate per provinsi (Completed Orders, minimal 200 order agar tidak terlalu noisy)
SELECT
  lo.provinsi,
  COUNT(*) AS completed_orders,
  SUM(CASE WHEN f.total_returned_qty > 0 THEN 1 ELSE 0 END) AS completed_dengan_retur,
  ROUND(100.0 * SUM(CASE WHEN f.total_returned_qty > 0 THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS return_rate_pct
FROM fact_orders f
JOIN dim_status st ON st.status_key = f.status_key
JOIN dim_location lo ON lo.location_key = f.location_key
WHERE st.status_group = 'Completed'
GROUP BY 1
HAVING COUNT(*) >= 200
ORDER BY return_rate_pct DESC;

-- C6. Return rate per kategori produk (Completed Orders, minimal 100 order).
--     Lewat bridge: order multi-kategori dihitung di tiap kategorinya (incidence rate per kategori).
SELECT
  c.category_name,
  COUNT(*) AS completed_orders_dengan_kategori,
  SUM(CASE WHEN f.total_returned_qty > 0 THEN 1 ELSE 0 END) AS dengan_retur,
  ROUND(100.0 * SUM(CASE WHEN f.total_returned_qty > 0 THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS return_rate_pct
FROM fact_orders f
JOIN dim_status st ON st.status_key = f.status_key
JOIN bridge_order_category b ON b.order_id = f.order_id
JOIN dim_category c ON c.category_key = b.category_key
WHERE st.status_group = 'Completed'
GROUP BY 1
HAVING COUNT(*) >= 100
ORDER BY return_rate_pct DESC;

-- C7. Return rate per bucket qty (apakah order besar lebih sering diretur?)
SELECT
  CASE
    WHEN f.total_qty <= 2 THEN '1-2'
    WHEN f.total_qty <= 5 THEN '3-5'
    WHEN f.total_qty <= 10 THEN '6-10'
    ELSE '11+'
  END AS qty_bucket,
  COUNT(*) AS completed_orders,
  SUM(CASE WHEN f.total_returned_qty > 0 THEN 1 ELSE 0 END) AS completed_dengan_retur,
  ROUND(100.0 * SUM(CASE WHEN f.total_returned_qty > 0 THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS return_rate_pct
FROM fact_orders f
JOIN dim_status st ON st.status_key = f.status_key
WHERE st.status_group = 'Completed' AND f.total_qty IS NOT NULL
GROUP BY 1
ORDER BY MIN(f.total_qty);

-- C8. Tren return bulanan (Completed Orders)
SELECT
  d.year_month,
  COUNT(*) AS completed_orders,
  SUM(CASE WHEN f.total_returned_qty > 0 THEN 1 ELSE 0 END) AS completed_dengan_retur,
  ROUND(100.0 * SUM(CASE WHEN f.total_returned_qty > 0 THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS return_rate_pct
FROM fact_orders f
JOIN dim_status st ON st.status_key = f.status_key
JOIN dim_date d ON d.date_key = f.date_key
WHERE st.status_group = 'Completed'
GROUP BY 1
ORDER BY 1;
