# 09 — Payment Method Behavior

## Input
- Star schema dari Tahap 8: `fact_orders`, `dim_payment_method`, `dim_status`, `dim_date`, `dim_location`, `dim_shipping`, `dim_cancellation_reason`
- Definisi Analytical Population dari `docs/05_data_validation.md`
- Cancellation dan return per metode pembayaran dari `docs/08_order_status_cancellation_return.md`
- Dijalankan via `sql/09_payment_method.sql`

## Proses Analisis
1. **Adopsi dan nilai:** porsi order, porsi revenue, AOV, dan median nilai order per metode dan per kelompok pembayaran (`payment_group`).
2. **Pergeseran komposisi per bulan:** persentase order per kelompok pembayaran, termasuk metode NULL ("Tidak Diketahui").
3. **Hubungan dengan ukuran order:** komposisi kelompok pembayaran per bucket qty dan per bucket nilai order.
4. **Hubungan dengan wilayah:** komposisi per provinsi (provinsi dengan ≥200 order).
5. **Hubungan dengan pengiriman:** ongkir dan berat per kelompok pembayaran, serta porsi COD di 10 opsi pengiriman terbanyak.
6. **Diskon dan anomali:** penggunaan diskon per kelompok, dan sebaran order tidak batal dengan pembayaran nol.
7. **Scorecard per metode:** rangkuman order, revenue, AOV, cancellation, dan return.

Analisis nilai (revenue, AOV, bucket nilai, ongkir, diskon) memakai Completed Orders; analisis komposisi memakai semua order.

## Temuan

### A/B. Adopsi dan nilai order
| Kelompok | Order | % order | Revenue Completed | % revenue | AOV |
|---|---:|---:|---:|---:|---:|
| Cash on Delivery | 10.306 | 54,62% | Rp 356.717.177 | 37,51% | Rp 40.768 |
| Ekosistem Shopee (Digital) | 5.179 | 27,45% | Rp 336.784.289 | 35,42% | Rp 73.889 |
| Online / Kartu / Bank | 3.014 | 15,97% | Rp 231.853.044 | 24,38% | Rp 95.217 |
| Tidak Diketahui | 283 | 1,50% | Rp 16.140.703 | 1,70% | Rp 64.306 |
| Gerai Retail | 72 | 0,38% | Rp 9.468.491 | 1,00% | Rp 242.782 |
| Lainnya | 14 | 0,07% | Rp 0 | 0,00% | Rp 0 |

- **COD dominan dari sisi jumlah tapi bukan dari sisi nilai:** 54,6% order menghasilkan 37,5% revenue. Dua kelompok non-COD utama (Shopee digital dan Online/Kartu/Bank) bersama-sama 43,4% order tetapi 59,8% revenue.
- AOV COD Rp 40.768 adalah yang terendah di antara kelompok besar: sekitar 1,8 kali lebih rendah dari Shopee digital (Rp 73.889) dan 2,3 kali lebih rendah dari Online/Kartu/Bank (Rp 95.217).
- Per metode (AOV / median / rata-rata qty): COD Rp 40.768 / Rp 23.000 / 1,85; ShopeePay Rp 71.652 / Rp 28.800 / 2,62; Online Payment Rp 94.208 / Rp 36.000 / 4,51; SPayLater Rp 81.494 / Rp 31.718 / 2,63; SeaBank Bayar Instan Rp 69.989 / Rp 22.000 / 3,01; Kartu Kredit/Debit Rp 108.500 / Rp 43.000 / 2,79.
- Gerai Retail punya AOV tertinggi (Rp 242.782; Alfamart/Alfamidi/Dan+Dan Rp 284.624 dengan rata-rata qty 8,33), tetapi hanya 72 order (39 Completed), jadi angka ini sangat sensitif terhadap beberapa order besar.
- Angka AOV sudah memasukkan 56 order Completed dengan pembayaran nol (lihat bagian H), jadi sedikit lebih rendah dari AOV order yang benar-benar membayar.

### C. Pergeseran komposisi per bulan
| Bulan | % COD | % Shopee digital |
|---|---:|---:|
| 2023-12 | 45,95% | 39,19% |
| 2024-06 | 56,96% | 29,56% |
| 2024-10 | 54,64% | 26,29% |
| 2025-02 | 47,54% | 30,83% |
| 2025-05 | 60,56% | 25,15% |
| 2025-08 | 61,36% | 22,19% |
| 2025-10 | 63,49% | 21,58% |
| 2025-11 | 62,95% | 22,28% |

- **Ada pergeseran dari Shopee digital ke COD:** COD naik dari sekitar 46% (Des 2023) ke sekitar 63% (Okt–Nov 2025), sementara Shopee digital turun dari 39% ke 22%. Tren tidak mulus (mis. Feb–Mar 2025 COD sempat turun ke 47%). Rata-rata sederhana antarbulan COD: 53,1% (Jan–Jun 2025) vs 61,4% (Agu–Okt 2025).
- Kelompok Online/Kartu/Bank (kolom ini terpotong di layar; dihitung sebagai sisa 100% dikurangi kelompok lain) berkisar sekitar 11–21% per bulan tanpa tren searah: terendah di Jun 2024 (11,2%) dan Mei 2025 (12,1%), tertinggi di Feb–Mar 2025 (19,7% dan 21,3%), dan hampir sama di ujung periode (13,5% di Des 2023 vs 13,3% di Nov 2025). Jadi pergeseran terutama terjadi antara Shopee digital dan COD.
- **Pergeseran ke COD tidak menjelaskan turunnya cancellation rate** di Agustus–Oktober 2025 (dari Tahap 9: 15,82% → 9,61%). COD justru naik pada periode itu, padahal COD punya cancellation rate yang lebih tinggi daripada kelompok digital setelah "belum dibayar" dikeluarkan. Penyebab penurunan tetap belum diketahui; kemungkinan cancellation turun di semua kelompok, tetapi cancellation per kelompok per bulan belum dihitung.
- **Metode pembayaran NULL tersebar merata di semua bulan** (0,51%–2,17% per bulan), tidak terkonsentrasi pada periode tertentu.
- Kelompok Gerai Retail sangat kecil dan cenderung menurun (sekitar 0,8–1,3% di Des 2023–Jul 2024, umumnya di bawah 0,5% setelahnya, kecuali Feb–Mar 2025).

### D. Metode pembayaran vs ukuran order

**Per bucket qty (% order dalam bucket):**
| Qty | COD | Shopee digital | Online/Kartu/Bank |
|---|---:|---:|---:|
| 1–2 | 57,95% | 26,16% | 13,93% |
| 3–5 | 43,98% | 32,51% | 21,84% |
| 6–10 | 42,01% | 33,82% | 21,80% |
| 11+ | 20,47% | 33,95% | 42,33% |

**Per bucket nilai order (Completed Orders, tanpa 56 baris pembayaran nol):**
| Nilai order | COD | Shopee digital | Online/Kartu/Bank | Gerai Retail |
|---|---:|---:|---:|---:|
| < 50rb | 58,61% | 27,18% | 12,51% | 0,16% |
| 50rb–150rb | 47,40% | 30,22% | 20,62% | 0,31% |
| 150rb–300rb | 29,91% | 34,19% | 33,33% | 0,43% |
| 300rb–500rb | 26,75% | 37,45% | 31,28% | 1,23% |
| ≥ 500rb | 11,85% | 48,34% | 35,55% | 2,84% |

- **Metode pembayaran sangat terkait dengan ukuran order.** COD mendominasi order kecil (58,6% dari order <50rb) dan hanya 11,9% dari order ≥500rb, di mana Shopee digital (48,3%) dan Online/Kartu/Bank (35,6%) mendominasi. Pola yang sama muncul di qty: COD 58% (qty 1–2) turun ke 20% (qty 11+), dan Online/Kartu/Bank menjadi yang terbesar (42,3%) di qty 11+.
- Ini konsisten dengan perbedaan AOV di bagian A. Data tidak menjelaskan sebabnya (preferensi pembeli, batas nilai COD di platform, atau faktor lain); ini hipotesis yang perlu dikonfirmasi ke pihak bisnis.

### E. Metode pembayaran per provinsi (13 provinsi dengan ≥200 order)
| Provinsi | Order | % COD | % Shopee digital | % Online/Kartu/Bank |
|---|---:|---:|---:|---:|
| Sulawesi Selatan | 217 | 86,18% | 5,99% | 5,99% |
| Sumatera Barat | 256 | 78,13% | 12,50% | 9,38% |
| Sumatera Utara | 276 | 76,45% | 14,13% | 9,42% |
| Jambi | 308 | 75,97% | 14,94% | 8,12% |
| Riau | 300 | 69,67% | 18,33% | 10,33% |
| Sumatera Selatan | 579 | 69,43% | 17,10% | 12,44% |
| Lampung | 441 | 68,03% | 19,50% | 11,11% |
| Jawa Timur | 1.411 | 65,34% | 21,19% | 11,69% |
| Jawa Tengah | 1.310 | 61,15% | 21,45% | 15,19% |
| Jawa Barat | 6.078 | 53,27% | 29,55% | 14,87% |
| DI Yogyakarta | 229 | 52,40% | 32,75% | 13,97% |
| Banten | 3.281 | 42,55% | 34,56% | 20,94% |
| DKI Jakarta | 2.667 | 36,18% | 37,91% | 23,66% |

- **Ada gradien wilayah yang jelas:** DKI Jakarta dan Banten paling sedikit memakai COD (36% dan 43%), sedangkan provinsi di Sumatera dan Sulawesi Selatan memakai COD 68–86%.
- Provinsi dengan porsi COD tinggi (Riau, Sumatera Utara, Jambi, Sumatera Selatan) juga muncul dengan cancellation rate tinggi di EDA (15,9–18,7%). Kaitannya belum diuji dan perlu dicek di Tahap 11 (Regional), karena COD sendiri hanya berbeda beberapa poin dari kelompok lain dalam cancellation rate.

### F. Metode pembayaran vs pengiriman (Completed Orders)
| Kelompok | Completed | Avg ongkir dibayar | Avg perkiraan ongkir | % gratis ongkir | Avg berat |
|---|---:|---:|---:|---:|---:|
| Cash on Delivery | 8.750 | Rp 4.649 | Rp 17.015 | 63,94% | 978 g |
| Ekosistem Shopee (Digital) | 4.558 | Rp 4.420 | Rp 16.683 | 66,70% | 2.780 g |
| Online / Kartu / Bank | 2.435 | Rp 7.242 | Rp 19.874 | 59,14% | 3.634 g |
| Tidak Diketahui | 251 | Rp 4.359 | Rp 16.649 | 66,53% | 2.482 g |
| Gerai Retail | 39 | Rp 31.069 | Rp 39.633 | 17,95% | 6.018 g |

- Order COD jauh lebih ringan (rata-rata 978 g) dibanding Shopee digital (2.780 g) dan Online/Kartu/Bank (3.634 g), selaras dengan temuan bahwa COD didominasi order kecil.
- Ongkir yang dibayar pembeli hampir sama untuk COD dan Shopee digital (Rp 4.649 vs Rp 4.420) meski beratnya berbeda hampir tiga kali lipat; sekitar dua pertiga order di kedua kelompok itu gratis ongkir.

**Porsi COD pada 10 opsi pengiriman terbanyak:**
| Opsi pengiriman | Order | % COD |
|---|---:|---:|
| Hemat Kargo-SPX Hemat | 11.571 | 65,41% |
| Reguler (Cashless)-SPX Standard | 4.047 | 52,78% |
| SPX Hemat | 454 | 65,20% |
| Hemat Kargo | 427 | 0,00% |
| Instant (Versi Lama)-SPX Instant (Versi Lama) | 312 | 0,32% |
| Reguler (Cashless)-JNE Reguler | 293 | 0,00% |
| Same Day-SPX Sameday | 273 | 0,00% |
| Kargo-JNE Trucking (JTR) | 172 | 0,00% |
| Hemat Kargo-J&T Economy | 169 | 78,11% |
| SPX Standard | 164 | 31,10% |

- COD terkonsentrasi di opsi SPX Hemat, SPX Standard, dan J&T Economy. Lima opsi (Hemat Kargo tanpa nama kurir, Instant Versi Lama, JNE Reguler, Same Day SPX, dan JNE Trucking) hampir atau sama sekali tidak memuat order COD. Dugaan bahwa COD memang tidak tersedia di opsi-opsi itu masuk akal tetapi belum bisa diverifikasi dari data.

### G. Diskon
Diskon sangat jarang dipakai: 20 dari 8.750 order COD (0,23%), 30 dari 4.558 order Shopee digital (0,66%), 36 dari 2.435 order Online/Kartu/Bank (1,48%), 2 dari 251 order Tidak Diketahui (0,80%), dan 0 di Gerai Retail. Total hanya 88 dari 16.045 Completed Orders (0,55%). Rata-rata diskon saat ada diskon di kelompok Online/Kartu/Bank (Rp 121.227) lebih besar daripada AOV kelompok itu (Rp 95.217), dan dua order Tidak Diketahui punya rata-rata diskon Rp 3, sehingga makna kolom `Total Diskon` perlu dikonfirmasi sebelum dipakai untuk kesimpulan apa pun.

### H. Order tidak batal dengan pembayaran nol
Seluruh 56 order dengan `flag_selesai_bayar_nol` berstatus Selesai dan tersebar di beberapa metode: COD 15, Pembayaran dibebaskan 12, ShopeePay 11, Online Payment 6, SeaBank Bayar Instan 5, SPayLater 5, Kartu Kredit/Debit 1, Tidak Diketahui 1. Tidak ada order In-Progress dengan pembayaran nol.

- Dua belas order (21,4%) punya penjelasan yang jelas: metode "Pembayaran dibebaskan". Dua belas dari 13 order dengan metode itu berstatus Selesai; satu lagi Batal.
- Sisa 44 order tersebar di metode biasa tanpa konsentrasi pada satu metode, dan penyebab pembayaran nolnya tidak bisa ditentukan dari data.

### I. Scorecard (rangkuman dari Tahap 9 dan 10)
| Metode | Order | Cancel rate | Cancel rate tanpa "belum dibayar" | Return rate |
|---|---:|---:|---:|---:|
| COD | 10.306 | 13,43% | 13,43% | 0,54% |
| ShopeePay | 3.269 | 8,81% | 6,85% | 1,29% |
| Online Payment | 2.811 | 18,68% | 10,74% | 1,06% |
| SPayLater | 1.336 | 15,34% | 10,55% | 1,43% |
| SeaBank Bayar Instan | 574 | 13,94% | 11,67% | 2,05% |
| Tidak Diketahui | 283 | 11,31% | 9,54% | 0,80% |
| Kartu Kredit/Debit | 200 | 11,50% | 6,00% | 3,39% |

Return rate seluruh metode digital/prabayar (1,06%–3,39%) lebih tinggi dari COD (0,54%), konsisten dengan temuan Tahap 9. Metode berjumlah sangat kecil (Indomaret, Alfamart, BCA OneKlik, Mitra Shopee, Pembayaran dibebaskan) tidak diinterpretasikan.

## Output
- Tidak ada table baru; seluruhnya query analisis read-only di atas star schema.
- Kandidat insight untuk dashboard dan `docs/insights.md`:
  1. **COD mendominasi jumlah order (54,6%) tetapi bukan nilai (37,5% revenue).** AOV COD Rp 40.768 vs Rp 73.889 (Shopee digital) dan Rp 95.217 (Online/Kartu/Bank).
  2. **Metode pembayaran berkaitan kuat dengan nilai order:** COD 58,6% dari order <50rb tetapi hanya 11,9% dari order ≥500rb; qty 11+ hanya 20,5% COD.
  3. **Porsi COD naik dari sekitar 46% (Des 2023) ke sekitar 63% (Okt–Nov 2025)** dengan Shopee digital turun dari 39% ke 22%. Pergeseran ini tidak menjelaskan turunnya cancellation rate di akhir 2025.
  4. **Adopsi COD sangat berbeda antarwilayah:** 36% (DKI Jakarta) sampai 86% (Sulawesi Selatan); wilayah dengan porsi COD tinggi perlu dicek keterkaitannya dengan cancellation di Tahap 11.
  5. **COD terkonsentrasi di opsi pengiriman tertentu** (SPX Hemat/Standard, J&T Economy), dan hampir tidak ada di opsi Instant, Same Day, JNE Reguler, dan Kargo.

## Assumptions
- `payment_group` memakai pengelompokan Tahap 8; nilai mentah `metode_pembayaran` tetap dipakai untuk analisis per metode.
- Analisis nilai memakai Completed Orders karena order Batal bernilai nol. AOV di bagian A/B/F/G memasukkan 56 order pembayaran nol, sedangkan bagian D2 mengeluarkannya.
- Bucket qty dan bucket nilai memakai batas yang sama dengan EDA (Tahap 7). Ambang provinsi di bagian E adalah ≥200 order total (bukan Completed Orders seperti di Tahap 9).
- Metode NULL dipertahankan sebagai kategori "Tidak Diketahui" (Tahap 5) dan tidak diimputasi; kelompok ini tidak menyerupai COD maupun kelompok prabayar secara jelas (AOV Rp 64.306).
- Penjelasan sebab (mis. batas COD di platform, ketersediaan COD per opsi pengiriman, alasan order kecil memilih COD) adalah hipotesis yang konsisten dengan data, bukan hasil yang dibuktikan.

## Batasan Data
- Satu order hanya punya satu metode pembayaran; pembayaran campuran (mis. voucher plus transfer) tidak terwakili.
- Makna kolom `Total Diskon` belum jelas (lihat bagian G), sehingga diskon tidak dipakai sebagai penjelas.
- Tidak ada `customer_id`, jadi perpindahan metode pembayaran oleh pembeli yang sama dari waktu ke waktu tidak bisa dilacak; pergeseran komposisi bulanan bisa disebabkan pembeli yang berbeda.
- Sebagian kolom output terpotong di layar (`pct_online_kartu_bank` di bagian C, dan beberapa kolom di bagian A dan I). Angka per metode untuk order dan revenue diambil dari ringkasan per kelompok (bagian B) dan hasil EDA Tahap 7; kolom Online/Kartu/Bank di bagian C dihitung sebagai sisa, bukan dibaca langsung.
- Kelompok kecil (Gerai Retail 72 order, Lainnya 14 order) tidak cukup untuk kesimpulan yang kuat.
- November 2025 belum matang (250 order In-Progress), tetapi komposisi pembayaran berbasis jumlah order sedikit terpengaruh.

## Kesimpulan
Pola pembayaran di dataset ini terutama dibentuk oleh ukuran dan nilai order: COD melayani order kecil dan ringan dalam jumlah besar (54,6% order, 37,5% revenue), sedangkan metode digital dan kartu melayani order yang lebih besar dan bernilai tinggi (43,4% order, 59,8% revenue). Adopsi COD juga sangat berbeda antarwilayah (36%–86%) dan meningkat dari waktu ke waktu, terutama menggantikan Shopee digital. Pergeseran ke COD tidak cukup menjelaskan turunnya cancellation rate di akhir 2025, jadi penyebab penurunan itu masih terbuka. Lanjut ke Tahap 11 — Regional Performance.
