# Indonesia E-commerce Sales Analytics

> Status: ✅ Selesai — Tahap 0–15 (SQL/data pipeline) dan dashboard Power BI
> 5 halaman sudah lengkap.

Portfolio project data analyst berbasis dataset transaksional e-commerce Indonesia
(`indonesia_ecommerce_sales_challenging.csv`, 18.868 baris, 19 kolom), grain
**1 baris = 1 order**. Dibangun pakai SQL/DuckDB untuk pipeline data, Power BI
untuk dashboard.

## Scope singkat

Project ini fokus ke: Sales & Revenue Performance, Order Status/Cancellation/Return Behavior,
Payment Method Behavior, Regional Performance, Product Category Performance (agregat +
co-occurrence), dan Shipping Behavior.

Project ini **tidak** mencakup: Customer Segmentation/RFM, Repeat-Purchase Rate, CLV, atau
Market Basket Analysis — dataset tidak punya `customer_id` dan tidak punya item-level basket.
Detail lengkap ada di `docs/business_understanding.md`.

## Insight utama

6 insight utama (dengan bukti angka dan rekomendasi) ada di
[`docs/insights.md`](docs/insights.md). Ringkasan tiga yang paling penting:

1. **Cancellation rate Online Payment yang terlihat tinggi (18,68%) sebenarnya
   didorong auto-cancel "belum dibayar"** — setelah dikeluarkan, turun ke
   10,74%, di bawah COD (13,43%).
2. **Pengiriman gagal di luar Jawa adalah masalah kurir yang sama (SPX, J&T)
   yang gagal lebih sering**, bukan pergantian kurir — tingkat kegagalan SPX
   naik 11,5x dari Jawa ke Sulawesi.
3. **COD mendominasi 54,6% order tapi cuma 37,5% revenue** — AOV-nya jauh di
   bawah metode pembayaran digital/kartu.

## Dashboard

File Power BI: [`dashboard/indo_ecommerce_sales_analytics.pbix`](dashboard/indo_ecommerce_sales_analytics.pbix)
— 5 halaman:

1. **Overview** — KPI ringkasan, tren bulanan, komposisi status order
2. **Status & Cancellation** — alasan pembatalan per pihak, dampak auto-cancel
3. **Payment Method** — performa per metode pembayaran, volume vs AOV
4. **Regional** — performa provinsi/kota, porsi COD vs cancellation rate
5. **Category & Shipping** — performa kategori produk, co-occurrence, performa kurir

Screenshot tiap halaman ada di [`screenshots/`](screenshots/).

## Struktur folder

```
data/
  raw/          # CSV asli, read-only, source of truth
  processed/    # (tidak dipakai — cleaning dilakukan in-database via DuckDB)
  data_mart/    # 11 file parquet, hasil Tahap 14-15, sumber dashboard
sql/            # 02_*.sql s.d. 14_*.sql, satu file per tahap roadmap
docs/           # business understanding, findings tiap tahap, insights
dashboard/      # indo_ecommerce_sales_analytics.pbix
screenshots/    # screenshot tiap halaman dashboard
```

## Cara reproduce

Prasyarat: [DuckDB CLI](https://duckdb.org/docs/installation/), Power BI Desktop
(untuk buka `.pbix`).

```powershell
# 1. Clone repo, taruh CSV mentah di data/raw/
git clone https://github.com/ahmadfariden/indo-ecommerce-sales-analytics.git
cd indo-ecommerce-sales-analytics

# 2. Jalankan seluruh pipeline SQL berurutan (02 s.d. 14)
.\duckdb.exe indo.duckdb -c ".read sql/02_data_collection.sql"
.\duckdb.exe indo.duckdb -c ".read sql/03_data_profiling.sql"
.\duckdb.exe indo.duckdb -c ".read sql/04_data_cleaning.sql"
.\duckdb.exe indo.duckdb -c ".read sql/05_data_validation.sql"
.\duckdb.exe indo.duckdb -c ".read sql/06_eda.sql"
.\duckdb.exe indo.duckdb -c ".read sql/07_data_modeling.sql"
.\duckdb.exe indo.duckdb -c ".read sql/08_order_status_cancellation_return.sql"
.\duckdb.exe indo.duckdb -c ".read sql/09_payment_method.sql"
.\duckdb.exe indo.duckdb -c ".read sql/10_regional_performance.sql"
.\duckdb.exe indo.duckdb -c ".read sql/11_product_category.sql"
.\duckdb.exe indo.duckdb -c ".read sql/12_shipping_behavior.sql"
.\duckdb.exe indo.duckdb -c ".read sql/13_marts.sql"
.\duckdb.exe indo.duckdb -c ".read sql/14_parquet_export.sql"

# 3. Buka dashboard/indo_ecommerce_sales_analytics.pbix di Power BI Desktop,
#    Refresh kalau data/data_mart/*.parquet berubah
```

Catatan: `sql/10_regional_performance.sql` dan `sql/12_shipping_behavior.sql`
masing-masing membuat view (`v_orders_region`, `v_shipping_parsed`) yang
dipakai lagi oleh `sql/13_marts.sql` — jalankan berurutan, jangan di-skip.

## Dokumentasi per tahap

Setiap file `sql/*.sql` punya `.md` pendamping di `docs/` (Input, Proses
Analisis, Temuan, Output, Assumptions, Kesimpulan), mengikuti aturan main yang
disepakati di awal project. Mulai dari `docs/02_data_collection.md` sampai
`docs/14_parquet_export.md`.
