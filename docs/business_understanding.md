# Business Understanding — Indonesia E-commerce Sales Analytics

> Tahap 2 dari roadmap. Mencakup Data Feasibility Check, Analytical Scope,
> Business Questions, dan Success Criteria. Aktivitas profiling/cleaning
> **tidak** termasuk di dokumen ini — lihat `docs/profiling_findings.md`
> (menyusul di Tahap 18) untuk itu.

---

## 1. Data Feasibility Check

Inventarisasi apa yang benar-benar tersedia di dataset sebelum menentukan KPI:

- ❌ **Tidak ada `customer_id`/`user_id`** — grain data adalah order, bukan
  customer. Segmentasi customer, repeat-purchase rate, dan CLV **tidak bisa
  dihitung**.
- ❌ **Tidak ada item-level basket** — `product_categories` /
  `num_product_categories` cuma ringkasan kategori + jumlah kategori per
  order, bukan daftar SKU dengan qty masing-masing. Market basket / product
  pair analysis **tidak bisa dilakukan**, hanya analisis di level kategori
  agregat.
- ⚠️ **Dua bulan hilang total dari data** (Desember 2024, Juli 2025 — 0
  baris, bukan 0 transaksi) — wajib diperlakukan sebagai *missing period*,
  bukan nilai 0, di semua tren bulanan/YoY.
- ⚠️ **283 baris `total_qty` / `Metode Pembayaran` missing**, overlap NULL
  antar dua kolom hanya 3 baris (independen, bukan pola yang sama) — perlu
  keputusan eksplisit sebelum agregasi.
- ✅ Yang tersedia: metrik order (qty, weight, discount, shipping cost,
  returned qty, payment amount), status order & alasan pembatalan, metode
  pembayaran, opsi pengiriman, lokasi (kota/provinsi), waktu order & tanggal
  order, kategori produk agregat.

## 2. Analytical Scope

**IN scope:**
- Sales & Revenue Performance (order-level)
- Order Status, Cancellation & Return Behavior
- Payment Method Behavior
- Regional Performance
- Product Category Performance (agregat), termasuk category co-occurrence
- Shipping Behavior (distribusi opsi pengiriman, pola ongkir vs total
  pembayaran)

**OUT of scope:**
- Customer Segmentation / RFM (tidak ada `customer_id`)
- Repeat-Purchase Rate & Customer Lifetime Value
- Market Basket / Product Pair Analysis (tidak ada item-level basket)
- Forecasting
- Causal Inference
- Machine Learning modeling

Seluruh analisis bersifat **descriptive** dan **diagnostic** analytics.

## 3. Business Questions

1. Provinsi/kota mana penyumbang order & revenue terbesar?
2. Metode pembayaran apa paling dominan dan apakah berkorelasi dengan
   pembatalan?
3. Apa alasan pembatalan paling sering?
4. Bagaimana tren bulanan (dengan 2 bulan gap diperlakukan sebagai missing
   period)?
5. Kategori produk apa paling sering dibeli, dan mana yang polanya grosir
   (qty tinggi)?
6. Kategori produk apa yang paling sering muncul bersamaan dalam satu
   order?
7. Berapa return rate keseluruhan dan apakah ada pola per provinsi/kategori?
8. Bagaimana pola hubungan antara ongkir yang dibayar pembeli dan total
   pembayaran, serta bagaimana distribusi opsi pengiriman?

## 4. Success Criteria

Dashboard 5 halaman + minimal 3 insight actionable berbasis bukti, dengan
setiap KPI card yang bisa ditelusuri balik ke raw data.

---

## Definition of Done

- [x] Business Questions & Success Criteria tertulis
- [x] Analytical Scope (IN/OUT) sudah dikunci
- [x] Data Feasibility Check sudah dikunci
- [ ] Git checkpoint sudah di-commit

**Checkpoint:** `chore: define business objectives, KPI, and feasibility check`
