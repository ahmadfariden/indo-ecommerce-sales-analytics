# 11 — Product Category Performance & Category Co-occurrence

## Input
- Star schema dari Tahap 8: `fact_orders`, `dim_category`, `bridge_order_category`, `dim_status`, `dim_date`
- Definisi Analytical Population dari `docs/05_data_validation.md`
- Dijalankan via `sql/11_product_category.sql`

**Peringatan desain:** `bridge_order_category` adalah relasi many-to-many (7,24% order punya >1 kategori, dari EDA Tahap 7). Revenue di bagian B1 dihitung **hanya dari order single-category** supaya tidak dobel-hitung; bagian B2 memakai seluruh order lewat bridge tapi **tanpa kolom revenue**, hanya metrik yang aman didobel-hitung (frekuensi, cancellation rate, rata-rata qty).

## Proses Analisis
1. Cek kualitas 38 nama kategori (normalisasi, daftar lengkap, pasangan nama mirip).
2. Performa kategori: revenue bersih dari order single-category (B1), dan frekuensi dari seluruh order (B2).
3. Kategori vs ukuran order (pola grosir per kategori, minimal 50 order, single-category).
4. Category co-occurrence: pasangan kategori yang sering muncul bersama (D1), dan pasangan tersering untuk tiap kategori (D2).
5. Tren bulanan 5 kategori teratas by revenue.
6. Ringkasan cakupan order single vs multi-kategori.

## Temuan

### A. Kualitas nama kategori: bersih
38 kategori, jumlah sama sebelum dan sesudah normalisasi huruf/spasi — tidak ada duplikat penulisan. Satu-satunya pasangan dengan jarak edit ≤3 adalah Celengan vs Talenan (jarak 3), dua produk yang jelas berbeda, jadi tidak ada yang perlu digabung. Kekhawatiran di Tahap 8 terjawab, sama seperti nama kota di Tahap 11.

Kategori terpopuler dari seluruh order (termasuk multi-kategori): Celengan (5.420), Mangkok Sambal/Saus (3.562), Aksesoris Pintu (2.571), Nampan/Tray (1.320), Other (827).

### B1. Revenue bersih per kategori (order single-category, 92,76% order)
| Kategori | Order | Completed | Revenue Completed | % dari revenue single-cat | AOV | Cancel rate |
|---|---:|---:|---:|---:|---:|---:|
| Seal / Baut / Roof | 586 | 492 | Rp 245.458.553 | 28,3% | Rp 498.899 | 14,68% |
| Celengan | 5.083 | 4.496 | Rp 133.958.862 | 15,4% | Rp 29.795 | 10,88% |
| Mangkok Sambal / Saus | 3.253 | 2.775 | Rp 113.711.488 | 13,1% | Rp 40.977 | 10,88% |
| Nampan / Tray | 1.140 | 968 | Rp 87.516.039 | 10,1% | Rp 90.409 | 14,04% |
| Lunch Box / Rantang | 492 | 393 | Rp 43.492.911 | 5,0% | Rp 110.669 | 19,92% |
| Other | 473 | 370 | Rp 33.447.380 | 3,9% | Rp 90.398 | 21,35% |
| Baskom / Mangkok Besar | 536 | 444 | Rp 32.210.334 | 3,7% | Rp 72.546 | 17,16% |
| Rak / Rak Serbaguna | 573 | 390 | Rp 31.218.023 | 3,6% | Rp 80.046 | 31,94% |
| Aksesoris Pintu | 2.365 | 2.114 | Rp 30.593.059 | 3,5% | Rp 14.472 | 8,71% |
| Keranjang | 457 | 371 | Rp 13.417.601 | 1,5% | Rp 36.166 | 18,60% |

- **Seal/Baut/Roof adalah temuan paling mencolok:** hanya 586 order (3,3% dari order single-category) tetapi menyumbang **28,3% revenue single-category**, lebih besar dari Celengan dan Mangkok Sambal/Saus digabung. AOV-nya Rp 498.899 — sekitar 8,4 kali AOV proxy keseluruhan (Rp 59.269 dari EDA) dan 12–34 kali AOV kategori volume tinggi lainnya (Celengan Rp 29.795, Aksesoris Pintu Rp 14.472).
- Tiga kategori teratas (Seal/Baut/Roof, Celengan, Mangkok Sambal/Saus) = 56,9% revenue single-category. Lima teratas = 72,0%.
- **Cancellation rate bervariasi tajam antarkategori.** Tertinggi di antara kategori bervolume wajar: Rak/Rak Serbaguna 31,94% (573 order, lebih dari dua kali cancellation rate keseluruhan 13,64%) dan Pengolah Bumbu/Sayur 33,33% (141 order). Terendah: Aksesoris Pintu 8,71%, Celengan 10,88%, Mangkok Sambal/Saus 10,88%.
- Kategori sangat kecil (Perkakas 2 order, Aksesoris Motor 1 order, Pot Tanaman/Bunga 2 order dengan cancel 100%) tidak diinterpretasikan.

### B2. Frekuensi dan pola pembelian (seluruh order lewat bridge)
- **Kategori punya dua pola berbeda: item utama vs item pelengkap.** Kategori dengan porsi order multi-kategori sangat tinggi cenderung dibeli bersama item lain: Sikat/Pembersih 96,43%, Sapu/Pembersih Lantai 83,16%, Spatula 79,22%, Perlengkapan Packing 77,96%, Talenan 70,00%, Aksesoris Mandi 67,35%, Mangkok 65,12%.
- Sebaliknya, kategori bervolume besar cenderung dibeli sendiri: Seal/Baut/Roof hanya 2,66% order multi-kategori, Celengan 6,22%, Stempel/Alat Kantor 4,85%, Pengolah Bumbu/Sayur 7,24%, Aksesoris Pintu 8,01%.
- Cancellation rate per kategori dari data seluruh order (B2) sejalan dengan B1: Rak/Rak Serbaguna tertinggi (30,84%), Aksesoris Pintu dan Celengan terendah (8,91% dan 10,83%).

### C. Kategori vs ukuran order (pola grosir, order single-category, ≥50 order)
| Kategori | Order | Avg qty | Median qty | % indikasi grosir (qty≥11) |
|---|---:|---:|---:|---:|
| Nampan / Tray | 1.123 | 7,83 | 2,0 | 12,56% |
| Aksesoris ID Card | 55 | 7,15 | 1,0 | 12,73% |
| Piring | 129 | 6,67 | 2,0 | 11,63% |
| Lunch Box / Rantang | 485 | 5,97 | 1,0 | 10,52% |
| Botol / Gelas / Mug | 220 | 3,41 | 2,0 | 6,82% |
| Mangkok Sambal / Saus | 3.199 | 2,29 | 2,0 | 0,94% |
| Aksesoris Pintu | 2.337 | 1,66 | 1,0 | 0,43% |
| Celengan | 5.009 | 1,46 | 1,0 | 0,44% |
| Rak / Rak Serbaguna | 567 | 1,05 | 1,0 | 0,00% |

- **Nampan/Tray adalah kategori dengan pola grosir paling jelas** di antara kategori bervolume besar: rata-rata qty 7,83 (median hanya 2, jadi rata-rata terdorong ekor grosir panjang) dan 12,56% order-nya masuk qty≥11.
- Empat kategori bervolume terbesar (Celengan, Mangkok Sambal/Saus, Aksesoris Pintu, Rak/Rak Serbaguna) semuanya pola retail murni: median qty 1, indikasi grosir hampir nol (0–0,94%).
- Data tidak menunjukkan Seal/Baut/Roof di tabel ini karena rata-rata qty-nya (3,38 dari B1) belum tentu berbasis ≥50 order single-category murni — periksa lagi bila diperlukan; AOV tinggi kategori itu tampaknya berasal dari harga satuan yang tinggi, bukan qty besar.

### D. Category co-occurrence
**Top pasangan kategori (D1):**
| Pasangan | Order bersama |
|---|---:|
| Mangkok Sambal/Saus + Other | 82 |
| Celengan + Perlengkapan Packing | 78 |
| Mangkok Sambal/Saus + Peralatan Makan | 75 |
| Botol/Gelas/Mug + Mangkok Sambal/Saus | 71 |
| Celengan + Other | 64 |
| Celengan + Keranjang | 51 |

**Pola dari pasangan tersering tiap kategori (D2):**
- **"Other" adalah hub co-occurrence paling sering**, menjadi pasangan tersering untuk 11 kategori (Baskom/Mangkok Besar, Aksesoris Pintu, Saringan/Strainer, Plastik/Wadah Plastik, Pisau/Alat Potong, Spatula, Toples/Sealware, Teko/Jug, Cobek/Ulekan, Talenan, Pengolah Bumbu/Sayur). Karena "Other" adalah kategori campuran (bukan produk spesifik), pola ini kemungkinan mencerminkan keberagaman isi kategori itu sendiri, bukan hubungan produk yang jelas.
- **Celengan** jadi pasangan tersering untuk 6 kategori terkait kebersihan/rumah tangga kecil (Sapu/Pembersih Lantai, Sikat/Pembersih, Aksesoris Mandi, Bangku/Kursi Kecil, Tempat Sampah, Keranjang) — mengindikasikan Celengan sering dibeli sebagai tambahan kecil di order rumah tangga.
- **Mangkok Sambal/Saus** jadi pasangan tersering untuk Peralatan Makan, Botol/Gelas/Mug, dan Nampan/Tray — mengelompok jadi kebutuhan peralatan makan/dapur.
- **Aksesoris Pintu** jadi pasangan tersering untuk Peralatan Kamar Mandi, Gantungan Baju/Hanger, Seal/Baut/Roof, Perkakas, Aksesoris ID Card, Gayung — mengelompok jadi kebutuhan perlengkapan rumah/hardware.
- Tiga kelompok co-occurrence ini (rumah tangga kecil dengan Celengan, dapur/makan dengan Mangkok Sambal/Saus, hardware/rumah dengan Aksesoris Pintu) adalah pola paling jelas dari data; kelompok "Other" tidak informatif karena sifat kategorinya sendiri campuran.

### E. Tren bulanan (5 kategori teratas by revenue single-category)
- **Celengan:** naik dari 172 order/Rp 4,7 juta (Des 2023) ke puncak 423 order/Rp 12,7 juta (Agu 2024), lalu turun tajam ke titik terendah 62 order/Rp 1,4 juta (Jun 2025), sebelum kembali naik ke sekitar 300 order/Rp 7 juta di Sep–Okt 2025. Pola ini sejalan dengan tren revenue keseluruhan di EDA (puncak Agu–Okt 2024, turun di paruh pertama 2025).
- **Seal/Baut/Roof:** volume order kecil dan stabil (1–57 order/bulan) tetapi revenue sangat fluktuatif karena AOV tinggi — mis. September 2024 hanya 21 order tapi Rp 21,7 juta revenue (≈Rp 1 juta/order), dan Oktober 2025 57 order menghasilkan Rp 25,3 juta (revenue bulanan tertinggi kategori ini sepanjang periode).
- **Nampan/Tray:** melonjak tajam di akhir periode — dari sekitar 20–40 order/bulan sepanjang 2024, menjadi 189 order (Agu 2025) dan 169 order (Sep 2025), jauh di atas pola historisnya. Ini kategori yang perlu dicek lebih lanjut (kampanye, perubahan harga, atau perubahan permintaan) karena lonjakannya tidak sejalan dengan tren Celengan yang justru menurun di paruh awal 2025.
- **Mangkok Sambal/Saus:** relatif stabil di 70–215 order/bulan, dengan lonjakan di November 2025 (438 order) — bulan yang sama yang menurut Tahap 9 belum matang (banyak order In-Progress), jadi angka November perlu dibaca hati-hati.
- **Lunch Box/Rantang:** memuncak di pertengahan 2024 (Jun–Okt 2024, 39–52 order/bulan) lalu menurun dan stabil di kisaran rendah (8–30 order/bulan) sepanjang 2025.

### F. Cakupan single vs multi-category
| Tipe order | Order | % order | Revenue Completed | % revenue |
|---|---:|---:|---:|---:|
| Single-category | 17.502 | 92,76% | Rp 867.309.197 | 91,20% |
| Multi-category | 1.366 | 7,24% | Rp 83.654.507 | 8,80% |

Order multi-kategori sedikit overrepresented di revenue (8,80% revenue dari 7,24% order), konsisten dengan order yang mengandung lebih dari satu kategori cenderung bernilai lebih besar per order.

## Output
- Tidak ada table baru; seluruhnya query analisis read-only di atas star schema.
- Kandidat insight untuk dashboard dan `docs/insights.md`:
  1. **Seal/Baut/Roof adalah kategori bernilai tinggi tersembunyi:** 3,3% order tapi 28,3% revenue single-category, AOV ~8,4x rata-rata. Layak perhatian khusus dari sisi stok dan promosi, terlepas dari volume order-nya yang kecil.
  2. **Rak/Rak Serbaguna punya cancellation rate 31,94%**, lebih dari dua kali rata-rata keseluruhan, pada kategori bervolume wajar (573 order) — layak diselidiki penyebabnya (kualitas produk, harga, atau kecocokan foto/deskripsi).
  3. **Nampan/Tray adalah kategori grosir paling jelas** (12,56% order qty≥11) sekaligus mengalami lonjakan volume tajam di Agustus–September 2025 — dua sinyal yang layak dicek bersama tim bisnis.
  4. **Pola co-occurrence membentuk 3 kelompok produk alami:** rumah tangga kecil (Celengan), dapur/makan (Mangkok Sambal/Saus), dan hardware/rumah (Aksesoris Pintu) — bisa jadi dasar rekomendasi cross-sell "sering dibeli bersama".
  5. **Kategori dengan porsi order multi-kategori tinggi** (Sikat/Pembersih, Sapu/Pembersih Lantai, Spatula, Perlengkapan Packing) adalah item pelengkap, bukan item penarik utama — cocok untuk strategi bundling, bukan promosi berdiri sendiri.

## Assumptions
- Revenue kategori (B1) hanya mencakup order single-category (92,76% order, 91,20% revenue keseluruhan yang sudah Completed); kategori yang sering muncul di order multi-kategori (mis. Sikat/Pembersih 96,43% multi-kategori) revenue aslinya tidak terwakili di B1 dan hanya terlihat lewat frekuensi di B2.
- Bucket qty grosir (≥11) di bagian C memakai ambang yang sama dengan EDA dan Tahap 9; hanya kategori dengan ≥50 order single-category yang ditampilkan.
- Category co-occurrence (D) dihitung dari seluruh order lewat bridge tanpa bobot revenue atau qty — murni jumlah order yang mengandung kedua kategori sekaligus.
- Kategori "Other" diperlakukan sebagai kategori data apa adanya (bukan digabung ke kategori lain), karena tidak ada informasi tambahan untuk memecahnya lebih lanjut.
- Tren bulanan (E) memakai order single-category saja, konsisten dengan B1; pola kategori pada order multi-kategori tidak tercermin di tren ini.

## Batasan Data
- Tidak ada harga satuan atau nama produk spesifik, hanya kategori agregat, sehingga penyebab AOV tinggi Seal/Baut/Roof (harga satuan tinggi vs qty besar per unit) tidak bisa dipastikan dari data ini.
- Revenue kategori pada order multi-kategori tidak bisa dialokasikan per kategori (tidak ada breakdown nilai per item dalam satu order), sehingga B2 sengaja tidak menyertakan revenue.
- November 2025 belum matang (Tahap 9); lonjakan Mangkok Sambal/Saus di bulan itu perlu dikonfirmasi setelah data bulan tersebut lengkap.
- Category co-occurrence tidak dibobot dengan ukuran kategori, sehingga kategori besar (Celengan, Mangkok Sambal/Saus, Other) secara alami lebih sering muncul sebagai pasangan hanya karena volumenya besar, bukan karena hubungan produk yang kuat.

## Kesimpulan
Performa kategori sangat timpang: satu kategori bervolume kecil (Seal/Baut/Roof) menyumbang lebih dari seperempat revenue single-category berkat AOV yang jauh di atas rata-rata, sementara kategori bervolume besar (Celengan, Mangkok Sambal/Saus, Aksesoris Pintu) mengandalkan jumlah order. Cancellation rate berbeda tajam antarkategori, dengan Rak/Rak Serbaguna sebagai kandidat masalah utama. Category co-occurrence membentuk tiga kelompok produk yang cukup jelas dan bisa dipakai untuk strategi cross-sell, sementara pola item pelengkap (porsi multi-kategori tinggi) berbeda dari item penarik utama. Lanjut ke Tahap 13 — Shipping Behavior, termasuk menuntaskan analisis pengiriman gagal per kurir/wilayah yang ditunda dari Tahap 11.
