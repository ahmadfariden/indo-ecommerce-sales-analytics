# Indonesia E-commerce Sales Analytics

> Status: 🚧 Skeleton — belum ada satu pun query atau data yang dieksekusi.

Portfolio project data analyst berbasis dataset transaksional e-commerce Indonesia
(`indonesia_ecommerce_sales_challenging.csv`), grain **1 baris = 1 order**.

## Scope singkat

Project ini fokus ke: Sales & Revenue Performance, Order Status/Cancellation/Return Behavior,
Payment Method Behavior, Regional Performance, Product Category Performance (agregat +
co-occurrence), dan Shipping Behavior.

Project ini **tidak** mencakup: Customer Segmentation/RFM, Repeat-Purchase Rate, CLV, atau
Market Basket Analysis — dataset tidak punya `customer_id` dan tidak punya item-level basket.
Detail lengkap ada di roadmap (`docs/` — menyusul di Tahap 2).

## Struktur folder

```
data/
  raw/          # CSV asli, read-only, source of truth
  processed/    # hasil cleaning/validation
  data_mart/    # parquet mart siap dashboard
sql/            # 02_*.sql s.d. 14_*.sql, urutan sesuai roadmap
docs/           # methodology, assumptions, insights, data dictionary
dashboard/      # file Power BI (.pbix)
screenshots/    # screenshot dashboard untuk publishing
```

## Workflow

SETUP → PROFILE → CLEAN → VALIDATE → EDA → MODEL → ANALYZE → MART → DASHBOARD → COMMUNICATE → QA/PUBLISH

## Cara reproduce

_Akan dilengkapi setelah data collection & cleaning selesai (Tahap 3–5)._

## Roadmap

Lihat roadmap lengkap (governance, traceability matrix, DoD per tahap) di file terpisah
yang menyertai proyek ini.
