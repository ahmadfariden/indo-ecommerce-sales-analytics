-- ============================================================
-- File   : sql/14_parquet_export.sql
-- Tujuan : Tahap 15 — Parquet Export: ekspor seluruh mart ke
--          data/data_mart/*.parquet, siap dikonsumsi Power BI.
-- Prasyarat : sql/13_marts.sql sudah dijalankan (11 mart ada)
-- ============================================================

.mode markdown

COPY mart_overview_kpi            TO 'data/data_mart/mart_overview_kpi.parquet'            (FORMAT PARQUET);
COPY mart_monthly_trend           TO 'data/data_mart/mart_monthly_trend.parquet'           (FORMAT PARQUET);
COPY mart_order_status            TO 'data/data_mart/mart_order_status.parquet'            (FORMAT PARQUET);
COPY mart_cancellation_reason     TO 'data/data_mart/mart_cancellation_reason.parquet'     (FORMAT PARQUET);
COPY mart_payment_method          TO 'data/data_mart/mart_payment_method.parquet'          (FORMAT PARQUET);
COPY mart_regional_province       TO 'data/data_mart/mart_regional_province.parquet'       (FORMAT PARQUET);
COPY mart_regional_city           TO 'data/data_mart/mart_regional_city.parquet'           (FORMAT PARQUET);
COPY mart_category                TO 'data/data_mart/mart_category.parquet'                (FORMAT PARQUET);
COPY mart_category_pair           TO 'data/data_mart/mart_category_pair.parquet'           (FORMAT PARQUET);
COPY mart_shipping_kurir          TO 'data/data_mart/mart_shipping_kurir.parquet'          (FORMAT PARQUET);
COPY mart_shipping_region_failure TO 'data/data_mart/mart_shipping_region_failure.parquet' (FORMAT PARQUET);

-- ============================================================
-- VALIDASI: baca balik tiap parquet, bandingkan row count dengan table asal
-- ============================================================
SELECT 'mart_overview_kpi' AS mart,
  (SELECT COUNT(*) FROM mart_overview_kpi) AS baris_table,
  (SELECT COUNT(*) FROM read_parquet('data/data_mart/mart_overview_kpi.parquet')) AS baris_parquet
UNION ALL
SELECT 'mart_monthly_trend',
  (SELECT COUNT(*) FROM mart_monthly_trend),
  (SELECT COUNT(*) FROM read_parquet('data/data_mart/mart_monthly_trend.parquet'))
UNION ALL
SELECT 'mart_order_status',
  (SELECT COUNT(*) FROM mart_order_status),
  (SELECT COUNT(*) FROM read_parquet('data/data_mart/mart_order_status.parquet'))
UNION ALL
SELECT 'mart_cancellation_reason',
  (SELECT COUNT(*) FROM mart_cancellation_reason),
  (SELECT COUNT(*) FROM read_parquet('data/data_mart/mart_cancellation_reason.parquet'))
UNION ALL
SELECT 'mart_payment_method',
  (SELECT COUNT(*) FROM mart_payment_method),
  (SELECT COUNT(*) FROM read_parquet('data/data_mart/mart_payment_method.parquet'))
UNION ALL
SELECT 'mart_regional_province',
  (SELECT COUNT(*) FROM mart_regional_province),
  (SELECT COUNT(*) FROM read_parquet('data/data_mart/mart_regional_province.parquet'))
UNION ALL
SELECT 'mart_regional_city',
  (SELECT COUNT(*) FROM mart_regional_city),
  (SELECT COUNT(*) FROM read_parquet('data/data_mart/mart_regional_city.parquet'))
UNION ALL
SELECT 'mart_category',
  (SELECT COUNT(*) FROM mart_category),
  (SELECT COUNT(*) FROM read_parquet('data/data_mart/mart_category.parquet'))
UNION ALL
SELECT 'mart_category_pair',
  (SELECT COUNT(*) FROM mart_category_pair),
  (SELECT COUNT(*) FROM read_parquet('data/data_mart/mart_category_pair.parquet'))
UNION ALL
SELECT 'mart_shipping_kurir',
  (SELECT COUNT(*) FROM mart_shipping_kurir),
  (SELECT COUNT(*) FROM read_parquet('data/data_mart/mart_shipping_kurir.parquet'))
UNION ALL
SELECT 'mart_shipping_region_failure',
  (SELECT COUNT(*) FROM mart_shipping_region_failure),
  (SELECT COUNT(*) FROM read_parquet('data/data_mart/mart_shipping_region_failure.parquet'));

-- Sanity check tambahan: baca ulang salah satu nilai kunci dari parquet
-- (harus identik dengan sumbernya, bukan cuma cocok row count)
SELECT
  (SELECT total_orders FROM mart_overview_kpi) AS total_orders_table,
  (SELECT total_orders FROM read_parquet('data/data_mart/mart_overview_kpi.parquet')) AS total_orders_parquet,
  (SELECT revenue_completed FROM mart_overview_kpi) AS revenue_table,
  (SELECT revenue_completed FROM read_parquet('data/data_mart/mart_overview_kpi.parquet')) AS revenue_parquet;

.mode duckbox
