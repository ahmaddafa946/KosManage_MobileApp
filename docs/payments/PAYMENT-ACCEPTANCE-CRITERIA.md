# PAYMENT & BILLING ACCEPTANCE CRITERIA
**KosManage Mobile Platform (Verification Checklist, Functional Guarantees, and Production Sign-Off)**

- **Module:** Payment & Billing Quality Gates
- **Version:** 1.0.0
- **Status:** Approved Acceptance Criteria
- **Path:** `docs/payments/PAYMENT-ACCEPTANCE-CRITERIA.md`

---

## 1. Quality Gates Overview

Checklist ini merupakan kriteria penerimaan resmi (*Definition of Acceptance*) yang harus dipenuhi secara penuh sebelum fitur pembayaran dan penagihan otomatis dinyatakan siap rilis (*Production Ready*).

---

## 2. Acceptance Criteria Checklist

### BILLING
- [ ] Tagihan otomatis diterbitkan oleh `pg_cron` setiap hari pukul 00:05 WIB untuk tenant aktif yang masa sewanya telah atau akan berakhir.
- [ ] Tagihan memiliki nominal (`amount_due`) yang tepat sesuai dengan `rent_price` kamar/penghuni yang tersimpan di database.
- [ ] Tagihan memiliki tanggal jatuh tempo (`due_date`) yang dihitung secara benar berbasis tanggal akhir periode sebelumnya.
- [ ] Sistem tidak pernah membuat tagihan duplikat untuk tenant dan periode sewa (`billing_period`) yang sama (`ON CONFLICT DO NOTHING`).
- [ ] Tagihan yang belum lunas setelah melewati toleransi 3 hari (*grace period*) secara otomatis berubah statusnya menjadi `overdue`.
- [ ] Tagihan yang telah lunas tidak pernah berubah statusnya menjadi `overdue`.
- [ ] Pemilik kos tetap dapat membuat tagihan manual melalui aplikasi mobile tanpa mengganggu sistem penagihan otomatis.

### TENANT
- [ ] Tenant dapat melihat tagihan aktif miliknya di bagian atas (Hero Card) pada tab Tagihan.
- [ ] Tenant dapat melihat nominal tagihan berformat Rupiah, tanggal jatuh tempo, dan hitung mundur sisa hari.
- [ ] Tenant dapat menekan tombol [Bayar Sekarang] pada tagihan aktif yang belum lunas.
- [ ] Tenant disajikan pilihan metode pembayaran yang jelas: QRIS, Transfer Bank / Virtual Account, dan Tunai (Cash).
- [ ] Tenant hanya dapat melihat tagihan dan riwayat transaksi miliknya sendiri.
- [ ] Tenant dilarang mengubah status tagihan secara mandiri atau memanipulasi nominal tagihan.
- [ ] Tenant menerima kuitansi digital setelah pembayaran berhasil diverifikasi.

### QRIS
- [ ] Memilih metode QRIS memicu pembuatan transaksi di gateway dan mengembalikan payload EMVCo dalam waktu $< 3$ detik.
- [ ] Aplikasi Flutter merender QR Code dinamis dengan ketajaman tinggi yang mudah dipindai oleh aplikasi m-Banking dan e-Wallet.
- [ ] Layar menampilkan timer hitung mundur sesi pembayaran (15 menit).
- [ ] Tersedia tombol [Simpan QR / Tangkapan Layar] untuk memudahkan pembayaran jika dilakukan pada smartphone yang sama.
- [ ] Setelah pembayaran diselesaikan di simulator/e-wallet, status di aplikasi tenant otomatis berubah menjadi 'Lunas' tanpa perlu refresh manual (via Realtime WebSocket).
- [ ] Jika sesi 15 menit habis sebelum dibayar, QR Code otomatis dinonaktifkan dan muncul tombol [Buat QRIS Baru].

### BANK TRANSFER
- [ ] Tenant dapat memilih bank tujuan: BCA, BNI, BRI, Mandiri, atau Permata.
- [ ] Sistem menampilkan nomor Virtual Account resmi dari gateway beserta logo bank terkait.
- [ ] Tersedia tombol [Salin Nomor VA] yang langsung menyalin nomor ke clipboard dan memunculkan feedback visual.
- [ ] Layar menyajikan petunjuk langkah demi langkah transfer melalui ATM dan Mobile Banking.
- [ ] Sesi Virtual Account aktif selama 24 jam sebelum kedaluwarsa.
- [ ] Pelunasan transfer VA langsung terdeteksi oleh sistem melalui webhook settlement.

### CASH
- [ ] Tenant dapat mengajukan pembayaran tunai dengan status awal `waiting_confirmation`.
- [ ] Tenant melihat instruksi jelas untuk menyerahkan uang fisik langsung kepada pemilik kos.
- [ ] Tenant dilarang dan tidak memiliki kemampuan untuk mengonfirmasi sendiri kelunasan pembayaran tunai.
- [ ] Owner menerima notifikasi adanya pengajuan pembayaran tunai lengkap dengan nama penghuni, kamar, dan nominal.
- [ ] Owner memiliki tombol tindakan [Konfirmasi Pembayaran Diterima] pada menu pembayarannya.
- [ ] Menekan tombol konfirmasi menampilkan dialog verifikasi fisik yang meminta owner memastikan uang telah di tangan.
- [ ] Konfirmasi oleh owner secara instan mengubah status invoice menjadi `paid` dan memperpanjang masa sewa tenant.

### WEBHOOK
- [ ] Endpoint `/payment-webhook` hanya memproses payload dengan tanda tangan kriptografis SHA-512 yang valid.
- [ ] Payload dengan signature tidak valid langsung ditolak dengan respon HTTP 401 Unauthorized.
- [ ] Webhook yang dikirim ulang oleh gateway (duplikat) diidentifikasi oleh tabel `payment_webhook_events` dan dibalas HTTP 200 tanpa mengeksekusi mutasi berulang.
- [ ] Webhook out-of-order ditangani dengan benar: event `settlement` selalu diutamakan dan tidak boleh digugurkan oleh event `expire` yang terlambat.
- [ ] Webhook berhasil memperbarui status baris `payments` dan `payment_transactions` secara atomik dalam satu transaksi database.

### SECURITY
- [ ] Kode sumber aplikasi Flutter **TIDAK MEMUAT** `MIDTRANS_SERVER_KEY` atau `SUPABASE_SERVICE_ROLE_KEY`.
- [ ] `MIDTRANS_SERVER_KEY` hanya disimpan dalam Supabase Secrets (Environment Server).
- [ ] Nominal uang tidak pernah diterima dari input klien Flutter; nominal dihitung secara otoritatif di server.
- [ ] Row Level Security (RLS) aktif pada semua tabel finansial (`payments`, `payment_transactions`, `notifications`).
- [ ] Owner A tidak dapat melihat data transaksi properti milik Owner B.
- [ ] Tenant A tidak dapat melihat data tagihan milik Tenant B.
- [ ] Trigger database aktif untuk mencegah eskalasi wewenang peran (*role privilege escalation*).

### NOTIFICATION
- [ ] Tenant menerima notifikasi in-app dan push saat tagihan baru diterbitkan (`invoice_created`).
- [ ] Tenant menerima notifikasi pengingat H-3 dan H-1 sebelum jatuh tempo (`payment_reminder`).
- [ ] Tenant dan Owner menerima notifikasi saat pembayaran berhasil diverifikasi (`payment_success`).
- [ ] Owner menerima notifikasi saat ada tenant yang mengajukan pembayaran tunai (`cash_confirmation_required`).
- [ ] Setiap notifikasi memuat deep link yang ketika diklik langsung membuka detail tagihan terkait di aplikasi.

### RENTAL RENEWAL
- [ ] Pembayaran tagihan renewal yang lunas secara otomatis memperpanjang `tenants.end_date` tepat 1 bulan kalender `(end_date + INTERVAL '1 month')::date`.
- [ ] Kolom `payments.renewal_applied_at` terisi timestamp pelunasan sebagai kunci proteksi idempotensi.
- [ ] Retry webhook atau klik berulang tidak pernah memperpanjang masa sewa lebih dari 1 kali untuk invoice yang sama.
- [ ] Riwayat perpanjangan sewa tercatat permanen di tabel audit `rental_renewals`.

### TESTING
- [ ] Seluruh unit test model, validator, dan countdown calculator lulus 100%.
- [ ] Widget test untuk dialog pembayaran, tombol salin VA, dan hero card lulus tanpa layout overflow.
- [ ] Pengujian idempotensi database Stored Procedure lulus (eksekusi ganda menghasilkan tepat 1 invoice).
- [ ] Pengujian isolasi RLS lulus (tenant tidak bisa membaca data tenant lain).
- [ ] Pengujian sandbox Midtrans simulator (QRIS dan Virtual Account) berhasil dari pembuatan hingga webhook settlement.

### PRODUCTION READINESS
- [ ] Kredensial Midtrans Production terdaftar dan tersimpan aman di Supabase Secrets.
- [ ] Webhook URL terdaftar secara resmi di dashboard merchant Midtrans dengan protokol HTTPS.
- [ ] Dokumentasi arsitektur, API, state machine, dan database tersimpan lengkap di folder `docs/payments/`.
- [ ] Seluruh aturan arsitektur Flutter, Riverpod, dan GoRouter selaras dengan baseline KosManage Mobile.
- [ ] Tidak ada regresi pada fitur eksisting KosManage (kamar, penghuni, laporan keuangan).
