# 08 — Order Status, Cancellation & Return Behavior

## Input
- Star schema dari Tahap 8: `fact_orders`, `dim_status`, `dim_cancellation_reason`, `dim_payment_method`, `dim_location`, `dim_category`, `dim_date`, `bridge_order_category`
- Definisi Analytical Population dari `docs/05_data_validation.md`
- Dijalankan via `sql/08_order_status_cancellation_return.sql`

Denominator yang dipakai: cancellation rate = order Batal / Total Orders (18.868); return rate = order Selesai dengan `total_returned_qty > 0` / Completed Orders (16.045).

## Proses Analisis
1. **Order status:** funnel status dan total pembayaran per status.
2. **Cancellation:** pecah per pihak pembatal, alasan (grup), metode pembayaran (dengan dekomposisi alasan), tren bulanan, dan bucket qty.
3. **Uji hipotesis dari EDA:** cancellation rate Online Payment (18,68%) lebih tinggi dari COD (13,43%). Dicek dengan menghitung rate setelah mengeluarkan pembatalan "Pesanan belum dibayar" (auto-cancel sistem).
4. **Return (basis Completed Orders):** cek sebaran retur per status, return rate berbasis order dan qty, retur penuh vs sebagian, lalu per kelompok pembayaran, provinsi (min. 200 order), kategori produk (min. 100 order), bucket qty, dan tren bulanan.

## Temuan

### A. Order Status
| Status | Order | % | Total pembayaran |
|---|---:|---:|---:|
| Selesai | 16.045 | 85,04% | Rp 950.963.704 |
| Batal | 2.573 | 13,64% | Rp 0 |
| Diterima (window retur) | 161 | 0,85% | Rp 5.942.773 |
| Sedang Dikirim | 59 | 0,31% | Rp 4.438.752 |
| Telah Dikirim | 30 | 0,16% | Rp 746.572 |

Ketiga status In-Progress (250 order) membawa total pembayaran Rp 11.128.097 yang belum masuk hitungan Completed Orders.

**Semua 250 order In-Progress berada di November 2025.** Di Agustus–Oktober 2025 jumlah order = Selesai + Batal persis (mis. Okt: 1.205 = 1.092 + 113), sedangkan November menyisakan 1.131 − 780 − 101 = 250. Artinya November 2025 belum matang: revenue Selesai, return rate, dan cancellation rate bulan itu masih bisa berubah.

### B. Cancellation

**Berdasarkan pihak (2.573 order Batal):** Pembeli 1.736 (67,47%), Sistem 824 (32,02%), Penjual 13 (0,51%).

**Alasan pembatalan (jawaban Q3):**
| Alasan (grup) | Pihak | Order | % dari Batal |
|---|---|---:|---:|
| Berubah pikiran | Pembeli | 624 | 24,25% |
| Ubah pesanan | Pembeli | 603 | 23,44% |
| Pesanan belum dibayar | Sistem | 403 | 15,66% |
| Ubah alamat pengiriman | Pembeli | 353 | 13,72% |
| Pengiriman gagal | Sistem | 238 | 9,25% |
| Penjual terlambat kirim | Sistem | 160 | 6,22% |
| Lainnya (Pembeli) | Pembeli | 45 | 1,75% |
| Ubah voucher | Pembeli | 31 | 1,20% |
| Penjual tidak responsif | Pembeli | 30 | 1,17% |
| Kendala pembayaran | Pembeli | 30 | 1,17% |
| Menemukan harga lebih murah | Pembeli | 20 | 0,78% |
| Paket hilang | Sistem | 19 | 0,74% |
| Produk habis | Penjual | 13 | 0,51% |
| Lainnya (Sistem) | Sistem | 4 | 0,16% |

Empat alasan teratas menyumbang 77,07% pembatalan. Pembatalan karena mengubah pesanan, alamat, atau voucher totalnya 987 order (38,36%). Alasan yang berkaitan dengan sisi penjual atau logistik (terlambat kirim, tidak responsif, produk habis, pengiriman gagal, paket hilang) totalnya 460 order (17,88%).

**Cancellation per metode pembayaran (jawaban Q2) — hipotesis EDA terkonfirmasi:**
| Metode | Order | Cancel rate | Batal "belum dibayar" | Cancel rate tanpa "belum dibayar" |
|---|---:|---:|---:|---:|
| COD | 10.306 | 13,43% | 0 | 13,43% |
| ShopeePay | 3.269 | 8,81% | 64 | 6,85% |
| Online Payment | 2.811 | 18,68% | 223 | 10,74% |
| SPayLater | 1.336 | 15,34% | 64 | 10,55% |
| SeaBank Bayar Instan | 574 | 13,94% | 13 | 11,67% |
| Kartu Kredit/Debit | 200 | 11,50% | 11 | 6,00% |
| Indomaret/i.Saku | 38 | 44,74% | 12 | 13,16% |
| Alfamart/Alfamidi/Dan+Dan | 34 | 47,06% | 10 | 17,65% |

- Selisih Online Payment dengan COD (18,68% vs 13,43%) hilang setelah pembatalan "Pesanan belum dibayar" dikeluarkan: Online Payment turun ke 10,74%, **lebih rendah dari COD (13,43%)**. Sebanyak 223 dari 2.811 order Online Payment (7,9%) dibatalkan otomatis karena belum dibayar.
- Online Payment menyumbang 223 dari 403 pembatalan "belum dibayar" (55,3%), padahal porsinya hanya 14,9% dari seluruh order.
- Rate sangat tinggi di Indomaret (44,74%) dan Alfamart (47,06%) sebagian besar juga berasal dari "belum dibayar" (12 dari 17 dan 10 dari 16 pembatalan). Volumenya kecil (38 dan 34 order), jadi angka ini rentan noise.
- COD punya pola berbeda: **234 dari 238 pembatalan "Pengiriman gagal" (98,3%) berasal dari COD**. COD juga menyumbang 1.384 dari 2.573 pembatalan (53,8%), sebanding dengan porsinya di total order (54,6%).

**Tren bulanan cancellation rate:** Puncak di Desember 2023 (20,72%) dan Mei 2025 (20,76%). Rata-rata Januari–Juni 2025 = 15,82% (790 dari 4.993 order). Mulai Agustus 2025 turun tajam: Agustus 9,24%, September 10,17%, Oktober 9,38% (rata-rata 9,61%, 315 dari 3.278 order). November 2025 (8,93%) tidak dipakai sebagai pembanding karena belum matang.

**Bucket qty:** Cancellation rate 13,36% (qty 1–2), 13,06% (3–5), 17,44% (6–10), 18,60% (11+). Order qty ≥6 secara gabungan 17,86% vs 13,32% untuk qty 1–5.

### C. Return (Completed Orders)
- **Definisi aman:** seluruh 143 order dengan retur berstatus Selesai; tidak ada retur di order Batal maupun In-Progress.
- **Return rate keseluruhan:** 0,89% berbasis order (143 dari 16.045) dan 0,90% berbasis qty (353 dari 39.251 unit).
- **Retur penuh vs sebagian:** 66 penuh (46,5%), 76 sebagian (53,5%). Satu order retur tidak punya `total_qty` sehingga tidak masuk pemisahan ini.

**Per kelompok pembayaran:**
| Kelompok | Completed | Retur | Return rate |
|---|---:|---:|---:|
| Cash on Delivery | 8.750 | 47 | 0,54% |
| Ekosistem Shopee (Digital) | 4.558 | 64 | 1,40% |
| Online / Kartu / Bank | 2.435 | 30 | 1,23% |
| Tidak Diketahui | 251 | 2 | 0,80% |
| Gerai Retail | 39 | 0 | 0,00% |
| Lainnya | 12 | 0 | 0,00% |

Metode prabayar/digital punya return rate sekitar 2,3–2,6 kali COD.

**Per bucket qty (temuan paling kuat):** 0,54% (qty 1–2) → 1,80% (3–5) → 3,73% (6–10) → 4,08% (11+). Naik konsisten, sekitar 7,6 kali dari bucket terkecil ke terbesar.

**Per provinsi (11 provinsi dengan ≥200 Completed Orders):** DI Yogyakarta 2,49% (5 retur), Jambi 1,21% (3), Jawa Timur 1,20% (14), Banten 0,94% (27), Jawa Barat 0,86% (46), Riau 0,86% (2), DKI Jakarta 0,82% (19), Jawa Tengah 0,72% (8), Sumatera Selatan 0,42% (2), Lampung 0,27% (1), Sumatera Utara 0% (0). Perbedaan antarprovinsi kebanyakan berbasis hanya 0–5 order retur, jadi tidak cukup kuat untuk disimpulkan sebagai pola regional.

**Per kategori produk (24 dari 38 kategori dengan ≥100 Completed Orders):**
- Tertinggi: Gantungan Baju/Hanger 6,54% (7 dari 107), Toples/Sealware 5,37% (8 dari 149), Plastik/Wadah Plastik 4,79% (9 dari 188), Pisau/Alat Potong 4,72% (6 dari 127).
- Terendah: Celengan 0,31% (15 dari 4.798), Seal/Baut/Roof 0,40% (2 dari 502), Aksesoris Pintu 0,61% (14 dari 2.295), Mangkok Sambal/Saus 0,62% (19 dari 3.041).
- Kategori dengan volume terbesar (Celengan, Mangkok Sambal/Saus, Aksesoris Pintu) punya return rate di bawah rata-rata keseluruhan; kategori teratas berbasis 6–9 order retur saja.

**Tren bulanan:** Return rate dekat 0% di awal periode (0% di Des 2023 dan Jan 2024, 0,09% di Jul 2024), sekitar 0,8–1,1% pada Agustus–Oktober 2024 (November 2024 0,56%), dan memuncak di Februari–Juni 2025 (1,16–2,31%; puncak Mei 2025 = 2,31%, 15 dari 649). Agustus–November 2025 kembali ke kisaran 0,89–1,15% (November belum matang). Bulan yang sama (Mei 2025) juga menjadi puncak cancellation rate (20,76%).

## Output
- Tidak ada table baru; seluruhnya query analisis read-only di atas star schema.
- Kandidat insight untuk dashboard dan `docs/insights.md`:
  1. **Cancellation rate Online Payment yang tinggi disebabkan auto-cancel "belum dibayar", bukan komitmen beli yang lebih rendah.** Tanpa alasan itu, rate-nya 10,74%, di bawah COD. Bukti: 223 order, 7,9 poin persentase.
  2. **Hampir semua pembatalan "Pengiriman gagal" berasal dari COD** (234 dari 238). Verifikasi alamat/nomor pembeli atau konfirmasi sebelum kirim untuk order COD layak diuji.
  3. **Sekitar 38% pembatalan adalah pembeli mengubah pesanan, alamat, atau voucher.** Kemudahan mengedit pesanan sebelum pengiriman berpotensi menurunkan pembatalan (perlu diuji; data tidak bisa membuktikan bahwa pembeli memesan ulang).
  4. **Order besar (qty ≥6) lebih rawan di dua sisi:** cancellation ~17,9% vs ~13,3%, dan return incidence 3,7–4,1% vs 0,54% untuk qty 1–2. Pengecekan konfirmasi dan packing khusus untuk order besar layak dipertimbangkan.
  5. **Cancellation rate turun dari 15,82% (Jan–Jun 2025) ke 9,61% (Agu–Okt 2025).** Penyebab tidak bisa ditentukan dari data; perlu dikonfirmasi ke pihak bisnis apa yang berubah.

## Assumptions
- Cancellation rate memakai denominator Total Orders; return rate memakai Completed Orders (`status_pesanan = 'Selesai'`) sesuai Tahap 6. Order dengan status "Diterima (window retur)" tidak masuk denominator, padahal masih bisa diretur; return rate bisa sedikit lebih rendah dari kondisi akhirnya.
- Return rate berbasis qty memakai total qty Completed Orders dengan `total_qty` NULL dihitung 0 di penyebut, jadi angka 0,90% sedikit terlalu tinggi bila baris NULL itu sebenarnya punya qty.
- Return incidence berbasis order dihitung dari `total_returned_qty > 0`. Metrik ini secara mekanis naik seiring qty (semakin banyak unit, semakin besar peluang minimal satu unit diretur), jadi kenaikan di bucket qty besar belum tentu berarti tiap unit lebih sering diretur. Return rate berbasis unit per bucket belum dihitung.
- Return rate per kategori lewat bridge menghitung order multi-kategori di setiap kategorinya (angka incidence per kategori, bukan pembagian). Faktor pengganggu seperti qty per order belum dikendalikan.
- Ambang minimum (200 Completed Orders untuk provinsi, 100 untuk kategori) adalah keputusan eksploratif agar tidak terlalu noisy; kategori dan provinsi di bawah ambang tidak dianalisis di sini.
- `cancel_reason_group` dan `payment_group` dari Tahap 8 dipakai apa adanya. "Pesanan belum dibayar" dianggap sebagai auto-cancel karena pembayaran tidak diselesaikan; data tidak menjelaskan penyebab pembeli tidak membayar.
- Interpretasi kausal (mis. COD → pengiriman gagal karena penolakan di tempat, atau COD → return lebih rendah karena pembeli bisa menolak di pintu) adalah hipotesis konsisten dengan data, bukan hasil yang dibuktikan.

## Batasan Data
- Order Batal punya `total_pembayaran` = 0 sehingga **revenue yang hilang akibat pembatalan tidak bisa dihitung** dari dataset ini.
- Tidak ada `customer_id`, jadi tidak bisa mengecek apakah pembatalan "ubah pesanan/alamat/voucher" diikuti pemesanan ulang.
- Tidak ada nilai (rupiah) atau alasan retur, hanya `total_returned_qty`, sehingga nilai retur dan penyebabnya tidak bisa dianalisis.
- November 2025 belum matang (250 order In-Progress); rate dan revenue bulan itu diperlakukan hati-hati. Di EDA (`docs/06_eda.md`), revenue November 2025 hanya menghitung status Selesai dan belum memasukkan Rp 11,1 juta dari order In-Progress.
- Output query B4 (alasan per kelompok pembayaran) terpotong di layar (40 dari 53 baris tampil), jadi hanya baris yang terlihat yang dipakai di dokumen ini.

## Kesimpulan
Pembatalan didominasi keputusan pembeli (67,5%), terutama berubah pikiran dan mengubah pesanan, ditambah pembatalan otomatis sistem (32,0%) karena belum dibayar, pengiriman gagal, dan keterlambatan penjual. Temuan paling penting dari tahap ini adalah pola Online Payment yang ternyata bukan lebih rawan batal, melainkan terdampak auto-cancel belum dibayar, serta pengiriman gagal yang hampir seluruhnya berasal dari COD. Return rate keseluruhan rendah (0,89%) dan paling jelas berkaitan dengan ukuran order (0,54% → 4,08%), sedangkan pola per provinsi dan kategori berbasis jumlah retur yang kecil sehingga perlu dibaca hati-hati. Lanjut ke Tahap 10 — Payment Method Behavior.
