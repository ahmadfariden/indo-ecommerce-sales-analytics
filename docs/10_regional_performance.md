# 10 — Regional Performance

## Input
- Star schema dari Tahap 8: `fact_orders`, `dim_location`, `dim_status`, `dim_payment_method`, `dim_cancellation_reason`, `dim_date`
- Definisi Analytical Population dari `docs/05_data_validation.md`
- Temuan Tahap 9 (`docs/08_order_status_cancellation_return.md`) dan Tahap 10 (`docs/09_payment_method.md`)
- Dijalankan via `sql/10_regional_performance.sql`

## Proses Analisis
1. **Cek kualitas nama kota/kabupaten** sebelum dipakai: jumlah nama mentah vs setelah normalisasi huruf/spasi, pola prefiks, varian, pasangan nama mirip, nama kota kembar antarprovinsi.
2. **Provinsi dan region:** order, revenue, kumulatif revenue, AOV, cancellation, return, dan porsi COD untuk 34 provinsi, lalu diringkas per `region_group` (pulau/kepulauan).
3. **Kota/kabupaten:** 20 kota teratas dan konsentrasi (berapa kota menyumbang 50% dan 80% order/revenue).
4. **Uji keterkaitan dari Tahap 9–10:** apakah cancellation rate per provinsi hanya cerminan porsi COD, dengan membandingkan cancellation order COD vs non-COD di dalam provinsi yang sama.
5. **Pengiriman per region** dan **tren bulanan** komposisi wilayah serta dekomposisi kenaikan porsi COD (di dalam wilayah vs pergeseran komposisi).
6. **Komposisi alasan pembatalan per region** untuk melihat apa yang mendorong selisih cancellation antarwilayah.

Analisis nilai (revenue, AOV, ongkir) memakai Completed Orders. Cancellation rate = order Batal / Total Orders; return rate = order Selesai dengan retur / Completed Orders.

## Temuan

### A. Kualitas nama kota/kabupaten: bersih
- 418 kombinasi provinsi–kota; jumlah nama mentah (418) sama dengan setelah normalisasi huruf/spasi (418), tidak ada varian penulisan.
- Seluruh nama berprefiks: 331 kabupaten ("KAB. ...", 10.125 order) dan 87 kota ("KOTA ...", 8.743 order).
- Tidak ada nama kota yang muncul di lebih dari satu provinsi, dan seluruh 34 provinsi terpetakan ke `region_group`.
- Satu-satunya pasangan nama mirip (jarak edit ≤2) adalah KAB. PEMALANG dan KAB. SEMARANG, dua kabupaten yang memang berbeda, jadi tidak ada yang digabung.
- Kekhawatiran di Tahap 8 (`dim_location` belum diperiksa) terjawab: tidak ada pembersihan tambahan yang diperlukan.

### B/C. Konsentrasi order dan revenue per wilayah
| Region | Order | % order | Revenue Completed | % revenue | AOV | Cancel rate | % COD |
|---|---:|---:|---:|---:|---:|---:|---:|
| Jawa | 14.976 | 79,37% | Rp 719.381.068 | 75,65% | Rp 55.307 | 12,24% | 49,69% |
| Sumatera | 2.585 | 13,70% | Rp 130.515.575 | 13,72% | Rp 62.778 | 17,06% | 72,26% |
| Kalimantan | 589 | 3,12% | Rp 35.164.278 | 3,70% | Rp 82.545 | 22,41% | 76,06% |
| Sulawesi | 392 | 2,08% | Rp 29.120.859 | 3,06% | Rp 103.265 | 24,23% | 87,50% |
| Bali & Nusa Tenggara | 298 | 1,58% | Rp 32.993.054 | 3,47% | Rp 142.827 | 21,48% | 61,41% |
| Maluku & Papua | 28 | 0,15% | Rp 3.788.870 | 0,40% | Rp 189.444 | 28,57% | 78,57% |

- **Jawa menyumbang 79,4% order dan 75,7% revenue.** Luar Jawa hanya 20,6% order tetapi 24,4% revenue, karena AOV-nya lebih tinggi: Rp 62.778 (Sumatera) sampai Rp 142.827 (Bali & Nusa Tenggara) dan Rp 189.444 (Maluku & Papua, hanya 28 order) dibanding Rp 55.307 di Jawa.
- **Cancellation rate naik seiring jauh dari Jawa:** 12,24% (Jawa), 17,06% (Sumatera), 22,41% (Kalimantan), 24,23% (Sulawesi), 21,48% (Bali & Nusa Tenggara), 28,57% (Maluku & Papua; 28 order).

**Provinsi teratas (jawaban Q1):**
| Provinsi | Order | % order | Revenue Completed | % revenue | AOV | Cancel rate | % COD |
|---|---:|---:|---:|---:|---:|---:|---:|
| Jawa Barat | 6.078 | 32,21% | Rp 246.035.278 | 25,87% | Rp 46.195 | 11,40% | 53,27% |
| Banten | 3.281 | 17,39% | Rp 162.836.566 | 17,12% | Rp 56.698 | 11,86% | 42,55% |
| DKI Jakarta | 2.667 | 14,14% | Rp 126.397.404 | 13,29% | Rp 54.482 | 12,67% | 36,18% |
| Jawa Tengah | 1.310 | 6,94% | Rp 88.948.391 | 9,35% | Rp 79.632 | 13,05% | 61,15% |
| Jawa Timur | 1.411 | 7,48% | Rp 86.650.413 | 9,11% | Rp 73.997 | 15,45% | 65,34% |
| Sumatera Selatan | 579 | 3,07% | Rp 37.185.310 | 3,91% | Rp 77.631 | 15,89% | 69,43% |
| Lampung | 441 | 2,34% | Rp 20.796.753 | 2,19% | Rp 55.606 | 14,29% | 68,03% |
| Bali | 180 | 0,95% | Rp 19.415.308 | 2,04% | Rp 134.829 | 18,89% | 50,00% |
| Sulawesi Selatan | 217 | 1,15% | Rp 17.621.092 | 1,85% | Rp 108.105 | 22,12% | 86,18% |
| Sumatera Utara | 276 | 1,46% | Rp 16.700.588 | 1,76% | Rp 77.318 | 17,75% | 76,45% |

- Tiga provinsi teratas (Jawa Barat, Banten, DKI Jakarta) = 56,29% revenue; lima teratas = 74,75%; sepuluh teratas = 86,50%.
- Peringkat revenue tidak sama dengan peringkat order: Jawa Tengah (1.310 order) melampaui Jawa Timur (1.411 order) karena AOV lebih tinggi (Rp 79.632 vs Rp 73.997). Jawa Barat punya order terbanyak tetapi AOV terendah di antara provinsi besar (Rp 46.195), dan DI Yogyakarta AOV terendah secara keseluruhan (Rp 42.353). Bali naik ke peringkat 8 revenue dengan hanya 180 order karena AOV Rp 134.829, sekitar 2,9 kali Jawa Barat.
- Provinsi kecil (<50 order) dan Papua/Papua Barat (masing-masing 1 order) tidak diinterpretasikan.
- **Return rate per region** berbasis jumlah retur yang kecil (Jawa 119, Sumatera 12, Kalimantan 4, Sulawesi 4, Bali & Nusa Tenggara 4, Maluku & Papua 0): Jawa 0,91%, Sumatera 0,58%, Kalimantan 0,94%, Sulawesi 1,42%, Bali & Nusa Tenggara 1,73%. Hanya angka Jawa yang cukup kuat; perbedaan lain tidak disimpulkan (sama seperti pola provinsi di Tahap 9).

### D. Kota/kabupaten
- **Konsentrasi tinggi:** 15 dari 418 kota menyumbang 50% order dan 80 kota (19%) menyumbang 80% order. Untuk revenue: 17 kota untuk 50% dan 76 kota untuk 80%. Sepuluh kota teratas = 40,01% order dan 37,07% revenue.
- 18 dari 20 kota teratas ada di Jawa (hanya Kota Palembang dan Kota Bandar Lampung di luar Jawa), dan 13 di antaranya di wilayah Jabodetabek.
- Kota dengan order terbanyak: Kab. Bogor (1.082), Kab. Tangerang (1.027), Kota Tangerang (915), Kab. Bekasi (750), Kota Tangerang Selatan (740).
- **Revenue tidak selalu mengikuti order:** Kab. Tangerang (Rp 53.935.941) sedikit melampaui Kab. Bogor (Rp 53.152.123) meski ordernya lebih sedikit. **Kota Palembang** menonjol: hanya 281 order (peringkat 15) tetapi revenue Rp 24.308.173 (lebih tinggi dari Kab. Bekasi dan Kota Jakarta Timur) berkat AOV Rp 101.708, tertinggi di antara 20 kota teratas. Kab. Bandung Barat (Rp 28.657) dan Kab. Bekasi (Rp 35.778) AOV-nya terendah.
- Di 18 kota Jawa dalam daftar teratas, **kabupaten punya COD lebih tinggi tetapi cancellation lebih rendah dibanding kota**: 7 kabupaten dengan COD sekitar 53% dan cancellation sekitar 10,7% (4.071 order), 11 kota dengan COD sekitar 36% dan cancellation sekitar 12,6% (6.043 order); dihitung terboboti dari tabel kota teratas, jadi berbasis sampel terbatas. Arah ini berlawanan dengan dugaan bahwa lebih banyak COD berarti lebih banyak pembatalan.

### E. Uji hipotesis: apakah selisih cancellation antarprovinsi hanya cerminan porsi COD?
Secara nasional cancellation rate order COD (13,43%) dan non-COD (13,89%) hampir sama; setelah pembatalan "belum dibayar" (semuanya non-COD) dikeluarkan, non-COD turun ke sekitar 9,18% (786 dari 8.562 order), lebih rendah dari COD.

| Provinsi | Order | % COD | Cancel semua | Cancel order COD | Cancel order non-COD | Cancel tanpa "belum dibayar" |
|---|---:|---:|---:|---:|---:|---:|
| Sulawesi Selatan | 217 | 86,18% | 22,12% | 20,86% (187) | 30,00% (30) | 20,74% |
| Sumatera Barat | 256 | 78,13% | 19,53% | 18,00% (200) | 25,00% (56) | 16,80% |
| Riau | 300 | 69,67% | 18,67% | 19,14% (209) | 17,58% (91) | 16,00% |
| Sumatera Utara | 276 | 76,45% | 17,75% | 17,54% (211) | 18,46% (65) | 16,67% |
| Jambi | 308 | 75,97% | 16,88% | 18,38% (234) | 12,16% (74) | 15,26% |
| Sumatera Selatan | 579 | 69,43% | 15,89% | 14,43% (402) | 19,21% (177) | 13,47% |
| Jawa Timur | 1.411 | 65,34% | 15,45% | 14,75% (922) | 16,77% (489) | 13,32% |
| Lampung | 441 | 68,03% | 14,29% | 14,33% (300) | 14,18% (141) | 13,15% |
| Jawa Tengah | 1.310 | 61,15% | 13,05% | 12,48% (801) | 13,95% (509) | 10,84% |
| DKI Jakarta | 2.667 | 36,18% | 12,67% | 11,71% (965) | 13,22% (1.702) | 9,75% |
| Banten | 3.281 | 42,55% | 11,86% | 10,53% (1.396) | 12,84% (1.885) | 9,84% |
| Jawa Barat | 6.078 | 53,27% | 11,40% | 10,69% (3.238) | 12,22% (2.840) | 9,49% |
| DI Yogyakarta | 229 | 52,40% | 10,48% | 5,00% (120) | 16,51% (109) | 9,17% |

(Angka dalam kurung = jumlah order pada kelompok itu.)

- **Hipotesis tidak didukung.** Cancellation rate order COD saja tetap jauh lebih tinggi di provinsi luar Jawa (Sulawesi Selatan 20,86%, Riau 19,14%, Jambi 18,38%, Sumatera Barat 18,00%, Sumatera Utara 17,54%) dibanding Jawa Barat (10,69%), Banten (10,53%), dan DKI Jakarta (11,71%), sekitar 1,5–2,0 kali. Selisih itu juga tetap ada setelah "belum dibayar" dikeluarkan (Sulawesi Selatan 20,74% vs Jawa Barat 9,49%). Jadi ada efek wilayah tersendiri yang tidak berasal dari komposisi pembayaran.
- Arah COD vs non-COD di dalam provinsi tidak konsisten (non-COD lebih tinggi di 10 dari 13 provinsi, lebih rendah di Riau dan Jambi, hampir sama di Lampung). Basis non-COD di provinsi kecil hanya 30–91 order, jadi perbedaan itu tidak diinterpretasikan.
- DI Yogyakarta memiliki cancellation COD 5,00% (6 dari 120 order), jauh di bawah non-COD (16,51%); basis kecil, tidak diinterpretasikan.

### F. Pengiriman per region (Completed Orders)
| Region | Completed | Avg ongkir dibayar | Avg perkiraan ongkir | % ongkir dibayar pembeli* | % gratis ongkir | Avg berat |
|---|---:|---:|---:|---:|---:|---:|
| Jawa | 13.007 | Rp 3.555 | Rp 13.239 | 26,9% | 68,36% | 1.931 g |
| Sumatera | 2.079 | Rp 7.697 | Rp 29.855 | 25,8% | 52,04% | 1.854 g |
| Kalimantan | 426 | Rp 17.157 | Rp 43.523 | 39,4% | 31,22% | 1.654 g |
| Sulawesi | 282 | Rp 23.422 | Rp 51.682 | 45,3% | 23,40% | 1.940 g |
| Bali & Nusa Tenggara | 231 | Rp 14.975 | Rp 42.402 | 35,3% | 37,66% | 2.855 g |
| Maluku & Papua | 20 | Rp 57.180 | Rp 99.530 | 57,4% | 10,00% | 2.494 g |

*Rasio dua rata-rata (ongkir dibayar ÷ perkiraan ongkos kirim), jadi hanya perkiraan kasar.

- Perkiraan ongkos kirim naik tajam dari Jawa: 2,3 kali (Sumatera), 3,3 kali (Kalimantan), 3,9 kali (Sulawesi), 3,2 kali (Bali & Nusa Tenggara), 7,5 kali (Maluku & Papua), sedangkan berat rata-rata order relatif sama (1,7–2,9 kg). Biaya tampaknya ditentukan tujuan, bukan berat.
- Porsi ongkir yang ditanggung pembeli naik dari sekitar 27% (Jawa) dan 26% (Sumatera) ke sekitar 45% (Sulawesi) dan 57% (Maluku & Papua); order gratis ongkir turun dari 68% ke 23% (Sulawesi).

### G. Tren bulanan: komposisi wilayah dan dekomposisi porsi COD
| Bulan | Order | % order Jawa | % COD semua | % COD Jawa | % COD luar Jawa |
|---|---:|---:|---:|---:|---:|
| 2023-12 | 444 | 84,68% | 45,95% | 41,76% | 69,12% |
| 2024-06 | 697 | 84,22% | 56,96% | 53,83% | 73,64% |
| 2025-05 | 819 | 78,75% | 60,56% | 55,35% | 79,89% |
| 2025-09 | 1.131 | 76,83% | 59,42% | 53,74% | 78,24% |
| 2025-10 | 1.205 | 72,78% | 63,49% | 56,78% | 81,40% |
| 2025-11 | 1.131 | 67,64% | 62,95% | 54,64% | 80,33% |

- **Porsi order Jawa turun** dari 84,7% (Des 2023) ke 67,6% (Nov 2025), dengan penurunan tercepat di Oktober–November 2025. Dihitung dari persentase bulanan, order luar Jawa tumbuh sekitar 5 kali (dari sekitar 68 ke sekitar 366 order per bulan), sedangkan Jawa sekitar 2 kali (sekitar 376 ke sekitar 765). Angka ini perkiraan.
- **Kenaikan porsi COD terjadi di dalam wilayah, bukan sekadar pergeseran komposisi.** COD di Jawa naik dari 41,8% ke 54,6% dan di luar Jawa dari 69,1% ke 80,3%. Dari kenaikan total 17,0 poin (45,95% → 62,95%), sekitar 12,3–12,6 poin berasal dari kenaikan di dalam wilayah dan sekitar 4,4–4,7 poin dari bergesernya komposisi ke luar Jawa (dua cara pembobotan memberi rentang ini). Ujung periode memakai bulan dengan order relatif sedikit (Des 2023: 444 order, sekitar 68 di luar Jawa), jadi angka ini perkiraan kasar.

### H. Komposisi alasan pembatalan per region (persentase dari total order region)
| Region | Cancel rate | Oleh pembeli | Oleh sistem | Pengiriman gagal | Penjual terlambat kirim | Belum dibayar | Ubah pesanan/alamat/voucher | Berubah pikiran |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Jawa | 12,24% | 8,51% | 3,65% | 0,57% | 0,81% | 2,15% | 4,74% | 3,09% |
| Sumatera | 17,06% | 10,95% | 6,07% | 3,17% | 0,93% | 1,93% | 6,46% | 3,91% |
| Kalimantan | 22,41% | 14,60% | 7,81% | 3,90% | 1,53% | 1,87% | 9,85% | 4,24% |
| Sulawesi | 24,23% | 14,03% | 10,20% | 7,91% | 0,77% | 1,28% | 8,16% | 5,10% |
| Bali & Nusa Tenggara | 21,48% | 11,07% | 10,40% | 4,70% | 0,67% | 4,70% | 6,04% | 4,36% |
| Maluku & Papua | 28,57% | 14,29% | 14,29% | 7,14% | 0,00% | 3,57% | 7,14% | 7,14% |

- **Pengiriman gagal adalah pendorong terbesar selisih cancellation antarwilayah:** naik dari 0,57% (Jawa) ke 3,17% (Sumatera), 3,90% (Kalimantan), dan 7,91% (Sulawesi), sekitar 14 kali di Sulawesi. Dari selisih cancellation Sulawesi vs Jawa sebesar 12,0 poin, sekitar 7,3 poin (61%) berasal dari pengiriman gagal; untuk Sumatera vs Jawa sekitar 2,6 dari 4,8 poin (54%).
- Di Kalimantan pendorong terbesar berbeda: pembeli mengubah pesanan, alamat, atau voucher (9,85% vs 4,74% di Jawa; sekitar 5,1 dari 10,2 poin selisih, 50%), diikuti pengiriman gagal (sekitar 3,3 poin, 33%).
- Alasan lain yang tidak bergerak searah: "belum dibayar" relatif datar (1,3–2,2%, kecuali Bali & Nusa Tenggara 4,7%) dan "penjual terlambat kirim" hanya 0,7–1,5%.
- Karena 234 dari 238 pembatalan "pengiriman gagal" berasal dari COD (Tahap 9) dan COD mendominasi luar Jawa, pengiriman gagal di luar Jawa pada dasarnya adalah kegagalan pengiriman COD. Dengan asumsi hampir semua kegagalan itu COD, tingkat kegagalan per order COD sekitar 1,1% di Jawa, 4,4% di Sumatera, 5,1% di Kalimantan, 7,7% di Bali & Nusa Tenggara, dan 9,0% di Sulawesi (perkiraan kasar).

## Output
- View `v_orders_region` di `indo.duckdb` (order + wilayah + status + pembayaran + alasan pembatalan + `region_group`), lapisan bantu untuk analisis regional.
- Tidak ada table baru selain view itu.
- Kandidat insight untuk dashboard dan `docs/insights.md`:
  1. **Bisnis sangat terkonsentrasi di Jawa dan Jabodetabek:** Jawa 79,4% order dan 75,7% revenue; tiga provinsi teratas 56,3% revenue; 15 dari 418 kota menghasilkan separuh order.
  2. **Luar Jawa kecil tapi bernilai lebih tinggi per order:** 20,6% order, 24,4% revenue; AOV Rp 62.778–142.827 vs Rp 55.307 di Jawa.
  3. **Cancellation rate meningkat seiring jauh dari Jawa** (12,2% → 24,2% di Sulawesi), dan ini bukan efek porsi COD: gap tetap ada pada order COD saja dan setelah "belum dibayar" dikeluarkan.
  4. **Pengiriman gagal menjelaskan lebih dari separuh selisih cancellation Sulawesi dan Sumatera dari Jawa** dan terutama terjadi pada COD; verifikasi alamat/kontak atau alternatif pembayaran prabayar untuk pengiriman COD ke luar Jawa layak diuji.
  5. **Pembeli luar Jawa menanggung porsi ongkir lebih besar** (sekitar 45% di Sulawesi vs 27% di Jawa) dengan ongkos kirim 2–4 kali lebih tinggi.
  6. **Order luar Jawa tumbuh lebih cepat (sekitar 5 kali vs 2 kali)**, sehingga risiko pembatalan dan beban ongkir ikut membesar bila tren berlanjut; kenaikan porsi COD terjadi di dalam wilayah, bukan hanya karena komposisi.

## Assumptions
- `region_group` adalah pengelompokan analitik per pulau/kepulauan (Jawa, Sumatera, Kalimantan, Sulawesi, Bali & Nusa Tenggara, Maluku & Papua); pemetaan provinsi ada di definisi view.
- Nama kota dinormalisasi hanya untuk huruf besar/kecil dan spasi ganda; "KOTA X" dan "KAB. X" tidak digabung karena unit administratif berbeda. Karena tidak ada varian, normalisasi tidak mengubah data.
- Ambang bacaan: provinsi dengan ≥200 order untuk perbandingan cancellation COD vs non-COD; provinsi dan kota kecil ditampilkan tetapi tidak diinterpretasikan.
- Dekomposisi porsi COD memakai dua cara pembobotan (bobot wilayah Des 2023 dengan tingkat COD Nov 2025, dan sebaliknya) dan melaporkan rentangnya; Des 2023 dan Nov 2025 dipakai sebagai ujung periode meski ordernya relatif sedikit.
- Tingkat pengiriman gagal per order COD mengasumsikan hampir semua pembatalan "pengiriman gagal" berasal dari COD (234 dari 238 secara nasional); tidak dihitung langsung per region × pembayaran.
- Hubungan antara jarak/wilayah dan cancellation bersifat korelasional; penyebabnya (kualitas alamat, kinerja kurir per wilayah, jarak, kebiasaan pembeli) tidak bisa dibedakan dari data ini.

## Batasan Data
- Tidak ada kolom kurir per wilayah di analisis ini; pengiriman gagal per opsi/kurir per wilayah belum dianalisis dan cocok dilanjutkan di Tahap 13 (Shipping Behavior).
- Tidak ada `customer_id`, sehingga tidak bisa dibedakan apakah pertumbuhan luar Jawa berasal dari pembeli baru atau pembeli lama.
- Return rate per region/provinsi berbasis 0–119 order retur dan tidak cukup untuk kesimpulan regional (kecuali Jawa).
- November 2025 belum matang (250 order In-Progress, Tahap 9): jumlah order dan komposisi wilayah tidak terpengaruh, tetapi AOV/revenue/cancellation bulan itu belum final. Bulan dengan missing period (Des 2024, Jul 2025) tidak tampil di tren.
- AOV dihitung dari Completed Orders, sehingga AOV wilayah dengan cancellation tinggi mengecualikan lebih banyak order.

## Kesimpulan
Penjualan sangat terkonsentrasi di Jawa dan Jabodetabek, tetapi luar Jawa membawa nilai per order yang lebih tinggi dengan risiko pembatalan yang jauh lebih besar. Selisih cancellation antarwilayah bukan cerminan porsi COD; penyebab terbesarnya adalah pengiriman gagal (terutama pada COD) dan, di Kalimantan, pembeli yang mengubah pesanan, sementara ongkos kirim yang 2–4 kali lebih mahal menambah beban bagi pembeli luar Jawa. Karena order luar Jawa tumbuh lebih cepat dan porsi COD naik di dalam setiap wilayah, dua pola ini layak dipantau. Analisis pengiriman gagal per kurir/opsi pengiriman dan wilayah dilanjutkan di Tahap 13. Lanjut ke Tahap 12 — Product Category Performance.
