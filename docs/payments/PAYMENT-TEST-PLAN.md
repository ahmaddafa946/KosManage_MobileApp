# COMPREHENSIVE PAYMENT & BILLING TEST PLAN
**KosManage Mobile Platform (Unit, Widget, Integration, Database, RLS, Edge Functions & Sandbox Gateway QA)**

- **Module:** Quality Assurance & Test Engineering
- **Version:** 1.0.0
- **Status:** Approved Test Plan
- **Path:** `docs/payments/PAYMENT-TEST-PLAN.md`

---

## 1. Overview & Test Strategy

Rencana pengujian (*test plan*) ini mencakup seluruh lapisan arsitektur sistem pembayaran dan penagihan otomatis untuk memastikan keandalan finansial tanpa celah:
1. **Dart Unit & Model Tests:** Pengujian model data, formatter mata uang, kalkulator countdown, dan validator.
2. **Flutter Widget Tests:** Pengujian komponen antarmuka pengguna (Hero card, QRIS renderer, Virtual Account box, dialog konfirmasi tunai).
3. **Database & Stored Procedure Tests (pgTAP / SQL):** Pengujian logika `generate_recurring_invoices()` dan `apply_rental_renewal()`.
4. **Row Level Security (RLS) Isolation Tests:** Pengujian isolasi multi-tenant antar pengguna.
5. **Edge Function & Webhook Tests:** Pengujian integrasi API, tanda tangan SHA-512, idempotensi event duplikat, dan penanganan webhook out-of-order.
6. **End-to-End Midtrans Sandbox Gateway Tests:** Pengujian skenario nyata menggunakan Midtrans Payment Simulator.

---

## 2. Test Matrix & Coverage Summary

| Kategori Tes | Lingkup / Komponen | Target File / Runner | Target Cakupan |
|---|---|---|---|
| **Unit Test** | Domain Models, Formatters, Status Helpers | `test/payments/unit/*_test.dart` | >95% Branch Coverage |
| **Widget Test** | Payment Screens, Dialogs, Countdowns | `test/payments/widget/*_test.dart` | 100% Critical User Flows |
| **Integration Test** | Repository <-> Supabase Local Stack | `test/payments/integration/*_test.dart` | Happy & Failure Paths |
| **Database & RLS** | PostgreSQL Constraints, Functions, RLS | SQL Runner / pgTAP Test Suites | 100% Security Boundary |
| **Edge Function** | Deno TypeScript Endpoints | Deno Test Runner (`deno test`) | Webhook, Crypto, Intent |
| **Sandbox Gateway** | Midtrans Sandbox Simulator | QA Staging Manual & Automated Scripts | QRIS, BCA VA, Cash Flows |

---

## 3. Detailed Test Suites

### 3.1 Unit Testing (Dart)
- [ ] **TC-UNIT-01 (Invoice Model Parsing):** Memastikan `OwnerPayment.fromJson` dan model Invoice baru dapat membaca seluruh field relasi `tenants`, `rooms`, `period_start`, dan `invoice_number` tanpa error null.
- [ ] **TC-UNIT-02 (Remaining Amount Calculator):** Memastikan getter `remaining` mengembalikan `amount_due - amount_paid` dan tidak pernah mengembalikan angka negatif.
- [ ] **TC-UNIT-03 (Payment Countdown Service):** Menguji fungsi countdown sesi bayar (15 menit untuk QRIS dan 24 jam untuk VA) terhadap referensi waktu sekarang (*mocked clock*).
- [ ] **TC-UNIT-04 (Currency & VA Formatter):** Memverifikasi format Rupiah (`formatRupiah`) dan format spasi nomor Virtual Account (contoh: `9101 2123 4567 8901`).

---

### 3.2 Flutter Widget & Screen Testing
- [ ] **TC-WDG-01 (Active Bill Hero Card):** Widget merender nominal besar, status badge berwarna sesuai, dan tanggal jatuh tempo dengan benar.
- [ ] **TC-WDG-02 (QRIS Screen Display):** Widget merender string QRIS menggunakan widget QR barcode, menampilkan tombol "Simpan Gambar", dan ticker waktu mundur 15 menit.
- [ ] **TC-WDG-03 (Virtual Account Copy Box):** Menekan tombol [Salin Nomor VA] menyalin string nomor ke Clipboard sistem dan menampilkan snackbar konfirmasi.
- [ ] **TC-WDG-04 (Cash Waiting State UI):** Layar tenant menampilkan banner kuning peringatan "Menunggu Konfirmasi Pemilik" dan menonaktifkan tombol bayar ganda.
- [ ] **TC-WDG-05 (Owner Cash Confirmation Modal):** Dialog verifikasi kas menampilkan nama penghuni, nomor kamar, nominal fisik, dan tombol konfirmasi yang terlindungi dari double-tap (*async button lock*).

---

### 3.3 Database & Stored Procedure Testing (PostgreSQL)
- [ ] **TC-DB-01 (Idempotent Invoice Generation):**
  - **Skenario:** Jalankan `SELECT generate_recurring_invoices()` untuk 5 tenant aktif.
  - **Ekspektasi:** Terbentuk 5 baris tagihan baru.
  - **Tindakan Lanjutan:** Jalankan fungsi yang sama sekali lagi di hari yang sama.
  - **Ekspektasi:** Tidak ada baris tagihan baru yang bertambah (jumlah tetap 5 baris, `ON CONFLICT DO NOTHING`).
- [ ] **TC-DB-02 (Unique Constraint Validation):**
  - **Skenario:** Mencoba `INSERT` manual baris kedua dengan `tenant_id` dan `billing_period` yang sama.
  - **Ekspektasi:** PostgreSQL menolak dengan error `duplicate key value violates unique constraint "uq_payments_tenant_billing_period"`.
- [ ] **TC-DB-03 (Atomic Rental Renewal):**
  - **Skenario:** Panggil `public.apply_rental_renewal(payment_id)` pada tagihan lunas.
  - **Ekspektasi:** Kolom `tenants.end_date` bertambah tepat 1 bulan kalender, `renewal_applied_at` terisi timestamp, dan 1 baris tercatat di `rental_renewals`.
- [ ] **TC-DB-04 (Duplicate Renewal Prevention):**
  - **Skenario:** Panggil `public.apply_rental_renewal(payment_id)` untuk kedua kalinya pada baris yang sama.
  - **Ekspektasi:** Fungsi mengembalikan `false`, dan `tenants.end_date` **TIDAK BERUBAH LAGI** (mencegah penambahan sewa ganda).

---

### 3.4 Row Level Security (RLS) Isolation Testing
- [ ] **TC-RLS-01 (Tenant Cross-Access Prevention):**
  - Login sebagai Tenant A (`auth.uid() = UserA`).
  - Query: `SELECT * FROM payments WHERE tenant_id = 'TenantB'`.
  - Ekspektasi: Hasil query kosong (*0 rows returned*).
- [ ] **TC-RLS-02 (Tenant Mutation Prevention):**
  - Login sebagai Tenant A.
  - Query: `UPDATE payments SET amount_due = 1000 WHERE id = 'InvoiceA'`.
  - Ekspektasi: PostgreSQL RLS menolak mutasi (*0 rows updated* atau permission denied).
- [ ] **TC-RLS-03 (Owner Cross-Property Prevention):**
  - Login sebagai Owner A.
  - Query: `SELECT * FROM payments WHERE property_id = 'PropertyB'`.
  - Ekspektasi: Hasil query kosong (*0 rows returned*).

---

### 3.5 Supabase Edge Functions & Webhook Testing
- [ ] **TC-EF-01 (Create Payment Intent):**
  - Panggil `POST /create-payment` dengan token JWT tenant sah.
  - Ekspektasi: Respon HTTP 200 memuat `qr_string` dan `transaction_id`.
- [ ] **TC-EF-02 (Signature Verification - Valid):**
  - Kirim mock webhook settlement Midtrans dengan signature SHA-512 yang dihitung menggunakan Server Key yang benar.
  - Ekspektasi: Respon HTTP 200, status transaksi berubah menjadi `'success'`, invoice menjadi `'paid'`.
- [ ] **TC-EF-03 (Signature Verification - Invalid / Attack):**
  - Kirim mock webhook dengan signature palsu / sembarang.
  - Ekspektasi: Respon HTTP 401 Unauthorized, database tidak berubah.
- [ ] **TC-EF-04 (Duplicate Webhook Idempotency):**
  - Kirim webhook settlement yang sama persis 2 kali berturut-turut.
  - Ekspektasi: Panggilan kedua mengembalikan HTTP 200 dengan pesan `"Event already processed"`, dan masa sewa tidak diperpanjang dua kali.
- [ ] **TC-EF-05 (Out-of-Order Webhook Resolution):**
  - Kirim webhook `expire`, lalu 5 detik kemudian kirim webhook `settlement`.
  - Ekspektasi: Sistem secara cerdas mempromosikan status transaksi akhir menjadi `'success'` dan tagihan menjadi `'paid'` karena dana nyata telah diterima.

---

### 3.6 Midtrans Sandbox Simulator End-to-End Scenarios
- [ ] **TC-SBX-01 (QRIS Happy Path):** Buat tagihan $\rightarrow$ Pilih QRIS $\rightarrow$ Scan di Midtrans Simulator $\rightarrow$ Bayar sukses $\rightarrow$ Verifikasi UI Flutter update seketika via Realtime.
- [ ] **TC-SBX-02 (BCA Virtual Account Happy Path):** Buat tagihan $\rightarrow$ Pilih BCA VA $\rightarrow$ Masukkan nomor VA di simulator perbankan $\rightarrow$ Bayar sukses $\rightarrow$ Verifikasi status lunas.
- [ ] **TC-SBX-03 (Cash Two-Way Flow):** Tenant pilih Tunai $\rightarrow$ Owner buka aplikasi $\rightarrow$ Owner konfirmasi penerimaan uang $\rightarrow$ Kuitansi digital terbit.
- [ ] **TC-SBX-04 (Expired Session & Retry):** Biarkan sesi QRIS habis (15 menit) $\rightarrow$ Status berubah expired $\rightarrow$ Tap [Coba Lagi] $\rightarrow$ Sesi QRIS baru terbit dan dapat dibayar normal.
