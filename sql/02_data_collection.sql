-- ============================================================
-- File   : sql/02_data_collection.sql
-- Tujuan : Tahap 3 — Data Collection: ingest CSV mentah ke DuckDB
--          (sales_raw, semua kolom ALL_VARCHAR, source of truth)
-- Status : eksekusi ulang dari Fase 0, verifikasi angka terhadap referensi
-- Referensi (v1 lama) : total_rows = 18868, total_columns = 19,
--                        full_duplicate_rows = 0
-- ============================================================

-- Ingest raw CSV apa adanya, seluruh kolom sebagai VARCHAR dulu
CREATE OR REPLACE TABLE sales_raw AS
SELECT *
FROM read_csv_auto('data/raw/indonesia_ecommerce_sales_challenging.csv', ALL_VARCHAR=TRUE);

-- ------------------------------------------------------------
-- Initial inventory
-- ------------------------------------------------------------
SELECT COUNT(*) AS total_rows FROM sales_raw;

SELECT COUNT(*) AS total_columns FROM (DESCRIBE sales_raw);

-- Cek duplikat baris penuh
SELECT
  (SELECT COUNT(*) FROM sales_raw)
  - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM sales_raw)) AS full_duplicate_rows;

-- Lihat struktur kolom
DESCRIBE sales_raw;
