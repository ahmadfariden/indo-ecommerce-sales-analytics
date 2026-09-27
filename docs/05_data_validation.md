# 05 — Data Validation

## Input
- Table `sales` (hasil Tahap 5, lihat `docs/04_data_cleaning.md`)
- Table `sales_raw` (untuk reconciliation)
- Dijalankan via `sql/05_data_validation.sql`

## Proses Analisis
1. Reconciliation row count dan revenue (`Total Pembayaran`) antara `sales_raw` dan `sales`.
2. Cek keunikan `order_id` pasca cleaning.
3. Definisikan **Analytical Population**: Total Orders, Completed Orders, Cancelled Orders, In-Progress Orders — jadi denominator baku untuk KPI di tahap-tahap berikutnya.
4. Cek konsistensi logika bisnis: `alasan_pembatalan` vs `status_pesanan`, invariant `flag_selesai_bayar_nol`, `total_returned_qty` vs `total_qty`, `num_product_categories` vs jumlah kategori aktual di `product_categories`.
5. Cek nilai negatif di seluruh kolom numerik.
6. Cek distribusi `provinsi` (kandidat duplikat kapitalisasi/spasi seperti yang terjadi di `Metode Pembayaran`) dan missing `kota_kabupaten`.
7. Sanity check rentang tanggal (`order_date_clean` min/max).

## Temuan
- **Reconciliation sempurna:** `rows_raw` = `rows_clean` = 18.868; `revenue_raw` = `revenue_clean` = Rp 962.091.801 (identik sampai desimal) — proses cleaning tidak mengubah nilai finansial sama sekali, cuma casting tipe data.
- **`order_id` unik 100%** — 18.868 baris = 18.868 `order_id` distinct, tidak ada duplikasi tersembunyi.
- **Analytical Population terdefinisi:**
  | Segment | Jumlah | % |
  |---|---:|---:|
  | Total Orders | 18.868 | 100% |
  | Completed Orders | 16.045 | 85,04% |
  | Cancelled Orders | 2.573 | 13,64% |
  | In-Progress Orders | 250 | 1,32% |

  (In-Progress = Sedang Dikirim 59 + Telah Dikirim 30 + Diterima window retur 161 = 250, cocok dengan Tahap 5.)
- **Konsistensi logika bisnis 100% bersih:**
  - `batal_tanpa_alasan_flag` = 0 (semua order Batal punya alasan pembatalan)
  - `ada_alasan_tapi_bukan_batal` = 0 (tidak ada alasan pembatalan nyasar ke status non-Batal)
  - `flag_di_luar_status_selesai` = 0 (invariant `flag_selesai_bayar_nol` selalu di dalam status Selesai, sesuai desain Tahap 5)
  - `returned_qty_melebihi_total_qty` = 0 (tidak ada retur yang qty-nya lebih besar dari qty order)
  - `mismatch_num_product_categories` = 0 (jumlah kategori di `num_product_categories` selalu cocok dengan jumlah kategori aktual di `product_categories`)
- **Tidak ada nilai negatif** di semua 7 kolom numerik yang dicek (qty, weight, returned qty, diskon, ongkir dibayar pembeli, total pembayaran, perkiraan ongkos kirim).
- **`provinsi` bersih, 34 nilai unik** — tidak ada kandidat duplikat kapitalisasi/spasi seperti kasus `Metode Pembayaran` di Tahap 4. 34 provinsi ini konsisten dengan jumlah provinsi Indonesia versi sebelum pemekaran Papua 2022.
- **`kota_kabupaten` 0 missing** — seluruh 18.868 baris terisi.
- **Rentang tanggal:** 2023-12-01 s.d. 2025-11-30 — masuk akal, sesuai dengan 24 bulan periode yang dicek di Tahap 4 (termasuk 2 bulan missing period di tengah).

## Output
- Tidak ada table baru — seluruhnya query validasi (read-only) terhadap `sales` dan `sales_raw`.
- **Definisi Analytical Population** (Total/Completed/Cancelled/In-Progress Orders) ditetapkan sebagai acuan denominator KPI untuk seluruh Part 2 (Business Analysis) berikutnya — terutama Return Rate yang wajib pakai denominator Completed Orders, bukan Total Orders, sesuai QA checklist roadmap.

## Assumptions
- Denominator "Completed Orders" (16.045) ditetapkan sebagai acuan baku untuk metrik yang secara konseptual hanya relevan buat order yang benar-benar selesai (mis. return rate) — bukan Total Orders (18.868) yang juga mengandung order batal/in-progress yang belum tentu representatif.
- Karena semua pengecekan konsistensi lolos 0 anomali, tidak ada keputusan cleaning tambahan yang perlu di-rollback ke Tahap 5 — table `sales` dianggap final sebagai basis EDA dan Business Analysis.

## Kesimpulan
Table `sales` lolos seluruh uji reconciliation dan konsistensi logika bisnis tanpa satu pun anomali baru. Data secara finansial (`revenue`), struktural (row count, `order_id` unik), dan logis (status vs alasan pembatalan, flag invariants, qty/retur, kategori) terverifikasi solid. Analytical Population sudah terdefinisi jelas (Total/Completed/Cancelled/In-Progress) untuk dipakai sebagai denominator KPI di tahap berikutnya. Project siap lanjut ke Tahap 7 — EDA.
