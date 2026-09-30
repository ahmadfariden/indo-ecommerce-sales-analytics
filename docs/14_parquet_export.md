# 14 — Parquet Export

## Input
- 11 mart dari Tahap 14 (`docs/13_marts.md`)
- Dijalankan via `sql/14_parquet_export.sql`

## Proses Analisis
1. Ekspor tiap mart ke `data/data_mart/*.parquet` dengan `COPY ... TO ... (FORMAT PARQUET)`.
2. Baca ulang tiap file parquet dan bandingkan row count dengan table sumbernya.
3. Sanity check tambahan: baca `total_orders` dan `revenue_completed` langsung dari `mart_overview_kpi.parquet`, bandingkan dengan nilai di table.

## Temuan
- **Seluruh 11 file parquet berhasil dibuat**, row count identik dengan table sumbernya untuk semua mart (1 s.d. 37 baris, tergantung mart).
- **Sanity check nilai kunci juga identik:** `total_orders` 18.868 = 18.868, `revenue_completed` Rp 950.963.704 = Rp 950.963.704 — membuktikan proses ekspor tidak mengubah tipe data atau presisi angka.
- Tidak ditemukan anomali; tidak ada perbedaan yang perlu diinvestigasi.

## Output
- 11 file di `data/data_mart/`: `mart_overview_kpi.parquet`, `mart_monthly_trend.parquet`, `mart_order_status.parquet`, `mart_cancellation_reason.parquet`, `mart_payment_method.parquet`, `mart_regional_province.parquet`, `mart_regional_city.parquet`, `mart_category.parquet`, `mart_category_pair.parquet`, `mart_shipping_kurir.parquet`, `mart_shipping_region_failure.parquet`.
- File-file ini adalah sumber data langsung untuk dashboard Power BI di Part 3 roadmap.

## Assumptions
- Tidak ada asumsi tambahan di tahap ini — proses ekspor bersifat mekanis dari mart yang sudah divalidasi di Tahap 14.

## Batasan Data
- File parquet ini adalah snapshot dari `indo.duckdb` pada saat ekspor dijalankan. Kalau `sales_raw` atau `sales` berubah (mis. ada koreksi cleaning di kemudian hari), seluruh pipeline dari Tahap 5 harus dijalankan ulang sampai ke tahap ini sebelum parquet dipakai lagi di Power BI.
- File `.parquet` di-commit ke git (berbeda dari `indo.duckdb` yang di-`.gitignore`), karena inilah yang dikonsumsi Power BI secara langsung.

## Kesimpulan
Seluruh mart berhasil diekspor ke parquet tanpa kehilangan baris atau presisi nilai. Dengan ini, **seluruh 15 tahap SQL di roadmap (Tahap 0–15) selesai**: skeleton, business understanding, data collection, profiling, cleaning, validation, EDA, data modeling, lima analisis bisnis (order status/cancellation/return, payment method, regional, product category, shipping), data mart, dan parquet export. Data siap dipakai untuk membangun dashboard Power BI di Part 3 roadmap.
