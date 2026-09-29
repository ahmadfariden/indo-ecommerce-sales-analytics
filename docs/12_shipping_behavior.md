# 12 — Shipping Behavior

## Input
- Star schema dari Tahap 8: `fact_orders`, `dim_shipping`, `dim_status`, `dim_cancellation_reason`
- View `v_orders_region` dari Tahap 11 (`sql/10_regional_performance.sql`)
- Temuan Tahap 9 (`docs/08_order_status_cancellation_return.md`) dan Tahap 11 (`docs/10_regional_performance.md`)
- Dijalankan via `sql/12_shipping_behavior.sql`

## Proses Analisis
1. Tinjau seluruh 45 nilai `opsi_pengiriman` mentah.
2. Parsing jadi `kurir` (andal, berbasis nama SPX/JNE/J&T/GrabExpress/GoSend) dan `tier_layanan` (analitik/perkiraan, berbasis kata kunci Hemat Kargo/Kargo/Reguler/Instant/Same Day/Next Day/dst.), lewat view `v_shipping_parsed`.
3. Validasi parsing: cek baris yang gagal terklasifikasi. Ditemukan satu bug (`JNE Reguler` salah masuk "Lainnya"), diperbaiki, divalidasi ulang — bersih.
4. Performa per kurir (D) dan per tier layanan (E): order, revenue, AOV, cancellation, return rate, ongkir, berat.
5. Subsidi ongkir per kurir (F): rasio ongkir dibayar pembeli terhadap perkiraan ongkos kirim.
6. Pengiriman gagal per kurir (G, menuntaskan Tahap 9) dan per kurir × wilayah (H, menuntaskan Tahap 11).
7. Sanity check: apakah tier Kargo benar-benar membawa order lebih berat (I).

## Temuan

### Temuan paling penting: opsi pengiriman generik = 100% order Batal
Tujuh opsi pengiriman yang hanya menyebut tier tanpa nama kurir (`Hemat Kargo`, `Kargo`, `Reguler (Cashless)`, `Same Day`, `Instant`, `Instant (Versi Lama)`, `Next Day`) — total 697 order — **seluruhnya berstatus Batal, tanpa satu pun Completed** (cancellation rate 100%, revenue Rp 0). Pola ini konsisten sempurna: begitu nama kurir tercatat, order itu selalu berlanjut ke tahap berikutnya (Completed atau minimal In-Progress). Penjelasan paling masuk akal: sistem baru mencatat nama kurir spesifik setelah order lolos tahap pemesanan; kalau dibatalkan sebelum itu (mis. auto-cancel karena belum dibayar atau dibatalkan pembeli di awal), yang tersimpan cuma nama tier generik. Ini bukan produk analitik untuk dashboard performa kurir, tapi **indikator siap pakai untuk mendeteksi pembatalan dini** — bisa jadi sinyal terpisah di luar cakupan Tahap 9.

### A. Daftar 45 opsi pengiriman
Opsi terbanyak: `Hemat Kargo-SPX Hemat` (11.571, 61,3% dari seluruh order), `Reguler (Cashless)-SPX Standard` (4.047, 21,4%). Dua opsi ini saja sudah 82,7% dari seluruh order. Sisanya sangat terfragmentasi — 20 dari 45 opsi punya ≤10 order.

### D. Performa per kurir
| Kurir | Order | % order | Completed | Revenue Completed | AOV | Cancel rate | Return rate | Avg ongkir dibayar | Avg berat |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| SPX (Shopee Xpress) | 16.998 | 90,09% | 15.002 | Rp 716.901.245 | Rp 47.787 | 10,29% | 0,86% | Rp 4.290 | 1.508 g |
| Tidak disebutkan (generik) | 697 | 3,69% | 0 | Rp 0 | — | 100,00% | — | — | — |
| J&T | 557 | 2,95% | 475 | Rp 126.791.799 | Rp 266.930 | 14,36% | 0,63% | Rp 20.555 | 8.529 g |
| JNE | 524 | 2,78% | 489 | Rp 85.367.797 | Rp 174.576 | 6,49% | 2,25% | Rp 11.458 | 7.282 g |
| GoSend | 67 | 0,36% | 60 | Rp 15.467.423 | Rp 257.790 | 10,45% | 0,00% | Rp 15.750 | 8.998 g |
| GrabExpress | 25 | 0,13% | 19 | Rp 6.435.440 | Rp 338.707 | 24,00% | 0,00% | Rp 5.079 | 8.492 g |

- **SPX mendominasi total (90,1% order)** dengan AOV terendah (Rp 47.787) dan berat rata-rata teringan (1.508 g) — konsisten dengan pola order retail kecil yang mendominasi keseluruhan data (dari EDA).
- **JNE punya cancellation rate terendah (6,49%)**, kurang dari setengah SPX (10,29%) dan J&T (14,36%), meski volumenya kecil (524 order, dari mana 22 di antaranya adalah "JNE Reguler" yang sempat salah terklasifikasi).
- **J&T dan GoSend punya AOV tinggi** (Rp 266.930 dan Rp 257.790) dengan berat rata-rata jauh lebih besar (8.529 g dan 8.998 g) — kurir ini tampaknya dipakai untuk order besar/berat.
- **JNE punya return rate tertinggi (2,25%)**, sekitar 2,6 kali rata-rata keseluruhan (0,89%, dari Tahap 9), meski basisnya kecil (11 dari 489 Completed).
- **GrabExpress punya cancellation rate tertinggi di antara kurir bernama (24,00%)**, tapi basisnya sangat kecil (25 order), jadi tidak diinterpretasikan lebih jauh.

### E. Performa per tier layanan
| Tier | Order | % order | Cancel rate | Avg ongkir dibayar | Avg berat | Avg qty |
|---|---:|---:|---:|---:|---:|---:|
| Hemat Kargo | 12.683 | 67,22% | 14,01% | Rp 5.211 | 1.342 g | 1,99 |
| Reguler (Cashless) | 4.815 | 25,52% | 11,03% | Rp 1.645 | 1.054 g | 1,99 |
| Kargo | 421 | 2,23% | 20,43% | Rp 22.072 | 18.252 g | 17,45 |
| Instant (Versi Lama) | 410 | 2,17% | 21,46% | Rp 15.917 | 12.010 g | 6,61 |
| Same Day | 341 | 1,81% | 14,37% | Rp 13.178 | 5.853 g | 6,00 |
| Agen | 86 | 0,46% | 22,09% | Rp 8.284 | 1.117 g | 2,54 |
| Instant | 57 | 0,30% | 24,56% | Rp 5.921 | 6.581 g | 3,02 |
| Next Day | 31 | 0,16% | 12,90% | Rp 27.241 | 1.805 g | 2,22 |

- **Kargo jelas untuk order besar:** berat rata-rata 18.252 g (18,3 kg) dan qty rata-rata 17,45 — jauh di atas tier lain, membuktikan pola grosir yang sudah terlihat di EDA dan Tahap 12 (kategori Nampan/Tray) benar-benar terhubung ke pemilihan opsi pengiriman.
- **Reguler (Cashless) punya cancellation rate terendah (11,03%)** di antara tier bervolume besar, sedikit di bawah Hemat Kargo (14,01%) meski keduanya melayani order retail kecil serupa (avg qty 1,99 sama persis).
- **Tier ekspres (Instant, Instant Versi Lama, Agen) justru punya cancellation rate tertinggi** (21–25%), berlawanan dengan asumsi umum bahwa pengiriman cepat berarti komitmen beli lebih tinggi.
- **Next Day punya ongkir rata-rata tertinggi (Rp 27.241)** meski order-nya ringan (1.805 g) dan cancellation rate-nya rendah (12,90%) — kemungkinan segmen niche dengan pembeli yang lebih pasti.
- Tier `Economy` (3 order) dan `Instant Prioritas` (4 order) tidak diinterpretasikan karena basis terlalu kecil.

### F. Subsidi ongkir per kurir (Completed Orders)
| Kurir | Avg ongkir dibayar | Avg perkiraan ongkir | % dibayar dari perkiraan | % gratis ongkir |
|---|---:|---:|---:|---:|
| SPX (Shopee Xpress) | Rp 4.290 | Rp 16.202 | 26,48% | 65,12% |
| JNE | Rp 11.458 | Rp 27.398 | 41,82% | 63,60% |
| J&T | Rp 20.555 | Rp 42.996 | 47,81% | 32,84% |
| GoSend | Rp 15.750 | Rp 29.625 | 53,16% | 26,67% |
| GrabExpress | Rp 5.079 | Rp 26.053 | 19,49% | 47,37% |

- **SPX mendapat subsidi terbesar secara persentase**: pembeli cuma menanggung 26,48% dari perkiraan ongkos kirim, dan 65,12% order-nya gratis ongkir sama sekali — jauh di atas kurir lain. Ini konsisten dengan dominasi SPX di opsi "Hemat Kargo-SPX Hemat" yang jadi andalan strategi ongkir murah.
- **GrabExpress subsidinya secara persentase bahkan lebih besar (19,49%)**, tapi order gratis ongkirnya lebih sedikit (47,37%) — pola berbeda dari SPX, kemungkinan karena basis order sangat kecil (19 Completed).
- **J&T dan GoSend paling sedikit disubsidi** (47,81% dan 53,16% dari perkiraan dibayar pembeli), sejalan dengan kurir ini melayani order lebih besar/berat yang biayanya kurang cocok disubsidi penuh.

### G. Pengiriman gagal per kurir (menuntaskan Tahap 9)
| Kurir | Order | Pengiriman gagal | % pengiriman gagal | Penjual terlambat kirim | % |
|---|---:|---:|---:|---:|---:|
| SPX (Shopee Xpress) | 16.998 | 217 | 1,28% | 146 | 0,86% |
| J&T | 557 | 20 | 3,59% | 4 | 0,72% |
| JNE | 524 | 1 | 0,19% | 5 | 0,95% |
| GoSend | 67 | 0 | 0,00% | 2 | 2,99% |
| GrabExpress | 25 | 0 | 0,00% | 3 | 12,00% |

- Dari 238 pembatalan "Pengiriman gagal" secara nasional (Tahap 9), **217 (91,2%) berasal dari SPX**, sisanya 20 dari J&T dan hanya 1 dari JNE. Karena SPX juga mendominasi 90,1% order secara keseluruhan, tingkat kegagalannya (1,28%) justru bukan yang tertinggi — **J&T proporsinya lebih tinggi (3,59%)**, sekitar 2,8 kali SPX, meski volumenya jauh lebih kecil.
- Temuan Tahap 9 (234 dari 238 pengiriman gagal berasal dari COD) dan temuan di sini (217 dari 238 berasal dari SPX) sama-sama benar dan saling melengkapi — SPX adalah kurir dominan untuk pengiriman COD (lihat Tahap 10, opsi SPX Hemat/Standard adalah tempat COD terkonsentrasi).
- GoSend dan GrabExpress tidak mencatat pengiriman gagal sama sekali, tapi basisnya kecil (67 dan 25 order).

### H. Pengiriman gagal per kurir × wilayah (menuntaskan Tahap 11, ≥50 order)
| Wilayah | Kurir | Order | Pengiriman gagal | % |
|---|---|---:|---:|---:|
| Jawa | SPX (Shopee Xpress) | 13.577 | 85 | 0,63% |
| Jawa | JNE | 452 | 1 | 0,22% |
| Sumatera | SPX (Shopee Xpress) | 2.346 | 76 | 3,24% |
| Sumatera | J&T | 125 | 6 | 4,80% |
| Kalimantan | SPX (Shopee Xpress) | 475 | 18 | 3,79% |
| Kalimantan | J&T | 84 | 5 | 5,95% |
| Sulawesi | SPX (Shopee Xpress) | 332 | 24 | 7,23% |
| Sulawesi | J&T | 50 | 7 | 14,00% |
| Bali & Nusa Tenggara | SPX (Shopee Xpress) | 245 | 12 | 4,90% |

**Ini menjawab pertanyaan yang tertunda dari Tahap 11.** Tingkat kegagalan SPX sendiri naik tajam seiring jauh dari Jawa: 0,63% (Jawa) → 3,24% (Sumatera) → 3,79% (Kalimantan) → 4,90% (Bali & Nusa Tenggara) → 7,23% (Sulawesi), sekitar **11,5 kali lipat** dari Jawa ke Sulawesi. Jadi kenaikan pengiriman gagal di luar Jawa (dari Tahap 11) **bukan karena kurir yang berbeda dipakai di sana**, melainkan **kurir yang sama (SPX) gagal lebih sering di wilayah yang lebih jauh**. J&T menunjukkan pola serupa dan lebih ekstrem: 4,80% (Sumatera) → 5,95% (Kalimantan) → 14,00% (Sulawesi, basis 50 order). Ini memperkuat dugaan bahwa jarak/infrastruktur logistik, bukan pilihan kurir, adalah pendorong utama pengiriman gagal di luar Jawa — meskipun data tidak bisa memastikan penyebabnya (kualitas alamat, jangkauan armada, atau faktor lain).

### I. Sanity check: berat per tier (Completed Orders)
| Tier | Min | Median | Avg | Max |
|---|---:|---:|---:|---:|
| Kargo | 1.700 g | 10.000 g | 18.252 g | 192.500 g |
| Instant (Versi Lama) | 100 g | 7.000 g | 12.010 g | 152.000 g |
| Hemat Kargo | 10 g | 500 g | 1.342 g | 182.800 g |
| Reguler (Cashless) | 10 g | 500 g | 1.054 g | 32.000 g |

- **Logika pengelompokan tier terbukti valid dari sisi berat:** Kargo punya berat minimum 1.700 g (semua order-nya memang berat) dan median 10.000 g, jauh di atas Hemat Kargo dan Reguler (Cashless) yang median-nya sama-sama cuma 500 g.
- Menariknya, **Hemat Kargo dan Reguler (Cashless) punya outlier berat maksimum yang sangat tinggi** (182.800 g dan 32.000 g) meski median-nya kecil — berarti ada sebagian kecil order berat yang tetap memilih (atau ditempatkan ke) opsi hemat, bukan opsi kargo. Ini konsisten dengan Kargo yang hanya dipakai 2,23% order meski distribusi berat keseluruhan (dari EDA) punya ekor panjang.

## Output
- View `v_shipping_parsed` (kurir + tier_layanan) di `indo.duckdb`, lapisan bantu untuk analisis shipping.
- Kandidat insight untuk dashboard dan `docs/insights.md`:
  1. **Opsi pengiriman generik (tanpa nama kurir) = 100% order Batal (697 order).** Sinyal siap pakai untuk mendeteksi pembatalan dini, di luar cakupan alasan pembatalan yang sudah dianalisis di Tahap 9.
  2. **Pengiriman gagal di luar Jawa bukan soal kurir yang berbeda, tapi kurir yang sama gagal lebih sering.** Tingkat kegagalan SPX naik 11,5 kali dari Jawa (0,63%) ke Sulawesi (7,23%) — mendukung dugaan masalah jarak/infrastruktur, bukan pilihan kurir, sebagai pendorong utama.
  3. **J&T proporsi pengiriman gagalnya lebih tinggi dari SPX** (3,59% vs 1,28%) meski secara jumlah SPX mendominasi — dua metrik berbeda yang perlu ditampilkan bersama di dashboard, bukan saling menggantikan.
  4. **Tier ekspres (Instant, Agen) justru cancellation rate-nya tertinggi (21–25%)**, berlawanan dengan asumsi bahwa pengiriman cepat berarti pembeli lebih pasti.
  5. **SPX paling banyak disubsidi ongkirnya** (pembeli cuma menanggung 26,48% dari perkiraan biaya) — sejalan dengan strategi Hemat Kargo yang jadi opsi pengiriman terbesar.

## Assumptions
- `kurir` diekstrak dari substring nama kurir yang dikenal (SPX, JNE, J&T, GrabExpress, GoSend) — cara ini andal karena nama kurir unik dan tidak tumpang tindih.
- `tier_layanan` adalah pengelompokan analitik berbasis kata kunci, bukan sumber data resmi. Setelah perbaikan bug (`JNE Reguler`), validasi menunjukkan 0 baris tidak terklasifikasi, tapi definisi tier untuk opsi campuran (mis. "J&T Economy" → Hemat Kargo) tetap keputusan interpretatif, bukan fakta dari data.
- Opsi pengiriman generik (7 nilai, 697 order) diperlakukan sebagai kategori "Tidak disebutkan (generik)" tersendiri, bukan dihapus atau digabung ke kurir manapun, karena pola 100% Batal justru jadi temuan yang berguna.
- Pengiriman gagal per wilayah (H) dibatasi ≥50 order per kombinasi kurir-wilayah supaya tidak terlalu noisy; kombinasi di bawah itu (JNE, GoSend, GrabExpress di luar Jawa) tidak ditampilkan.
- Kaitan antara pengiriman gagal dan jarak/infrastruktur di bagian H adalah hipotesis yang konsisten dengan data (kurir sama, tingkat gagal beda per wilayah), bukan hasil yang dibuktikan — data tidak punya informasi kualitas alamat atau kapasitas armada per wilayah.

## Batasan Data
- Tidak ada tanggal pengiriman aktual atau waktu tempuh, sehingga kecepatan pengiriman sesungguhnya per kurir/tier tidak bisa diukur — hanya nama opsi yang dipilih saat checkout.
- Tidak ada data kapasitas armada atau cakupan wilayah tiap kurir, sehingga penyebab pasti kenaikan tingkat pengiriman gagal di luar Jawa (kualitas alamat pembeli, keterbatasan armada, atau jarak tempuh) tidak bisa dipastikan.
- `tier_layanan` untuk opsi tanpa kata kunci baku adalah tebakan; kalau nanti ternyata ada sumber definisi resmi dari platform, sebaiknya dipakai untuk menggantikan pengelompokan ini.
- Kurir dengan volume sangat kecil (GoSend 67 order, GrabExpress 25 order) tidak cukup untuk kesimpulan yang kuat, termasuk soal pengiriman gagal 0% pada keduanya.

## Kesimpulan
Shipping behavior mengonfirmasi dan memperdalam beberapa temuan dari tahap-tahap sebelumnya: opsi pengiriman generik ternyata jadi penanda sempurna untuk order yang dibatalkan lebih awal, kenaikan pengiriman gagal di luar Jawa (Tahap 11) ternyata terjadi pada kurir yang sama (bukan pergantian kurir), dan pola grosir (Tahap 7 dan Tahap 12) terbukti selaras dengan pemilihan tier Kargo. SPX mendominasi volume dan subsidi ongkir, sementara J&T dan GoSend melayani segmen order besar/berat dengan AOV jauh lebih tinggi. Dengan ini, seluruh Part 2 (Business Analysis, Tahap 9–13) selesai. Lanjut ke Tahap 14 — Data Mart.
