-- ============================================================
-- File   : sql/07_data_modeling.sql
-- Tujuan : Tahap 8 — Data Modeling: bentuk star schema dari table `sales`
-- Prasyarat : sql/04_data_cleaning.sql sudah dijalankan (table sales ada)
--
-- Desain (grain fact = 1 baris = 1 order):
--   fact_orders                 (order_id PK, FK ke semua dim, measures, flags)
--   dim_date                    (1 baris per tanggal, min..max order_date_clean)
--   dim_status                  (status_pesanan + status_group)
--   dim_cancellation_reason     (alasan mentah + actor + detail + group)
--   dim_payment_method          (metode_pembayaran + payment_group)
--   dim_location                (provinsi + kota_kabupaten)
--   dim_shipping                (opsi_pengiriman mentah, belum diparsing)
--   dim_category                (nama kategori produk unik)
--   bridge_order_category       (order_id <-> category_key, many-to-many)
--
-- Catatan desain:
-- * Kategori produk disimpan di bridge karena 1 order bisa punya >1 kategori
--   (product_categories berisi daftar dipisah koma). Fact tetap grain order.
-- * Kolom grouping (status_group, cancel_reason_group, payment_group) adalah
--   pengelompokan analitik; nilai mentah tetap disimpan di dimensinya.
-- * Mapping yang tidak dikenali jatuh ke 'Belum Terpetakan' supaya kelihatan
--   di validasi, bukan diam-diam masuk kategori lain.
-- ============================================================

-- ------------------------------------------------------------
-- 1. dim_date
--    is_missing_period_month = TRUE untuk bulan yang tidak punya order sama
--    sekali di sales (data-driven, bukan hardcode Des 2024 / Jul 2025)
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE dim_date AS
WITH bounds AS (
  SELECT MIN(order_date_clean) AS d_min, MAX(order_date_clean) AS d_max FROM sales
),
days AS (
  SELECT CAST(unnest(generate_series(
    (SELECT d_min FROM bounds),
    (SELECT d_max FROM bounds),
    INTERVAL 1 DAY
  )) AS DATE) AS full_date
)
SELECT
  CAST(strftime(full_date, '%Y%m%d') AS INTEGER) AS date_key,
  full_date,
  year(full_date)      AS year_num,
  quarter(full_date)   AS quarter_num,
  month(full_date)     AS month_num,
  strftime(full_date, '%Y-%m') AS year_month,
  monthname(full_date) AS month_name,
  day(full_date)       AS day_of_month,
  isodow(full_date)    AS iso_day_of_week,
  dayname(full_date)   AS day_name,
  isodow(full_date) IN (6, 7) AS is_weekend,
  CAST(date_trunc('month', full_date) AS DATE)
    NOT IN (SELECT DISTINCT CAST(order_month AS DATE) FROM sales) AS is_missing_period_month
FROM days;

-- ------------------------------------------------------------
-- 2. dim_status
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE dim_status AS
SELECT
  ROW_NUMBER() OVER (ORDER BY status_pesanan) AS status_key,
  status_pesanan,
  CASE
    WHEN status_pesanan = 'Selesai' THEN 'Completed'
    WHEN status_pesanan = 'Batal'   THEN 'Cancelled'
    ELSE 'In-Progress'
  END AS status_group
FROM (SELECT DISTINCT status_pesanan FROM sales);

-- ------------------------------------------------------------
-- 3. dim_cancellation_reason
--    Alasan mentah punya varian semantik yang sama (mis. bahasa Inggris vs
--    Indonesia untuk "ubah alamat pengiriman"), jadi ada cancel_reason_group.
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE dim_cancellation_reason AS
WITH base AS (
  SELECT DISTINCT alasan_pembatalan FROM sales
),
parsed AS (
  SELECT
    alasan_pembatalan,
    CASE
      WHEN alasan_pembatalan = 'Tidak dibatalkan' THEN 'Tidak Dibatalkan'
      WHEN alasan_pembatalan LIKE 'Dibatalkan oleh Pembeli%' THEN 'Pembeli'
      WHEN alasan_pembatalan LIKE 'Dibatalkan secara otomatis oleh sistem%' THEN 'Sistem'
      WHEN alasan_pembatalan LIKE 'Dibatalkan oleh Penjual%' THEN 'Penjual'
      ELSE 'Belum Terpetakan'
    END AS cancel_actor,
    CASE
      WHEN alasan_pembatalan LIKE '%Alasan: %'
        THEN TRIM(split_part(alasan_pembatalan, 'Alasan: ', 2))
      ELSE NULL
    END AS cancel_reason_detail
  FROM base
)
SELECT
  ROW_NUMBER() OVER (ORDER BY alasan_pembatalan) AS cancel_reason_key,
  alasan_pembatalan,
  cancel_actor,
  cancel_reason_detail,
  CASE
    WHEN cancel_actor = 'Tidak Dibatalkan' THEN 'Tidak Dibatalkan'
    WHEN cancel_reason_detail IN ('Need to change delivery address', 'Perlu mengubah alamat pengiriman')
      THEN 'Ubah alamat pengiriman'
    WHEN cancel_reason_detail IN ('Ubah Pesanan yang Ada', 'Perlu mengubah pesanan')
      THEN 'Ubah pesanan'
    WHEN cancel_reason_detail = 'Perlu mengubah Voucher'
      THEN 'Ubah voucher'
    WHEN cancel_reason_detail IN ('Lainnya/ berubah pikiran', 'Tidak ingin membeli lagi')
      THEN 'Berubah pikiran'
    WHEN cancel_reason_detail = 'Menemukan yang lebih murah'
      THEN 'Menemukan harga lebih murah'
    WHEN cancel_reason_detail = 'Proses pembayaran sulit'
      THEN 'Kendala pembayaran'
    WHEN cancel_reason_detail = 'Penjual tidak responsif terhadap pertanyaan Pembeli'
      THEN 'Penjual tidak responsif'
    WHEN cancel_reason_detail = 'Pesanan belum dibayar'
      THEN 'Pesanan belum dibayar'
    WHEN cancel_reason_detail = 'Pengiriman gagal'
      THEN 'Pengiriman gagal'
    WHEN cancel_reason_detail IN ('Penjual gagal mengirimkan pesanan tepat waktu',
                                  'Penjual tidak mengatur pengiriman tepat waktu')
      THEN 'Penjual terlambat kirim'
    WHEN cancel_reason_detail LIKE 'Paket hilang di perjalanan%'
      THEN 'Paket hilang'
    WHEN cancel_reason_detail = 'Produk habis'
      THEN 'Produk habis'
    WHEN cancel_reason_detail = 'Lainnya'
      THEN 'Lainnya'
    ELSE 'Belum Terpetakan'
  END AS cancel_reason_group
FROM parsed;

-- ------------------------------------------------------------
-- 4. dim_payment_method
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE dim_payment_method AS
SELECT
  ROW_NUMBER() OVER (ORDER BY metode_pembayaran) AS payment_key,
  metode_pembayaran,
  CASE
    WHEN metode_pembayaran = 'COD' THEN 'Cash on Delivery'
    WHEN metode_pembayaran IN ('ShopeePay', 'SPayLater', 'SeaBank Bayar Instan')
      THEN 'Ekosistem Shopee (Digital)'
    WHEN metode_pembayaran IN ('Online Payment', 'Kartu Kredit/Debit', 'BCA OneKlik')
      THEN 'Online / Kartu / Bank'
    WHEN metode_pembayaran IN ('Indomaret/i.Saku', 'Alfamart/Alfamidi/Dan+Dan')
      THEN 'Gerai Retail'
    WHEN metode_pembayaran = 'Tidak Diketahui' THEN 'Tidak Diketahui'
    WHEN metode_pembayaran IN ('Pembayaran dibebaskan', 'Mitra Shopee') THEN 'Lainnya'
    ELSE 'Belum Terpetakan'
  END AS payment_group
FROM (SELECT DISTINCT metode_pembayaran FROM sales);

-- ------------------------------------------------------------
-- 5. dim_location
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE dim_location AS
SELECT
  ROW_NUMBER() OVER (ORDER BY provinsi, kota_kabupaten) AS location_key,
  provinsi,
  kota_kabupaten
FROM (SELECT DISTINCT provinsi, kota_kabupaten FROM sales);

-- ------------------------------------------------------------
-- 6. dim_shipping (opsi mentah; parsing tier layanan vs kurir ditunda ke Tahap 13)
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE dim_shipping AS
SELECT
  ROW_NUMBER() OVER (ORDER BY opsi_pengiriman) AS shipping_key,
  opsi_pengiriman
FROM (SELECT DISTINCT opsi_pengiriman FROM sales);

-- ------------------------------------------------------------
-- 7. dim_category + bridge_order_category
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE dim_category AS
SELECT
  ROW_NUMBER() OVER (ORDER BY category_name) AS category_key,
  category_name
FROM (
  SELECT DISTINCT TRIM(cat) AS category_name
  FROM (
    SELECT unnest(string_split(product_categories, ',')) AS cat
    FROM sales
    WHERE product_categories IS NOT NULL
  )
  WHERE TRIM(cat) <> ''
);

CREATE OR REPLACE TABLE bridge_order_category AS
SELECT DISTINCT
  s.order_id,
  d.category_key
FROM (
  SELECT order_id, unnest(string_split(product_categories, ',')) AS cat
  FROM sales
  WHERE product_categories IS NOT NULL
) s
JOIN dim_category d ON d.category_name = TRIM(s.cat);

-- ------------------------------------------------------------
-- 8. fact_orders (grain: 1 baris = 1 order)
--    LEFT JOIN supaya key yang gagal match kelihatan sebagai NULL di validasi
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE fact_orders AS
SELECT
  s.order_id,
  CAST(strftime(s.order_date_clean, '%Y%m%d') AS INTEGER) AS date_key,
  st.status_key,
  cr.cancel_reason_key,
  pm.payment_key,
  lo.location_key,
  sh.shipping_key,
  s.waktu_pesanan_dibuat,
  s.total_qty,
  s.total_weight_gr,
  s.total_returned_qty,
  s.total_diskon,
  s.num_product_categories,
  s.ongkir_dibayar_pembeli,
  s.estimasi_potongan_ongkir,
  s.perkiraan_ongkos_kirim,
  s.total_pembayaran,
  s.flag_qty_missing,
  s.flag_selesai_bayar_nol
FROM sales s
LEFT JOIN dim_status st              ON st.status_pesanan = s.status_pesanan
LEFT JOIN dim_cancellation_reason cr ON cr.alasan_pembatalan = s.alasan_pembatalan
LEFT JOIN dim_payment_method pm      ON pm.metode_pembayaran = s.metode_pembayaran
LEFT JOIN dim_location lo            ON lo.provinsi = s.provinsi
                                    AND lo.kota_kabupaten = s.kota_kabupaten
LEFT JOIN dim_shipping sh            ON sh.opsi_pengiriman = s.opsi_pengiriman;

-- ============================================================
-- VALIDASI MODEL
-- ============================================================

-- V1. Jumlah baris tiap table model
SELECT 'fact_orders' AS table_name, COUNT(*) AS jumlah_baris FROM fact_orders
UNION ALL SELECT 'dim_date', COUNT(*) FROM dim_date
UNION ALL SELECT 'dim_status', COUNT(*) FROM dim_status
UNION ALL SELECT 'dim_cancellation_reason', COUNT(*) FROM dim_cancellation_reason
UNION ALL SELECT 'dim_payment_method', COUNT(*) FROM dim_payment_method
UNION ALL SELECT 'dim_location', COUNT(*) FROM dim_location
UNION ALL SELECT 'dim_shipping', COUNT(*) FROM dim_shipping
UNION ALL SELECT 'dim_category', COUNT(*) FROM dim_category
UNION ALL SELECT 'bridge_order_category', COUNT(*) FROM bridge_order_category;

-- V2. Grain fact: baris = 18.868 dan order_id unik
SELECT COUNT(*) AS fact_rows, COUNT(DISTINCT order_id) AS fact_distinct_order_id
FROM fact_orders;

-- V3. Reconciliation revenue: fact vs sales (harus identik)
SELECT
  (SELECT SUM(total_pembayaran) FROM sales)       AS revenue_sales,
  (SELECT SUM(total_pembayaran) FROM fact_orders) AS revenue_fact;

-- V4. Orphan key: harus 0 semua
SELECT
  SUM(CASE WHEN date_key IS NULL THEN 1 ELSE 0 END)          AS null_date_key,
  SUM(CASE WHEN status_key IS NULL THEN 1 ELSE 0 END)        AS null_status_key,
  SUM(CASE WHEN cancel_reason_key IS NULL THEN 1 ELSE 0 END) AS null_cancel_reason_key,
  SUM(CASE WHEN payment_key IS NULL THEN 1 ELSE 0 END)       AS null_payment_key,
  SUM(CASE WHEN location_key IS NULL THEN 1 ELSE 0 END)      AS null_location_key,
  SUM(CASE WHEN shipping_key IS NULL THEN 1 ELSE 0 END)      AS null_shipping_key
FROM fact_orders;

-- V5. Semua date_key di fact harus ada di dim_date (harus 0)
SELECT COUNT(*) AS fact_date_key_tidak_ada_di_dim_date
FROM fact_orders f
LEFT JOIN dim_date d ON d.date_key = f.date_key
WHERE d.date_key IS NULL;

-- V6. Bulan yang ditandai missing period di dim_date (ekspektasi: 2024-12 dan 2025-07)
SELECT DISTINCT year_month
FROM dim_date
WHERE is_missing_period_month
ORDER BY year_month;

-- V7. Mapping grouping: tidak boleh ada 'Belum Terpetakan'
SELECT 'cancel_actor' AS dimensi, cancel_actor AS nilai, COUNT(*) AS jumlah_baris_dim
FROM dim_cancellation_reason GROUP BY 2
UNION ALL
SELECT 'cancel_reason_group', cancel_reason_group, COUNT(*)
FROM dim_cancellation_reason GROUP BY 2
UNION ALL
SELECT 'payment_group', payment_group, COUNT(*)
FROM dim_payment_method GROUP BY 2
ORDER BY 1, 2;

-- V8. Bridge kategori: order unik di bridge vs order yang punya product_categories,
--     dan total baris bridge vs SUM(num_product_categories) (harus sama kalau kategori unik per order)
SELECT
  (SELECT COUNT(DISTINCT order_id) FROM bridge_order_category) AS order_di_bridge,
  (SELECT COUNT(*) FROM sales WHERE product_categories IS NOT NULL) AS order_dengan_kategori,
  (SELECT COUNT(*) FROM bridge_order_category) AS baris_bridge,
  (SELECT SUM(num_product_categories) FROM sales) AS sum_num_product_categories;

-- V9. Uji star join: revenue Completed Orders via dimensi (harus = 950.963.704 seperti EDA)
SELECT ROUND(SUM(f.total_pembayaran), 0) AS revenue_completed_via_star
FROM fact_orders f
JOIN dim_status st ON st.status_key = f.status_key
WHERE st.status_group = 'Completed';

-- V10. Uji star join: cancelled orders per actor (total non-'Tidak Dibatalkan' harus = 2.573)
SELECT cr.cancel_actor, COUNT(*) AS jumlah_order
FROM fact_orders f
JOIN dim_cancellation_reason cr ON cr.cancel_reason_key = f.cancel_reason_key
GROUP BY 1
ORDER BY jumlah_order DESC;
