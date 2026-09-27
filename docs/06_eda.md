# 06 — EDA (Exploratory Data Analysis)

## Input
- Table `sales` (hasil Tahap 5, divalidasi di Tahap 6)
- Definisi Analytical Population dari `docs/05_data_validation.md` (Total/Completed/Cancelled/In-Progress Orders)
- Dijalankan via `sql/06_eda.sql`

## Proses Analisis
1. Hitung KPI ringkas: cancellation rate, AOV proxy (basis Completed Orders), return rate (basis Completed Orders).
2. Tren bulanan order count & revenue.
3. Revenue & jumlah order per `status_pesanan`.
4. Revenue & cancellation rate per `metode_pembayaran`.
5. Top 10 provinsi by order, revenue, dan cancellation rate.
6. Distribusi `num_product_categories` (single vs multi-category order) dan rata-rata qty per bucket.
7. Bucket `total_qty` untuk identifikasi pola grosir.
8. Distribusi `opsi_pengiriman` + rata-rata ongkir dibayar pembeli vs perkiraan ongkos kirim.
9. Korelasi ongkir dibayar pembeli vs total pembayaran (deskriptif, non-causal) + bucket.
10. Ringkasan quantile `total_qty`, `total_pembayaran`, `ongkir_dibayar_pembeli`.

## Temuan

**Overview:**
- Cancellation rate: **13,64%** (2.573 dari 18.868 order)
- AOV Proxy (basis Completed Orders): **Rp 59.269**
- Return rate: **0,89%** (143 dari 16.045 Completed Orders punya `total_returned_qty > 0`) — relatif rendah
- Revenue Completed Orders: **Rp 950.963.704** (99,9% dari total revenue keseluruhan)

**Tren bulanan:** Revenue naik dari akhir 2023 (~Rp 24 juta/bulan), puncak di **Agustus–Oktober 2024** (Rp 66–72 juta/bulan), lalu menurun sepanjang awal–pertengahan 2025 (turun ke ~Rp 29–35 juta/bulan di Apr–Jun 2025), sebelum sedikit rebound di Sep–Okt 2025 (Rp 47–62 juta). Order count mengikuti pola serupa.

**Status Pesanan vs revenue:** Order **Batal** = Rp 0 revenue (100% baris Batal memang punya `total_pembayaran` 0, konfirmasi bahwa order batal tidak pernah tercatat ada pembayaran masuk). Status non-Selesai lain (Diterima window retur, Sedang Dikirim, Telah Dikirim) tetap punya revenue tercatat (order sudah dibayar, belum final).

**Metode Pembayaran — temuan penting:**
- **COD** dominan (10.306 order, 54,6%) dengan cancellation rate 13,43% (dekat rata-rata keseluruhan).
- **Online Payment**, meski sudah dibayar di muka, justru punya cancellation rate **lebih tinggi dari COD** (18,68% vs 13,43%) — kontra-intuitif, karena biasanya metode prabayar diasosiasikan dengan komitmen beli yang lebih kuat.
- **ShopeePay** justru cancellation rate paling rendah di antara metode besar (8,81%).
- Metode niche seperti **Indomaret/i.Saku** (44,74%) dan **Alfamart/Alfamidi/Dan+Dan** (47,06%) punya cancellation rate jauh di atas rata-rata, meski volumenya kecil (38 dan 34 order).

**Regional (Top 10):** Jawa Barat memimpin di order (6.078) dan revenue (Rp 246 juta) dengan cancellation rate **terendah** di top 10 (11,4%). Riau (18,67%) dan Sumatera Selatan (15,89%) punya cancellation rate tertinggi di antara top 10 provinsi meski volumenya jauh lebih kecil.

**Kategori produk:** 92,76% order cuma 1 kategori produk. Rata-rata qty naik seiring jumlah kategori (1 kategori: avg qty 2,41 → 11 kategori: avg qty 17,5) — pola yang masuk akal (order makin besar/beragam, makin banyak barang).

**Pola grosir:** 79,83% order retail kecil (qty 1-2). Hanya **2,28%** order (430 order) yang qty ≥11, indikasi grosir — segmen kecil tapi berpotensi bernilai tinggi per order.

**Shipping:** `Hemat Kargo-SPX Hemat` mendominasi (11.571 order, 61,3%) dengan ongkir dibayar pembeli rata-rata cuma Rp 4.411 padahal perkiraan ongkos kirim aslinya Rp 16.832 — subsidi/promo ongkir besar di opsi ini. Opsi kargo berat (`Kargo-JNE Trucking`, `Kargo-J&T Cargo`) punya ongkir dibayar pembeli jauh lebih tinggi (~Rp 21.500–21.800), konsisten dengan pengiriman barang lebih besar/berat.

**Ongkir vs total pembayaran:** Korelasi **0,4545** (positif sedang, bukan kuat) — order dengan total pembayaran lebih besar cenderung bayar ongkir lebih besar, tapi hubungannya tidak linear ketat, kemungkinan besar karena banyak subsidi ongkir. Bucket menunjukkan pola naik cukup jelas: <50rb → avg ongkir Rp 1.727; 50-150rb → Rp 10.102; 150-300rb → Rp 21.254; >=500rb → Rp 49.948 (ada sedikit penurunan di bucket 300-500rb yang perlu dicatat sebagai non-monoton, bukan tren sempurna).

**Distribusi numerik:** `total_qty` sangat skewed (median 1, p75 2, max 256) — mayoritas retail kecil dengan ekor grosir panjang. `total_pembayaran` median Rp 21.800. `ongkir_dibayar_pembeli` median **Rp 0** (banyak order gratis ongkir), p75 baru Rp 3.000.

## Output
- Tidak ada table baru — seluruhnya query eksploratif (read-only) terhadap `sales`.
- Pola-pola di atas jadi basis keputusan struktur dimensional model di Tahap 8 dan detail business analysis di Part 3 (Tahap 9-13).

## Assumptions
- Return rate dihitung dari indikator `total_returned_qty > 0` pada Completed Orders, sesuai definisi Analytical Population Tahap 6 (denominator Completed Orders, bukan Total Orders).
- Bucket `total_qty` (1-2 / 3-5 / 6-10 / 11+) dan bucket `total_pembayaran` (<50rb dst.) adalah threshold eksploratif untuk EDA, bukan keputusan final — boleh disesuaikan lagi kalau Business Analysis di Tahap 9-13 butuh cutoff berbeda.
- Korelasi ongkir vs total pembayaran (0,4545) diperlakukan murni deskriptif/korelasional, tidak diinterpretasikan sebagai hubungan sebab-akibat, sesuai batas Analytical Scope di `docs/business_understanding.md`.

## Kesimpulan
EDA mengonfirmasi beberapa pola kuat: dominasi COD dan opsi shipping hemat, konsentrasi order di Jawa Barat/Banten/DKI Jakarta, mayoritas order retail kecil dengan ekor grosir tipis, dan return rate keseluruhan yang rendah (0,89%). Temuan paling menarik untuk didalami di Business Analysis nanti adalah **cancellation rate Online Payment yang lebih tinggi dari COD** (berlawanan dengan ekspektasi umum) dan **subsidi ongkir besar pada opsi shipping terpopuler** — dua hal ini layak jadi kandidat insight utama di dashboard nanti. Data siap lanjut ke Tahap 8 — Data Modeling.
