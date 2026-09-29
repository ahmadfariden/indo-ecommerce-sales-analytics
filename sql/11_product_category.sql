-- ============================================================
-- File   : sql/11_product_category.sql
-- Tujuan : Tahap 12 — Business Analysis: Product Category Performance
--          & Category Co-occurrence (descriptive & diagnostic)
-- Prasyarat : sql/07_data_modeling.sql sudah dijalankan (star schema ada)
--
-- Peringatan desain (WAJIB dibaca sebelum memakai angka revenue kategori):
--  * bridge_order_category adalah relasi many-to-many: 1 order bisa
--    punya >1 kategori (7,24% order, dari EDA Tahap 7).
--  * MENJUMLAHKAN total_pembayaran per kategori lewat bridge akan
--    MENGHITUNG GANDA revenue order multi-kategori -> total lintas
--    kategori BISA MELEBIHI total revenue perusahaan.
--  * Solusi di file ini: bagian B1 menghitung revenue HANYA dari order
--    single-category (bersih, tidak dobel, tapi mengecualikan 7,24% order).
--    Bagian B2 memakai seluruh order lewat bridge tapi HANYA untuk metrik
--    yang aman didobel-hitung: jumlah order (incidence) dan rata-rata qty,
--    bukan revenue.
-- ============================================================

.mode markdown

-- ============================================================
-- A. KUALITAS NAMA KATEGORI (dibaca sebelum B-G)
-- ============================================================

-- A1. Jumlah kategori: mentah vs setelah normalisasi huruf/spasi
SELECT
  COUNT(*) AS jumlah_kategori,
  COUNT(DISTINCT UPPER(TRIM(regexp_replace(category_name, '\s+', ' ', 'g')))) AS jumlah_setelah_normalisasi
FROM dim_category;

-- A2. Daftar lengkap 38 kategori dengan jumlah order (bridge) - inspeksi visual
SELECT
  c.category_name,
  COUNT(*) AS jumlah_order
FROM bridge_order_category b
JOIN dim_category c ON c.category_key = b.category_key
GROUP BY 1
ORDER BY jumlah_order DESC;

-- A3. Pasangan nama sangat mirip (jarak edit <= 2) - kandidat typo/duplikat
SELECT
  a.category_name AS kategori_a,
  b.category_name AS kategori_b,
  levenshtein(UPPER(a.category_name), UPPER(b.category_name)) AS jarak_edit
FROM dim_category a
JOIN dim_category b ON a.category_name < b.category_name
WHERE levenshtein(UPPER(a.category_name), UPPER(b.category_name)) <= 3
ORDER BY jarak_edit;

-- ============================================================
-- B. PERFORMA KATEGORI
-- ============================================================

-- B1. Revenue BERSIH per kategori — HANYA order single-category (num_product_categories = 1)
--     Aman dijumlahkan; totalnya adalah subset revenue perusahaan (92,76% order).
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

-- B2. Frekuensi (incidence) per kategori — SELURUH order lewat bridge.
--     Kolom revenue SENGAJA TIDAK dihitung di sini (lihat peringatan di atas).
--     pct_dari_order_kategori-ini = share kategori ini yang order-nya multi-kategori.
SELECT
  c.category_name,
  COUNT(*) AS jumlah_order_menyentuh_kategori,
  SUM(CASE WHEN f.num_product_categories > 1 THEN 1 ELSE 0 END) AS jumlah_order_multi_kategori,
  ROUND(100.0 * SUM(CASE WHEN f.num_product_categories > 1 THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS pct_order_multi_kategori,
  ROUND(100.0 * SUM(CASE WHEN st.status_group = 'Cancelled' THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS cancellation_rate_pct,
  ROUND(AVG(f.total_qty), 2) AS avg_qty
FROM bridge_order_category b
JOIN fact_orders f ON f.order_id = b.order_id
JOIN dim_category c ON c.category_key = b.category_key
JOIN dim_status st ON st.status_key = f.status_key
GROUP BY 1
ORDER BY jumlah_order_menyentuh_kategori DESC;

-- ============================================================
-- C. KATEGORI vs UKURAN ORDER (pola grosir per kategori, order single-category)
-- ============================================================
WITH single_cat AS (
  SELECT f.order_id, f.total_qty, b.category_key
  FROM fact_orders f
  JOIN bridge_order_category b ON b.order_id = f.order_id
  WHERE f.num_product_categories = 1 AND f.total_qty IS NOT NULL
)
SELECT
  c.category_name,
  COUNT(*) AS jumlah_order,
  ROUND(AVG(sc.total_qty), 2) AS avg_qty,
  QUANTILE_CONT(sc.total_qty, 0.5) AS median_qty,
  ROUND(100.0 * SUM(CASE WHEN sc.total_qty >= 11 THEN 1 ELSE 0 END) / COUNT(*), 2)
    AS pct_indikasi_grosir
FROM single_cat sc
JOIN dim_category c ON c.category_key = sc.category_key
GROUP BY 1
HAVING COUNT(*) >= 50
ORDER BY avg_qty DESC;

-- ============================================================
-- D. CATEGORY CO-OCCURRENCE — pasangan kategori dalam order yang sama
-- ============================================================

-- D1. Top 20 pasangan kategori yang paling sering muncul bersama
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

-- D2. Untuk tiap kategori: pasangan yang paling sering menyertainya (top 1)
--     dan seberapa besar porsi order multi-kategori kategori itu yang berpasangan dengannya
WITH pair AS (
  SELECT
    ba.category_key AS cat_a, bb.category_key AS cat_b, COUNT(*) AS n
  FROM bridge_order_category ba
  JOIN bridge_order_category bb ON ba.order_id = bb.order_id AND ba.category_key <> bb.category_key
  GROUP BY 1, 2
),
ranked AS (
  SELECT cat_a, cat_b, n, ROW_NUMBER() OVER (PARTITION BY cat_a ORDER BY n DESC) AS rnk
  FROM pair
)
SELECT
  c1.category_name AS kategori,
  c2.category_name AS pasangan_tersering,
  r.n AS jumlah_order_bersama
FROM ranked r
JOIN dim_category c1 ON c1.category_key = r.cat_a
JOIN dim_category c2 ON c2.category_key = r.cat_b
WHERE r.rnk = 1
ORDER BY r.n DESC;

-- ============================================================
-- E. Tren bulanan — 5 kategori teratas (order single-category, by revenue B1)
-- ============================================================
WITH top5 AS (
  SELECT c.category_key, c.category_name
  FROM bridge_order_category b
  JOIN fact_orders f ON f.order_id = b.order_id AND f.num_product_categories = 1
  JOIN dim_status st ON st.status_key = f.status_key AND st.status_group = 'Completed'
  JOIN dim_category c ON c.category_key = b.category_key
  GROUP BY 1, 2
  ORDER BY SUM(f.total_pembayaran) DESC
  LIMIT 5
)
SELECT
  d.year_month,
  t.category_name,
  COUNT(*) AS jumlah_order,
  ROUND(SUM(CASE WHEN st.status_group = 'Completed' THEN f.total_pembayaran ELSE 0 END), 0)
    AS revenue_completed
FROM bridge_order_category b
JOIN fact_orders f ON f.order_id = b.order_id AND f.num_product_categories = 1
JOIN top5 t ON t.category_key = b.category_key
JOIN dim_date d ON d.date_key = f.date_key
JOIN dim_status st ON st.status_key = f.status_key
GROUP BY 1, 2
ORDER BY t.category_name, d.year_month;

-- ============================================================
-- F. Ringkasan cakupan: order single vs multi-kategori (konteks pembagi B1 vs B2)
-- ============================================================
SELECT
  CASE WHEN num_product_categories = 1 THEN 'Single-category' ELSE 'Multi-category' END AS tipe_order,
  COUNT(*) AS jumlah_order,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_order,
  ROUND(SUM(CASE WHEN st.status_group = 'Completed' THEN f.total_pembayaran ELSE 0 END), 0)
    AS revenue_completed,
  ROUND(100.0 * SUM(CASE WHEN st.status_group = 'Completed' THEN f.total_pembayaran ELSE 0 END)
        / SUM(SUM(CASE WHEN st.status_group = 'Completed' THEN f.total_pembayaran ELSE 0 END)) OVER (), 2)
    AS pct_revenue
FROM fact_orders f
JOIN dim_status st ON st.status_key = f.status_key
GROUP BY 1;

.mode duckbox
