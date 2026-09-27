-- ============================================================
-- File   : sql/04_data_cleaning.sql
-- Tujuan : Tahap 5 — Data Cleaning: bentuk table `sales` bersih
--          dari `sales_raw`, terapkan seluruh keputusan cleaning
--          dari temuan Tahap 4 (lihat docs/03_data_profiling.md)
-- Prasyarat : sql/02_data_collection.sql sudah dijalankan (sales_raw ada)
-- ============================================================

-- ------------------------------------------------------------
-- Keputusan cleaning (ringkas — detail lengkap di docs/04_data_cleaning.md):
-- 1. Source tanggal    : pakai "Waktu Pesanan Dibuat" (0 missing, unambigu),
--                         bukan order_date (188 missing, format DD/MM/YYYY ambigu)
-- 2. Metode Pembayaran : normalisasi varian kapitalisasi/spasi jadi kategori
--                         kanonik; NULL -> 'Tidak Diketahui' (bukan di-drop)
-- 3. Status Pesanan    : 6 varian "window retur" dikonsolidasi jadi
--                         'Diterima (window retur)'
-- 4. total_qty missing : tetap NULL, ditandai flag_qty_missing (bukan di-drop
--                         atau diisi 0/mean)
-- 5. flag_selesai_bayar_nol : baris di-retain apa adanya (revenue tetap
--                         dihitung 0), ditandai flag, bukan di-exclude
-- 6. Outlier total_qty : di-retain, tidak di-cap/di-exclude
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE sales AS
SELECT
  order_id,

  -- numeric casting
  TRY_CAST(total_qty AS INTEGER)              AS total_qty,
  TRY_CAST(total_weight_gr AS DOUBLE)         AS total_weight_gr,
  TRY_CAST(total_returned_qty AS INTEGER)     AS total_returned_qty,
  TRY_CAST("Total Diskon" AS DOUBLE)          AS total_diskon,
  TRY_CAST(num_product_categories AS INTEGER) AS num_product_categories,
  TRY_CAST("Ongkos Kirim Dibayar oleh Pembeli" AS DOUBLE)   AS ongkir_dibayar_pembeli,
  TRY_CAST("Estimasi Potongan Biaya Pengiriman" AS DOUBLE)  AS estimasi_potongan_ongkir,
  TRY_CAST("Total Pembayaran" AS DOUBLE)      AS total_pembayaran,
  TRY_CAST("Perkiraan Ongkos Kirim" AS DOUBLE) AS perkiraan_ongkos_kirim,

  -- text passthrough
  product_categories,
  "Alasan Pembatalan" AS alasan_pembatalan,
  "Opsi Pengiriman"   AS opsi_pengiriman,
  "Kota/Kabupaten"    AS kota_kabupaten,
  "Provinsi"          AS provinsi,

  -- Status Pesanan: konsolidasi 6 varian "window retur"
  CASE
    WHEN "Status Pesanan" LIKE 'Pesanan diterima, namun%'
      THEN 'Diterima (window retur)'
    ELSE "Status Pesanan"
  END AS status_pesanan,

  -- Metode Pembayaran: normalisasi varian
  CASE
    WHEN "Metode Pembayaran" IN ('COD (Bayar di Tempat)', 'Cash On Delivery', 'COD')
      THEN 'COD'
    WHEN lower("Metode Pembayaran") IN ('saldo shopeepay', 'shopeepay')
      THEN 'ShopeePay'
    WHEN lower("Metode Pembayaran") IN ('online payment', 'onlinepayment')
      THEN 'Online Payment'
    WHEN "Metode Pembayaran" IN ('SPayLater', 'SPay Later')
      THEN 'SPayLater'
    WHEN "Metode Pembayaran" IN ('Kartu Kredit/Debit', 'Cicilan Kartu Kredit')
      THEN 'Kartu Kredit/Debit'
    WHEN "Metode Pembayaran" IS NULL
      THEN 'Tidak Diketahui'
    ELSE "Metode Pembayaran"
  END AS metode_pembayaran,

  -- tanggal: source of truth = Waktu Pesanan Dibuat (bukan order_date)
  TRY_CAST("Waktu Pesanan Dibuat" AS TIMESTAMP) AS waktu_pesanan_dibuat,
  CAST(TRY_CAST("Waktu Pesanan Dibuat" AS TIMESTAMP) AS DATE) AS order_date_clean,
  date_trunc('month', TRY_CAST("Waktu Pesanan Dibuat" AS TIMESTAMP)) AS order_month,

  -- flags, bukan exclude
  CASE WHEN total_qty IS NULL THEN TRUE ELSE FALSE END AS flag_qty_missing,
  CASE
    WHEN "Status Pesanan" = 'Selesai' AND TRY_CAST("Total Pembayaran" AS DOUBLE) = 0
      THEN TRUE ELSE FALSE
  END AS flag_selesai_bayar_nol

FROM sales_raw;

-- ------------------------------------------------------------
-- Validasi pasca cleaning — pastikan tidak ada baris hilang/nambah
-- dan flag/kategori baru sesuai ekspektasi dari profiling
-- ------------------------------------------------------------

-- Row count harus tetap 18.868
SELECT COUNT(*) AS total_rows_after_cleaning FROM sales;

-- Metode Pembayaran setelah normalisasi (harus jauh lebih sedikit kategori)
SELECT metode_pembayaran, COUNT(*) AS jumlah
FROM sales GROUP BY 1 ORDER BY jumlah DESC;

-- Status Pesanan setelah konsolidasi (window retur harus jadi 1 baris = 161)
SELECT status_pesanan, COUNT(*) AS jumlah
FROM sales GROUP BY 1 ORDER BY jumlah DESC;

-- Flag counts harus cocok dengan profiling (283 dan 56)
SELECT
  SUM(CASE WHEN flag_qty_missing THEN 1 ELSE 0 END) AS jumlah_flag_qty_missing,
  SUM(CASE WHEN flag_selesai_bayar_nol THEN 1 ELSE 0 END) AS jumlah_flag_selesai_bayar_nol
FROM sales;

-- Cek order_date_clean tidak ada yang NULL (Waktu Pesanan Dibuat = 0 missing)
SELECT COUNT(*) AS missing_order_date_clean
FROM sales WHERE order_date_clean IS NULL;

-- Cek ulang missing period pakai kolom tanggal yang baru (harus tetap sama: Des 2024 & Jul 2025)
SELECT strftime(order_month, '%Y-%m') AS bulan, COUNT(*) AS jumlah_baris
FROM sales GROUP BY 1 ORDER BY 1;
