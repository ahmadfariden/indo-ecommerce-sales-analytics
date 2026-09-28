-- ============================================================
-- File   : sql/10_regional_performance.sql
-- Tujuan : Tahap 11 — Business Analysis: Regional Performance
--          (descriptive & diagnostic). Menjawab Q1 (provinsi/kota
--          penyumbang order & revenue terbesar) dan menguji dua
--          keterkaitan yang ditunda dari Tahap 9-10:
--            (1) apakah cancellation rate per provinsi hanya cerminan
--                porsi COD, atau ada efek provinsi tersendiri
--            (2) apakah naiknya porsi COD seiring waktu terjadi di dalam
--                wilayah, atau hanya pergeseran komposisi wilayah
-- Prasyarat : sql/07_data_modeling.sql sudah dijalankan (star schema ada)
--
-- Urutan: A = cek kualitas nama kota (WAJIB dibaca dulu sebelum B-G),
--         B-G = analisis.
-- Catatan:
--  * Analisis nilai (revenue, AOV, ongkir) memakai Completed Orders.
--  * Cancellation rate = Batal / Total Orders; return rate = order Selesai
--    dengan retur / Completed Orders (aturan Tahap 6).
--  * Nama kota dinormalisasi hanya untuk huruf besar/kecil dan spasi
--    (kota_norm). Kota vs Kabupaten TIDAK digabung (unit administratif berbeda).
--  * View v_orders_region dibuat sebagai lapisan bantu analisis regional.
-- ============================================================

-- Mode tampilan markdown: semua kolom & baris ditampilkan tanpa dipotong
-- (perintah CLI DuckDB, bukan SQL; dikembalikan ke duckbox di akhir file)
.mode markdown

-- ------------------------------------------------------------
-- 0. View bantu: order + wilayah + status + pembayaran
--    region_group = pengelompokan analitik per pulau/kepulauan
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_orders_region AS
SELECT
  f.order_id,
  f.date_key,
  f.total_qty,
  f.total_weight_gr,
  f.total_returned_qty,
  f.ongkir_dibayar_pembeli,
  f.perkiraan_ongkos_kirim,
  f.total_pembayaran,
  f.flag_selesai_bayar_nol,
  lo.provinsi,
  lo.kota_kabupaten AS kota_raw,
  UPPER(TRIM(regexp_replace(lo.kota_kabupaten, '\s+', ' ', 'g'))) AS kota_norm,
  CASE
    WHEN lo.provinsi IN ('DKI JAKARTA', 'JAWA BARAT', 'JAWA TENGAH', 'JAWA TIMUR',
                         'DI YOGYAKARTA', 'BANTEN') THEN 'Jawa'
    WHEN lo.provinsi IN ('NANGGROE ACEH DARUSSALAM (NAD)', 'SUMATERA UTARA', 'SUMATERA BARAT',
                         'RIAU', 'KEPULAUAN RIAU', 'JAMBI', 'SUMATERA SELATAN',
                         'BANGKA BELITUNG', 'BENGKULU', 'LAMPUNG') THEN 'Sumatera'
    WHEN lo.provinsi IN ('KALIMANTAN BARAT', 'KALIMANTAN TENGAH', 'KALIMANTAN SELATAN',
                         'KALIMANTAN TIMUR', 'KALIMANTAN UTARA') THEN 'Kalimantan'
    WHEN lo.provinsi IN ('SULAWESI UTARA', 'GORONTALO', 'SULAWESI TENGAH', 'SULAWESI BARAT',
                         'SULAWESI SELATAN', 'SULAWESI TENGGARA') THEN 'Sulawesi'
    WHEN lo.provinsi IN ('BALI', 'NUSA TENGGARA BARAT (NTB)', 'NUSA TENGGARA TIMUR (NTT)')
      THEN 'Bali & Nusa Tenggara'
    WHEN lo.provinsi IN ('MALUKU', 'MALUKU UTARA', 'PAPUA', 'PAPUA BARAT') THEN 'Maluku & Papua'
    ELSE 'Belum Terpetakan'
  END AS region_group,
  st.status_group,
  pm.payment_group,
  cr.cancel_reason_group,
  cr.cancel_actor
FROM fact_orders f
JOIN dim_location lo ON lo.location_key = f.location_key
JOIN dim_status st ON st.status_key = f.status_key
JOIN dim_payment_method pm ON pm.payment_key = f.payment_key
JOIN dim_cancellation_reason cr ON cr.cancel_reason_key = f.cancel_reason_key;

-- ============================================================
-- A. KUALITAS NAMA KOTA/KABUPATEN (dibaca sebelum B-G)
-- ============================================================

-- A1. Jumlah kombinasi: mentah vs setelah normalisasi huruf/spasi
--     (kalau kota_norm_distinct < kota_raw_distinct, ada varian huruf/spasi)
SELECT
  COUNT(*) AS baris_dim_location,
  COUNT(DISTINCT kota_kabupaten) AS kota_raw_distinct,
  COUNT(DISTINCT UPPER(TRIM(regexp_replace(kota_kabupaten, '\s+', ' ', 'g')))) AS kota_norm_distinct,
  COUNT(DISTINCT provinsi || '|' || UPPER(TRIM(regexp_replace(kota_kabupaten, '\s+', ' ', 'g'))))
    AS kombinasi_provinsi_kota_norm_distinct
FROM dim_location;

-- A2. Pola penulisan (prefiks) dan contohnya
SELECT
  CASE
    WHEN kota_norm LIKE 'KOTA %' THEN 'KOTA ...'
    WHEN kota_norm LIKE 'KAB.%' OR kota_norm LIKE 'KAB %' OR kota_norm LIKE 'KABUPATEN %' THEN 'KAB ...'
    ELSE 'Tanpa prefiks Kota/Kab'
  END AS pola_penulisan,
  COUNT(DISTINCT provinsi || '|' || kota_norm) AS jumlah_kota,
  COUNT(*) AS jumlah_order,
  MIN(kota_raw) AS contoh_1,
  MAX(kota_raw) AS contoh_2
FROM v_orders_region
GROUP BY 1
ORDER BY jumlah_order DESC;

-- A3. Varian yang hanya beda huruf/spasi dalam provinsi yang sama (kandidat digabung)
SELECT
  provinsi,
  kota_norm,
  COUNT(DISTINCT kota_raw) AS jumlah_varian_raw,
  STRING_AGG(DISTINCT kota_raw, ' | ') AS varian
FROM v_orders_region
GROUP BY 1, 2
HAVING COUNT(DISTINCT kota_raw) > 1
ORDER BY jumlah_varian_raw DESC, kota_norm
LIMIT 30;

-- A4. Pasangan nama sangat mirip dalam provinsi yang sama (jarak edit <= 2): kandidat typo
--     Perhatian: "KOTA X" vs "KAB. X" adalah unit berbeda dan JANGAN digabung
WITH c AS (
  SELECT provinsi, kota_norm, COUNT(*) AS orders
  FROM v_orders_region
  GROUP BY 1, 2
)
SELECT
  a.provinsi,
  a.kota_norm AS kota_a,
  a.orders AS orders_a,
  b.kota_norm AS kota_b,
  b.orders AS orders_b,
  levenshtein(a.kota_norm, b.kota_norm) AS jarak_edit
FROM c a
JOIN c b ON a.provinsi = b.provinsi AND a.kota_norm < b.kota_norm
WHERE levenshtein(a.kota_norm, b.kota_norm) <= 2
ORDER BY jarak_edit, a.orders + b.orders DESC
LIMIT 40;

-- A5. Nama kota yang sama muncul di lebih dari satu provinsi (bisa salah isi atau nama kembar)
SELECT
  kota_norm,
  COUNT(DISTINCT provinsi) AS jumlah_provinsi,
  STRING_AGG(DISTINCT provinsi, ' | ') AS provinsi_list,
  COUNT(*) AS jumlah_order
FROM v_orders_region
GROUP BY 1
HAVING COUNT(DISTINCT provinsi) > 1
ORDER BY jumlah_order DESC
LIMIT 30;

-- A6. Semua provinsi harus terpetakan ke region_group (harus 0)
SELECT COUNT(*) AS order_provinsi_belum_terpetakan
FROM v_orders_region
WHERE region_group = 'Belum Terpetakan';

-- ============================================================
-- B. PROVINSI (semua provinsi) — jawaban Q1 level provinsi
-- ============================================================
WITH agg AS (
  SELECT
    provinsi,
    region_group,
    COUNT(*) AS jumlah_order,
    SUM(CASE WHEN status_group = 'Completed' THEN 1 ELSE 0 END) AS completed_orders,
    SUM(CASE WHEN status_group = 'Completed' THEN total_pembayaran ELSE 0 END) AS revenue_completed,
    SUM(CASE WHEN status_group = 'Cancelled' THEN 1 ELSE 0 END) AS jumlah_batal,
    SUM(CASE WHEN status_group = 'Completed' AND total_returned_qty > 0 THEN 1 ELSE 0 END) AS completed_dengan_retur,
    SUM(CASE WHEN payment_group = 'Cash on Delivery' THEN 1 ELSE 0 END) AS order_cod
  FROM v_orders_region
  GROUP BY 1, 2
)
SELECT
  provinsi,
  region_group,
  jumlah_order,
  ROUND(100.0 * jumlah_order / SUM(jumlah_order) OVER (), 2) AS pct_order,
  completed_orders,
  ROUND(revenue_completed, 0) AS revenue_completed,
  ROUND(100.0 * revenue_completed / SUM(revenue_completed) OVER (), 2) AS pct_revenue,
  ROUND(100.0 * SUM(revenue_completed) OVER (ORDER BY revenue_completed DESC, provinsi
                                             ROWS UNBOUNDED PRECEDING)
        / SUM(revenue_completed) OVER (), 2) AS cum_pct_revenue,
  ROUND(revenue_completed / NULLIF(completed_orders, 0), 0) AS aov_completed,
  ROUND(100.0 * jumlah_batal / jumlah_order, 2) AS cancellation_rate_pct,
  completed_dengan_retur,
  ROUND(100.0 * completed_dengan_retur / NULLIF(completed_orders, 0), 2) AS return_rate_pct,
  ROUND(100.0 * order_cod / jumlah_order, 2) AS pct_cod
FROM agg
ORDER BY revenue_completed DESC;

-- ============================================================
-- C. RINGKASAN PER REGION GROUP (pulau/kepulauan)
-- ============================================================
WITH agg AS (
  SELECT
    region_group,
    COUNT(DISTINCT provinsi) AS jumlah_provinsi,
    COUNT(*) AS jumlah_order,
    SUM(CASE WHEN status_group = 'Completed' THEN 1 ELSE 0 END) AS completed_orders,
    SUM(CASE WHEN status_group = 'Completed' THEN total_pembayaran ELSE 0 END) AS revenue_completed,
    SUM(CASE WHEN status_group = 'Cancelled' THEN 1 ELSE 0 END) AS jumlah_batal,
    SUM(CASE WHEN status_group = 'Completed' AND total_returned_qty > 0 THEN 1 ELSE 0 END) AS completed_dengan_retur,
    SUM(CASE WHEN payment_group = 'Cash on Delivery' THEN 1 ELSE 0 END) AS order_cod
  FROM v_orders_region
  GROUP BY 1
)
SELECT
  region_group,
  jumlah_provinsi,
  jumlah_order,
  ROUND(100.0 * jumlah_order / SUM(jumlah_order) OVER (), 2) AS pct_order,
  ROUND(revenue_completed, 0) AS revenue_completed,
  ROUND(100.0 * revenue_completed / SUM(revenue_completed) OVER (), 2) AS pct_revenue,
  ROUND(revenue_completed / NULLIF(completed_orders, 0), 0) AS aov_completed,
  ROUND(100.0 * jumlah_batal / jumlah_order, 2) AS cancellation_rate_pct,
  completed_dengan_retur,
  ROUND(100.0 * completed_dengan_retur / NULLIF(completed_orders, 0), 2) AS return_rate_pct,
  ROUND(100.0 * order_cod / jumlah_order, 2) AS pct_cod
FROM agg
ORDER BY jumlah_order DESC;

-- ============================================================
-- D. KOTA/KABUPATEN — jawaban Q1 level kota
-- ============================================================

-- D1. Top 20 kota/kabupaten berdasarkan jumlah order
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
  ROUND(100.0 * SUM(CASE WHEN payment_group = 'Cash on Delivery' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS pct_cod
FROM v_orders_region
GROUP BY 1, 2
ORDER BY jumlah_order DESC
LIMIT 20;

-- D2. Konsentrasi: berapa kota yang menyumbang 50% dan 80% order / revenue Completed
WITH city AS (
  SELECT
    provinsi,
    kota_norm,
    COUNT(*) AS orders,
    SUM(CASE WHEN status_group = 'Completed' THEN total_pembayaran ELSE 0 END) AS revenue
  FROM v_orders_region
  GROUP BY 1, 2
),
ranked_orders AS (
  SELECT
    ROW_NUMBER() OVER (ORDER BY orders DESC, provinsi, kota_norm) AS rnk,
    SUM(orders) OVER (ORDER BY orders DESC, provinsi, kota_norm ROWS UNBOUNDED PRECEDING) * 1.0
      / SUM(orders) OVER () AS cum_share
  FROM city
),
ranked_revenue AS (
  SELECT
    ROW_NUMBER() OVER (ORDER BY revenue DESC, provinsi, kota_norm) AS rnk,
    SUM(revenue) OVER (ORDER BY revenue DESC, provinsi, kota_norm ROWS UNBOUNDED PRECEDING) * 1.0
      / SUM(revenue) OVER () AS cum_share
  FROM city
)
SELECT
  (SELECT COUNT(*) FROM city) AS total_kota,
  (SELECT MIN(rnk) FROM ranked_orders WHERE cum_share >= 0.5) AS kota_untuk_50pct_order,
  (SELECT MIN(rnk) FROM ranked_orders WHERE cum_share >= 0.8) AS kota_untuk_80pct_order,
  ROUND(100.0 * (SELECT cum_share FROM ranked_orders WHERE rnk = 10), 2) AS top10_kota_pct_order,
  (SELECT MIN(rnk) FROM ranked_revenue WHERE cum_share >= 0.5) AS kota_untuk_50pct_revenue,
  (SELECT MIN(rnk) FROM ranked_revenue WHERE cum_share >= 0.8) AS kota_untuk_80pct_revenue,
  ROUND(100.0 * (SELECT cum_share FROM ranked_revenue WHERE rnk = 10), 2) AS top10_kota_pct_revenue;

-- ============================================================
-- E. Uji keterkaitan: cancellation per provinsi vs porsi COD
--    (provinsi dengan >= 200 order). Bandingkan cancellation rate order COD
--    vs non-COD DALAM provinsi yang sama untuk memisahkan efek komposisi
--    pembayaran dari efek provinsi.
-- ============================================================

-- E0. Rujukan nasional
SELECT
  ROUND(100.0 * SUM(CASE WHEN status_group = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS cancel_rate_semua,
  ROUND(100.0 * SUM(CASE WHEN payment_group = 'Cash on Delivery' AND status_group = 'Cancelled' THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN payment_group = 'Cash on Delivery' THEN 1 ELSE 0 END), 0), 2)
    AS cancel_rate_cod,
  ROUND(100.0 * SUM(CASE WHEN payment_group <> 'Cash on Delivery' AND status_group = 'Cancelled' THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN payment_group <> 'Cash on Delivery' THEN 1 ELSE 0 END), 0), 2)
    AS cancel_rate_non_cod
FROM v_orders_region;

-- E1. Per provinsi
SELECT
  provinsi,
  COUNT(*) AS jumlah_order,
  ROUND(100.0 * SUM(CASE WHEN payment_group = 'Cash on Delivery' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_cod,
  ROUND(100.0 * SUM(CASE WHEN status_group = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS cancel_rate_semua,
  SUM(CASE WHEN payment_group = 'Cash on Delivery' THEN 1 ELSE 0 END) AS order_cod,
  ROUND(100.0 * SUM(CASE WHEN payment_group = 'Cash on Delivery' AND status_group = 'Cancelled' THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN payment_group = 'Cash on Delivery' THEN 1 ELSE 0 END), 0), 2)
    AS cancel_rate_cod,
  SUM(CASE WHEN payment_group <> 'Cash on Delivery' THEN 1 ELSE 0 END) AS order_non_cod,
  ROUND(100.0 * SUM(CASE WHEN payment_group <> 'Cash on Delivery' AND status_group = 'Cancelled' THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN payment_group <> 'Cash on Delivery' THEN 1 ELSE 0 END), 0), 2)
    AS cancel_rate_non_cod,
  ROUND(100.0 * (SUM(CASE WHEN status_group = 'Cancelled' THEN 1 ELSE 0 END)
                 - SUM(CASE WHEN cancel_reason_group = 'Pesanan belum dibayar' THEN 1 ELSE 0 END))
        / COUNT(*), 2) AS cancel_rate_tanpa_belum_dibayar
FROM v_orders_region
GROUP BY 1
HAVING COUNT(*) >= 200
ORDER BY cancel_rate_semua DESC;

-- ============================================================
-- F. Pengiriman per region group (Completed Orders)
-- ============================================================
SELECT
  region_group,
  COUNT(*) AS completed_orders,
  ROUND(AVG(ongkir_dibayar_pembeli), 0) AS avg_ongkir_dibayar_pembeli,
  ROUND(AVG(perkiraan_ongkos_kirim), 0) AS avg_perkiraan_ongkos_kirim,
  ROUND(100.0 * SUM(CASE WHEN ongkir_dibayar_pembeli = 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_gratis_ongkir,
  ROUND(AVG(total_weight_gr), 0) AS avg_berat_gr
FROM v_orders_region
WHERE status_group = 'Completed'
GROUP BY 1
ORDER BY completed_orders DESC;

-- ============================================================
-- G. Tren bulanan: komposisi wilayah dan dekomposisi porsi COD
--    Jika pct_cod_jawa dan pct_cod_luar_jawa sama-sama naik, kenaikan COD
--    terjadi di dalam wilayah; jika hanya pct_jawa turun, itu efek komposisi.
-- ============================================================
SELECT
  d.year_month,
  COUNT(*) AS jumlah_order,
  ROUND(100.0 * SUM(CASE WHEN v.region_group = 'Jawa' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_order_jawa,
  ROUND(100.0 * SUM(CASE WHEN v.payment_group = 'Cash on Delivery' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS pct_cod_semua,
  ROUND(100.0 * SUM(CASE WHEN v.region_group = 'Jawa' AND v.payment_group = 'Cash on Delivery' THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN v.region_group = 'Jawa' THEN 1 ELSE 0 END), 0), 2) AS pct_cod_jawa,
  ROUND(100.0 * SUM(CASE WHEN v.region_group <> 'Jawa' AND v.payment_group = 'Cash on Delivery' THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN v.region_group <> 'Jawa' THEN 1 ELSE 0 END), 0), 2) AS pct_cod_luar_jawa
FROM v_orders_region v
JOIN dim_date d ON d.date_key = v.date_key
GROUP BY 1
ORDER BY 1;

-- ============================================================
-- H. Komposisi alasan pembatalan per region group
--    Semua kolom pct_* memakai TOTAL ORDER region sebagai penyebut, sehingga
--    penjumlahan kolom alasan mendekati cancellation_rate_pct. Dipakai untuk
--    melihat apa yang mendorong selisih cancellation antarwilayah.
-- ============================================================
SELECT
  region_group,
  COUNT(*) AS jumlah_order,
  ROUND(100.0 * SUM(CASE WHEN status_group = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS cancel_rate_pct,
  ROUND(100.0 * SUM(CASE WHEN cancel_actor = 'Pembeli' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS pct_batal_oleh_pembeli,
  ROUND(100.0 * SUM(CASE WHEN cancel_actor = 'Sistem' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS pct_batal_oleh_sistem,
  ROUND(100.0 * SUM(CASE WHEN cancel_reason_group = 'Pengiriman gagal' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS pct_pengiriman_gagal,
  ROUND(100.0 * SUM(CASE WHEN cancel_reason_group = 'Penjual terlambat kirim' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS pct_penjual_terlambat_kirim,
  ROUND(100.0 * SUM(CASE WHEN cancel_reason_group = 'Pesanan belum dibayar' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS pct_belum_dibayar,
  ROUND(100.0 * SUM(CASE WHEN cancel_reason_group IN ('Ubah pesanan', 'Ubah alamat pengiriman', 'Ubah voucher')
                         THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_ubah_pesanan_alamat_voucher,
  ROUND(100.0 * SUM(CASE WHEN cancel_reason_group = 'Berubah pikiran' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS pct_berubah_pikiran
FROM v_orders_region
GROUP BY 1
ORDER BY jumlah_order DESC;

-- Kembalikan mode tampilan default
.mode duckbox
