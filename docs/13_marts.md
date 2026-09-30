# 13 — Data Mart

## Input
- Star schema dari Tahap 8 (`fact_orders` dan seluruh dimensi)
- View `v_orders_region` (Tahap 11) dan `v_shipping_parsed` (Tahap 13/shipping)
- Seluruh temuan Tahap 9–13 (`docs/08_*.md` s.d. `docs/12_*.md`)
- Dijalankan via `sql/13_marts.sql`

## Proses Analisis
Membentuk 11 table mart denormalized dari star schema, masing-masing merangkum satu tahap Business Analysis, lalu memvalidasi rekonsiliasi jumlah order terhadap `fact_orders` (18.868) untuk mart yang cakupannya seluruh order, dan terhadap jumlah order Batal (2.573) untuk `mart_cancellation_reason`.

## Temuan

**Rekonsiliasi 100% cocok** untuk semua mart yang seharusnya mencakup seluruh order:
| Mart | Nilai | Ekspektasi |
|---|---:|---:|
| mart_overview_kpi.total_orders | 18.868 | 18.868 |
| mart_monthly_trend (SUM jumlah_order) | 18.868 | 18.868 |
| mart_order_status (SUM jumlah_order) | 18.868 | 18.868 |
| mart_payment_method (SUM jumlah_order) | 18.868 | 18.868 |
| mart_regional_province (SUM jumlah_order) | 18.868 | 18.868 |
| mart_shipping_kurir (SUM jumlah_order) | 18.868 | 18.868 |
| mart_cancellation_reason (SUM jumlah_order) | 2.573 | 2.573 |

**Jumlah baris tiap mart:**
| Mart | Baris | Catatan cakupan |
|---|---:|---|
| mart_overview_kpi | 1 | Scorecard tunggal |
| mart_monthly_trend | 22 | 24 bulan periode dikurangi 2 bulan missing period (Tahap 4) |
| mart_order_status | 5 | Seluruh status_pesanan |
| mart_cancellation_reason | 14 | Seluruh grup alasan pembatalan |
| mart_payment_method | 12 | Seluruh metode pembayaran |
| mart_regional_province | 34 | Seluruh provinsi |
| mart_regional_city | 30 | Top 30 dari 418 kota (scope sengaja parsial) |
| mart_category | 37 | Order single-category saja; 1 dari 38 kategori (Tempat Sampah) tidak muncul karena 100% order-nya multi-kategori |
| mart_category_pair | 20 | Top 20 dari total pasangan co-occurrence (scope sengaja parsial) |
| mart_shipping_kurir | 6 | Seluruh kurir termasuk "Tidak disebutkan (generik)" |
| mart_shipping_region_failure | 13 | Kombinasi kurir × wilayah dengan ≥50 order (scope sengaja parsial) |

Tidak ada anomali dari validasi ini — seluruh mart yang seharusnya lengkap memang lengkap, dan mart yang cakupannya sengaja dibatasi (top N atau ambang minimum) sesuai desain yang sudah ditetapkan di tahap analisis masing-masing.

## Output
- 11 table DuckDB di `indo.duckdb`: `mart_overview_kpi`, `mart_monthly_trend`, `mart_order_status`, `mart_cancellation_reason`, `mart_payment_method`, `mart_regional_province`, `mart_regional_city`, `mart_category`, `mart_category_pair`, `mart_shipping_kurir`, `mart_shipping_region_failure`.
- Table ini yang akan diekspor ke parquet di Tahap 15 dan dipakai langsung sebagai sumber data Power BI.

## Assumptions
- Aturan denominator (cancellation rate = Batal / Total Orders; return rate = Completed dengan retur / Completed Orders) dibawa apa adanya dari Tahap 6 ke semua mart yang relevan.
- `mart_category` sengaja hanya mencakup order single-category (92,76% order), mengikuti keputusan Tahap 12 untuk menghindari dobel-hitung revenue pada order multi-kategori. Ini bukan cakupan penuh 100% order dan tidak direkonsiliasi ke 18.868.
- `mart_regional_city`, `mart_category_pair`, dan `mart_shipping_region_failure` sengaja dibatasi (top N atau ambang minimum order) sesuai keputusan di tahap analisis asalnya, bukan kesalahan cakupan.
- `is_incomplete_month` di `mart_monthly_trend` dihitung otomatis dari ada/tidaknya order berstatus In-Progress di bulan itu, sehingga akan tetap valid kalau nanti dataset diperbarui dan bulan lain jadi belum matang — bukan hardcode ke November 2025.

## Batasan Data
- Mart ini adalah ringkasan; untuk detail granular yang tidak masuk top N (mis. kota di luar top 30, pasangan kategori di luar top 20), rujuk kembali ke query asli di `sql/08` s.d. `sql/12` atau ke `docs/08_*.md` s.d. `docs/12_*.md`.
- Semua batasan data yang sudah dicatat di Tahap 9–13 (mis. revenue pembatalan tidak bisa dihitung, tidak ada `customer_id`, November 2025 belum matang) tetap berlaku untuk mart ini karena mart hanya meringkas, bukan menambah informasi baru.

## Kesimpulan
Sebelas mart berhasil dibentuk dan seluruhnya lolos rekonsiliasi terhadap star schema tanpa anomali. Data siap diekspor ke parquet di Tahap 15 untuk dipakai sebagai sumber dashboard Power BI.
