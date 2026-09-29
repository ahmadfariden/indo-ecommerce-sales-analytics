-- ============================================================
-- File   : sql/12_shipping_behavior.sql
-- Tujuan : Tahap 13 — Business Analysis: Shipping Behavior
--          (descriptive & diagnostic). Menuntaskan dua hal yang
--          ditunda: (1) parsing opsi_pengiriman (45 nilai granular,
--          ditunda sejak Tahap 5) jadi tier layanan + kurir, dan
--          (2) pengiriman gagal per kurir & wilayah (ditunda Tahap 11).
-- Prasyarat : sql/07_data_modeling.sql (star schema) dan
--             sql/10_regional_performance.sql (view v_orders_region,
--             untuk bagian H) sudah dijalankan.
--
-- Catatan parsing (WAJIB dibaca):
--  * kurir diekstrak dari substring nama kurir yang dikenal (SPX, JNE,
--    J&T, GrabExpress, GoSend) -> cukup andal.
--  * tier_layanan adalah pengelompokan ANALITIK berbasis kata kunci
--    (Hemat Kargo, Kargo, Reguler, Instant, Same Day, Next Day, dst).
--    Untuk opsi yang hanya menyebut kurir+tingkat tanpa kata baku
--    (mis. "SPX Standard", "J&T Economy"), tier ditebak dari konteks
--    kata dan DIBERI CATATAN sebagai perkiraan di bagian Assumptions.
--  * Bagian C memvalidasi: opsi yang gagal terklasifikasi harus 0 atau
--    ditinjau manual sebelum bagian D dst. dipakai.
-- ============================================================

.mode markdown

-- ============================================================
-- A. Daftar lengkap 45 opsi pengiriman (tinjau sebelum parsing B)
-- ============================================================
SELECT
  sh.opsi_pengiriman,
  COUNT(*) AS jumlah_order
FROM fact_orders f
JOIN dim_shipping sh ON sh.shipping_key = f.shipping_key
GROUP BY 1
ORDER BY jumlah_order DESC;

-- ============================================================
-- B. View parsing: kurir (andal) + tier_layanan (analitik/perkiraan)
-- ============================================================
CREATE OR REPLACE VIEW v_shipping_parsed AS
SELECT
  sh.shipping_key,
  sh.opsi_pengiriman,
  CASE
    WHEN sh.opsi_pengiriman LIKE '%SPX%' THEN 'SPX (Shopee Xpress)'
    WHEN sh.opsi_pengiriman LIKE '%J&T%' THEN 'J&T'
    WHEN sh.opsi_pengiriman LIKE '%JNE%' THEN 'JNE'
    WHEN sh.opsi_pengiriman LIKE '%GrabExpress%' THEN 'GrabExpress'
    WHEN sh.opsi_pengiriman LIKE '%GoSend%' OR sh.opsi_pengiriman LIKE '%Gosend%' THEN 'GoSend'
    ELSE 'Tidak disebutkan (generik)'
  END AS kurir,
  CASE
    WHEN sh.opsi_pengiriman LIKE 'Hemat Kargo%' OR sh.opsi_pengiriman LIKE '%Hemat%' THEN 'Hemat Kargo'
    WHEN sh.opsi_pengiriman LIKE 'Kargo%' OR sh.opsi_pengiriman LIKE '%Cargo%'
      OR sh.opsi_pengiriman LIKE '%Trucking%' THEN 'Kargo'
    WHEN sh.opsi_pengiriman LIKE 'Reguler%' OR sh.opsi_pengiriman LIKE '%Reguler%'
      OR sh.opsi_pengiriman LIKE '%Standard%' THEN 'Reguler (Cashless)'
    WHEN sh.opsi_pengiriman LIKE '%Economy%' THEN 'Economy'
    WHEN sh.opsi_pengiriman LIKE 'Instant Prioritas%' OR sh.opsi_pengiriman LIKE '%Instant Prioritas%'
      THEN 'Instant Prioritas'
    WHEN sh.opsi_pengiriman LIKE 'Instant (Versi Lama)%' OR sh.opsi_pengiriman LIKE '%Instant (Versi Lama)%'
      THEN 'Instant (Versi Lama)'
    WHEN sh.opsi_pengiriman LIKE '%Instant%' THEN 'Instant'
    WHEN sh.opsi_pengiriman LIKE 'Same Day%' OR sh.opsi_pengiriman LIKE '%Sameday%'
      OR sh.opsi_pengiriman LIKE '%Same Day%' THEN 'Same Day'
    WHEN sh.opsi_pengiriman LIKE 'Next Day%' OR sh.opsi_pengiriman LIKE '%YES%' THEN 'Next Day'
    WHEN sh.opsi_pengiriman LIKE 'Agen%' THEN 'Agen'
    WHEN sh.opsi_pengiriman LIKE '%Express Point%' THEN 'Express Point'
    WHEN sh.opsi_pengiriman LIKE '%Express%' THEN 'Reguler (Cashless)'
    ELSE 'Lainnya/Tidak Terklasifikasi'
  END AS tier_layanan
FROM dim_shipping sh;

-- ============================================================
-- C. VALIDASI parsing — harus 0 baris "Tidak Terklasifikasi" (atau ditinjau manual)
-- ============================================================
SELECT opsi_pengiriman, kurir, tier_layanan
FROM v_shipping_parsed
WHERE tier_layanan = 'Lainnya/Tidak Terklasifikasi' OR kurir = 'Tidak disebutkan (generik)'
ORDER BY opsi_pengiriman;

-- ============================================================
-- D. Performa per KURIR (Completed Orders untuk metrik nilai)
-- ============================================================
SELECT
  v.kurir,
  COUNT(*) AS jumlah_order,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_order,
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
  ROUND(AVG(CASE WHEN st.status_group = 'Completed' THEN f.perkiraan_ongkos_kirim END), 0)
    AS avg_perkiraan_ongkir,
  ROUND(AVG(CASE WHEN st.status_group = 'Completed' THEN f.total_weight_gr END), 0) AS avg_berat_gr
FROM fact_orders f
JOIN dim_status st ON st.status_key = f.status_key
JOIN v_shipping_parsed v ON v.shipping_key = f.shipping_key
GROUP BY 1
ORDER BY jumlah_order DESC;

-- ============================================================
-- E. Performa per TIER LAYANAN (Completed Orders untuk metrik nilai)
-- ============================================================
SELECT
  v.tier_layanan,
  COUNT(*) AS jumlah_order,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_order,
  SUM(CASE WHEN st.status_group = 'Completed' THEN 1 ELSE 0 END) AS completed_orders,
  ROUND(100.0 * SUM(CASE WHEN st.status_group = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS cancellation_rate_pct,
  ROUND(AVG(CASE WHEN st.status_group = 'Completed' THEN f.ongkir_dibayar_pembeli END), 0)
    AS avg_ongkir_dibayar,
  ROUND(AVG(CASE WHEN st.status_group = 'Completed' THEN f.perkiraan_ongkos_kirim END), 0)
    AS avg_perkiraan_ongkir,
  ROUND(AVG(CASE WHEN st.status_group = 'Completed' THEN f.total_weight_gr END), 0) AS avg_berat_gr,
  ROUND(AVG(CASE WHEN st.status_group = 'Completed' THEN f.total_qty END), 2) AS avg_qty
FROM fact_orders f
JOIN dim_status st ON st.status_key = f.status_key
JOIN v_shipping_parsed v ON v.shipping_key = f.shipping_key
GROUP BY 1
ORDER BY jumlah_order DESC;

-- ============================================================
-- F. Subsidi ongkir: rasio ongkir dibayar pembeli / perkiraan ongkos kirim
--    per kurir (rasio rendah = subsidi besar). Completed Orders.
-- ============================================================
SELECT
  v.kurir,
  COUNT(*) AS completed_orders,
  ROUND(AVG(f.ongkir_dibayar_pembeli), 0) AS avg_ongkir_dibayar,
  ROUND(AVG(f.perkiraan_ongkos_kirim), 0) AS avg_perkiraan_ongkir,
  ROUND(100.0 * AVG(f.ongkir_dibayar_pembeli) / NULLIF(AVG(f.perkiraan_ongkos_kirim), 0), 2)
    AS pct_dibayar_dari_perkiraan,
  ROUND(100.0 * SUM(CASE WHEN f.ongkir_dibayar_pembeli = 0 THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS pct_gratis_ongkir
FROM fact_orders f
JOIN dim_status st ON st.status_key = f.status_key
JOIN v_shipping_parsed v ON v.shipping_key = f.shipping_key
WHERE st.status_group = 'Completed'
GROUP BY 1
ORDER BY completed_orders DESC;

-- ============================================================
-- G. Pengiriman gagal per KURIR (menuntaskan temuan Tahap 9:
--    234 dari 238 pembatalan "Pengiriman gagal" berasal dari COD;
--    di sini dilihat dari sisi kurir, bukan metode pembayaran)
-- ============================================================
SELECT
  v.kurir,
  COUNT(*) AS jumlah_order,
  SUM(CASE WHEN cr.cancel_reason_group = 'Pengiriman gagal' THEN 1 ELSE 0 END) AS pengiriman_gagal,
  ROUND(100.0 * SUM(CASE WHEN cr.cancel_reason_group = 'Pengiriman gagal' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS pct_pengiriman_gagal,
  SUM(CASE WHEN cr.cancel_reason_group = 'Penjual terlambat kirim' THEN 1 ELSE 0 END)
    AS penjual_terlambat_kirim,
  ROUND(100.0 * SUM(CASE WHEN cr.cancel_reason_group = 'Penjual terlambat kirim' THEN 1 ELSE 0 END)
        / COUNT(*), 2) AS pct_penjual_terlambat_kirim
FROM fact_orders f
JOIN v_shipping_parsed v ON v.shipping_key = f.shipping_key
JOIN dim_cancellation_reason cr ON cr.cancel_reason_key = f.cancel_reason_key
GROUP BY 1
ORDER BY jumlah_order DESC;

-- ============================================================
-- H. Pengiriman gagal per KURIR x REGION (menuntaskan item tertunda Tahap 11)
--    Butuh view v_orders_region dari sql/10_regional_performance.sql
-- ============================================================
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
-- I. Sanity check: apakah tier Kargo benar-benar membawa order lebih berat?
-- ============================================================
SELECT
  v.tier_layanan,
  COUNT(*) AS completed_orders,
  ROUND(MIN(f.total_weight_gr), 0) AS min_berat_gr,
  QUANTILE_CONT(f.total_weight_gr, 0.5) AS median_berat_gr,
  ROUND(AVG(f.total_weight_gr), 0) AS avg_berat_gr,
  ROUND(MAX(f.total_weight_gr), 0) AS max_berat_gr
FROM fact_orders f
JOIN dim_status st ON st.status_key = f.status_key
JOIN v_shipping_parsed v ON v.shipping_key = f.shipping_key
WHERE st.status_group = 'Completed' AND f.total_weight_gr IS NOT NULL
GROUP BY 1
ORDER BY avg_berat_gr DESC;

.mode duckbox
