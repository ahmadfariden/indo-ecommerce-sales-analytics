# Insights — Indonesia E-commerce Sales Analytics

> Rangkuman insight utama dari seluruh Business Analysis (Tahap 9–13), disusun
> untuk memenuhi Success Criteria di `docs/business_understanding.md`: minimal
> 3 insight actionable berbasis bukti, dengan tiap insight bisa ditelusuri
> balik ke raw data. Setiap insight di bawah mencantumkan sumber tahap, bukti
> angka, dan rekomendasi — bukan sekadar deskripsi data.

---

## 1. Cancellation rate Online Payment yang terlihat tinggi sebenarnya didorong auto-cancel, bukan keengganan pembeli

**Bukti:** Cancellation rate Online Payment (18,68%) terlihat lebih tinggi dari COD (13,43%) di EDA awal. Setelah pembatalan otomatis "Pesanan belum dibayar" dikeluarkan, cancellation rate Online Payment turun ke 10,74% — **lebih rendah dari COD**. Sebanyak 223 dari 2.811 order Online Payment (7,9%) dibatalkan otomatis karena belum dibayar, menyumbang 55,3% dari seluruh pembatalan "belum dibayar" secara nasional meski porsi ordernya cuma 14,9%.

**Rekomendasi:** Jangan menyimpulkan Online Payment sebagai metode berisiko tinggi. Fokuskan perhatian pada *window waktu pembayaran* untuk metode ini — kemungkinan jendela konfirmasi pembayaran terlalu ketat dibanding kebiasaan pembeli, atau ada gesekan di alur pembayaran yang bikin transaksi tidak selesai.

**Sumber:** `docs/08_order_status_cancellation_return.md` (Tahap 9) — Dashboard Sheet 2, chart "Cancellation Rate: Semua Alasan vs Tanpa 'Belum Dibayar'"

---

## 2. Pengiriman gagal di luar Jawa adalah masalah kurir yang sama, bukan kurir yang berbeda

**Bukti:** Cancellation rate meningkat konsisten dari 12,24% (Jawa) ke 24,23% (Sulawesi). Awalnya terlihat seperti korelasi dengan porsi COD yang juga lebih tinggi di luar Jawa, tapi setelah dipecah per kurir, tingkat kegagalan pengiriman **SPX sendiri** naik dari 0,63% (Jawa) ke 7,23% (Sulawesi) — sekitar 11,5 kali lipat, pada kurir yang persis sama. J&T menunjukkan pola serupa dan lebih ekstrem (4,80% di Sumatera → 14,00% di Sulawesi).

**Rekomendasi:** Investigasi kualitas layanan SPX dan J&T secara spesifik di wilayah Sulawesi, Kalimantan, dan Sumatera — bukan mengevaluasi ulang pilihan kurir secara umum. Pertimbangkan verifikasi alamat/kontak tambahan untuk order COD di wilayah-wilayah ini, karena 234 dari 238 pembatalan "pengiriman gagal" secara nasional berasal dari COD.

**Sumber:** `docs/10_regional_performance.md` (Tahap 11) + `docs/12_shipping_behavior.md` (Tahap 13) — Dashboard Sheet 4 (scatter COD vs cancellation) dan Sheet 5 (chart pengiriman gagal per kurir × wilayah)

---

## 3. COD mendominasi volume order tapi bukan nilai bisnis

**Bukti:** COD menyumbang 54,62% dari seluruh order tapi hanya 37,51% dari revenue Completed Orders, dengan AOV Rp 40.768 — jauh di bawah Ekosistem Shopee Digital (Rp 73.889) dan Online/Kartu/Bank (Rp 95.217). Pola ini konsisten di tiap ukuran order: COD mendominasi order di bawah Rp 50 ribu (58,61%) tapi porsinya anjlok di order Rp 500 ribu ke atas (11,85%).

**Rekomendasi:** Jangan mengevaluasi performa metode pembayaran murni dari jumlah transaksi. Strategi untuk menaikkan AOV (bundling, insentif beli lebih banyak) kemungkinan lebih efektif diarahkan ke segmen non-COD, yang sudah terbukti nyaman dengan order bernilai lebih besar.

**Sumber:** `docs/09_payment_method.md` (Tahap 10) — Dashboard Sheet 3, scatter "Volume Order vs AOV per Metode"

---

## 4. Satu kategori kecil menyumbang lebih dari seperempat revenue, tapi nyaris tidak terlihat dari volume order

**Bukti:** Kategori "Seal / Baut / Roof" hanya 586 order (3,3% dari order single-category) tapi menyumbang Rp 245,5 juta — 28,3% dari seluruh revenue single-category, lebih besar dari kontribusi Celengan dan Mangkok Sambal/Saus digabung. AOV kategori ini Rp 498.899, sekitar 8,4 kali AOV rata-rata keseluruhan.

**Rekomendasi:** Kategori ini layak dapat perhatian stok dan promosi yang tidak proporsional dengan volumenya — kehilangan beberapa order di kategori ini berdampak jauh lebih besar ke revenue dibanding kategori bervolume tinggi seperti Celengan atau Aksesoris Pintu.

**Sumber:** `docs/11_product_category.md` (Tahap 12) — Dashboard Sheet 5, chart "Revenue per Kategori (Top 10)"

---

## 5. Opsi pengiriman tanpa nama kurir adalah sinyal sempurna untuk order yang akan dibatalkan

**Bukti:** 697 order dengan opsi pengiriman generik (hanya menyebut tier seperti "Hemat Kargo" tanpa nama kurir spesifik) **100% berstatus Batal**, tanpa satu pun Completed. Pola ini sempurna secara statistik — begitu nama kurir tercatat di opsi pengiriman, order itu selalu lanjut ke tahap berikutnya.

**Rekomendasi:** Field `opsi_pengiriman` bisa dipakai sebagai sinyal operasional real-time untuk mendeteksi order yang berisiko tinggi dibatalkan sebelum kurir ditugaskan — berguna untuk intervensi dini (mis. pengingat pembayaran) sebelum order benar-benar batal.

**Sumber:** `docs/12_shipping_behavior.md` (Tahap 13) — Dashboard Sheet 5, chart "Order & Cancellation Rate per Kurir" (kategori "Tidak disebutkan (generik)")

---

## 6. Rak/Rak Serbaguna adalah kandidat kategori bermasalah yang layak diselidiki

**Bukti:** Cancellation rate kategori ini 31,94% — lebih dari dua kali rata-rata keseluruhan (13,64%) — pada basis order yang tidak kecil (573 order), bukan kategori niche. Ini satu-satunya kategori bervolume wajar dengan cancellation serupa tingginya dengan kategori yang memang kecil basisnya.

**Rekomendasi:** Investigasi lebih lanjut dari sisi non-data: kualitas foto/deskripsi produk, akurasi harga, atau masalah pengemasan yang mungkin memicu pembatalan tinggi khusus di kategori ini.

**Sumber:** `docs/11_product_category.md` (Tahap 12) — Dashboard Sheet 5, chart "Revenue per Kategori (Top 10)" (data detail cancellation per kategori ada di mart, belum di-chart eksplisit di dashboard — lihat tabel sumber)

---

## Catatan metodologis (berlaku untuk semua insight di atas)

- Semua insight bersifat **deskriptif dan korelasional**, sesuai batas Analytical Scope di `docs/business_understanding.md` — tidak ada klaim sebab-akibat yang dibuktikan secara statistik formal.
- Cancellation rate dihitung dari Total Orders, return rate dari Completed Orders, konsisten dengan definisi Analytical Population di `docs/05_data_validation.md`.
- November 2025 (bulan terakhir dalam data) belum matang — 250 order masih berstatus In-Progress — sehingga tren di bulan tersebut tidak dipakai sebagai dasar insight manapun di atas.
- Dataset tidak memiliki `customer_id`, nilai/alasan retur, atau harga satuan produk — beberapa dugaan penyebab (mis. kenapa Seal/Baut/Roof AOV-nya tinggi) tetap berupa hipotesis yang konsisten dengan data, bukan fakta yang terbukti langsung.
