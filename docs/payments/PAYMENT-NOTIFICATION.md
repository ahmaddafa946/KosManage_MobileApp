# NOTIFICATION SUBSYSTEM SPECIFICATION: PAYMENTS & BILLING
**KosManage Mobile Platform (Multi-Channel Delivery: In-App, Realtime, and Push Notifications)**

- **Module:** Payment & Billing Notification System
- **Version:** 1.0.0
- **Status:** Approved Notification Specification
- **Path:** `docs/payments/PAYMENT-NOTIFICATION.md`

---

## 1. Overview & Multi-Channel Architecture

Sub-sistem notifikasi KosManage Mobile bertanggung jawab menyampaikan informasi penting terkait tagihan, masa sewa, dan status pembayaran kepada **Tenant** dan **Owner** secara tepat waktu.

### Tiga Saluran Pengiriman (*Multi-Channel Delivery*):
1. **In-App Notification Center:** Notifikasi persisten yang disimpan dalam tabel `notifications` dan dapat dibaca kapan saja melalui ikon lonceng pada aplikasi.
2. **Supabase Realtime Stream:** Komunikasi berbasis WebSocket dua arah yang memicu pembaruan state instan pada antarmuka pengguna (contoh: otomatis beralih ke halaman sukses saat webhook tiba tanpa perlu refresh manual).
3. **Push Notification (FCM / APNS):** Pemberitahuan langsung ke bilah notifikasi smartphone pengguna ketika aplikasi sedang tertutup atau smartphone dalam kondisi terkunci.

---

## 2. Notification Event Specifications

Berikut adalah spesifikasi lengkap untuk seluruh 9 (sembilan) event notifikasi pembayaran:

---

### 2.1 Event: `invoice_created`
- **Pemicu (Trigger):** Otomasi `generate_recurring_invoices()` atau pembuatan tagihan manual oleh pemilik kos.
- **Penerima (Recipient):** Tenant (Penghuni kamar terkait).
- **Judul Notifikasi:** *"Tagihan Sewa Baru Tersedia"*
- **Isi Pesan (Message):** *"Tagihan sewa kos periode {{billing_period}} sebesar Rp {{amount_due}} telah diterbitkan. Jatuh tempo: {{due_date}}."*
- **Entitas Terkait:** `payments` (Invoice ID).
- **Deep Link Route:** `/tenant/payments?id={{invoice_id}}`
- **Status Awal:** `is_read = false`.
- **Perilaku Realtime:** Badge angka merah di tab Tagihan bertambah 1. Hero Card "Tagihan Aktif" langsung terupdate.
- **Perilaku Push Notification:** Suara standar, prioritas tinggi (*High Priority*), membuka halaman pembayaran saat diklik.

---

### 2.2 Event: `payment_reminder`
- **Pemicu (Trigger):** Scheduler harian mendeteksi bahwa `due_date - CURRENT_DATE <= 3 hari` atau tagihan telah melewati jatuh tempo (*overdue*).
- **Penerima (Recipient):** Tenant.
- **Judul Notifikasi:** *"Pengingat Pembayaran Sewa Kos"*
- **Isi Pesan (Message):** *"Tagihan sewa kos periode {{billing_period}} sebesar Rp {{amount_due}} akan jatuh tempo dalam {{days_left}} hari. Segera lakukan pembayaran."* (Atau jika overdue: *"Tagihan Anda telah melewati jatuh tempo. Mohon segera melunasi sewa."*)
- **Entitas Terkait:** `payments` (Invoice ID).
- **Deep Link Route:** `/tenant/payments?id={{invoice_id}}`
- **Status Awal:** `is_read = false`.
- **Perilaku Realtime:** Menampilkan banner peringatan oranye/merah di Beranda Tenant.
- **Perilaku Push Notification:** Pesan pengingat berulang pada pukul 09:00 WIB.

---

### 2.3 Event: `payment_pending`
- **Pemicu (Trigger):** Tenant berhasil membuat transaksi QRIS atau Virtual Account di Edge Function `/create-payment`.
- **Penerima (Recipient):** Tenant.
- **Judul Notifikasi:** *"Menunggu Pembayaran"*
- **Isi Pesan (Message):** *"Transaksi {{payment_method}} telah dibuat. Harap selesaikan pembayaran sebelum {{expires_at}}."*
- **Entitas Terkait:** `payment_transactions` (Transaction ID).
- **Deep Link Route:** `/tenant/payments/active-session?tx_id={{transaction_id}}`
- **Status Awal:** `is_read = false`.
- **Perilaku Realtime:** Layar otomatis menampilkan QR Code atau Nomor VA dengan timer hitung mundur.
- **Perilaku Push Notification:** Tidak perlu push eksternal (cukup visual di dalam layar aplikasi karena pengguna sedang aktif bertransaksi).

---

### 2.4 Event: `payment_success`
- **Pemicu (Trigger):** Webhook Midtrans berstatus `settlement` berhasil diverifikasi oleh Edge Function.
- **Penerima (Recipient):** Tenant & Owner.
- **Versi Tenant:**
  - **Judul:** *"Pembayaran Berhasil Dilakukan!"*
  - **Pesan:** *"Terima kasih! Pembayaran sewa kos periode {{billing_period}} sebesar Rp {{amount_paid}} telah diterima. Masa sewa Anda telah diperpanjang."*
  - **Deep Link:** `/tenant/payments/receipt?id={{invoice_id}}`
- **Versi Owner:**
  - **Judul:** *"Pembayaran Sewa Diterima"*
  - **Pesan:** *"Penghuni {{tenant_name}} (Kamar {{room_number}}) telah melunasi tagihan periode {{billing_period}} sebesar Rp {{amount_paid}} via {{payment_method}}."*
  - **Deep Link:** `/owner/payments?id={{invoice_id}}`
- **Perilaku Realtime:**
  - Tenant: Layar pembayaran otomatis tertutup dan menampilkan animasi Lottie kuitansi sukses.
  - Owner: Angka pemasukan bulan ini di Dashboard Owner bertambah seketika, status tagihan berubah menjadi LUNAS (hijau).
- **Perilaku Push Notification:** Suara lonceng kasir (*cash register chimes*), notifikasi Heads-Up di smartphone.

---

### 2.5 Event: `payment_failed`
- **Pemicu (Trigger):** Webhook gateway menyatakan transaksi ditolak (`deny`, `failure`) oleh pihak perbankan.
- **Penerima (Recipient):** Tenant.
- **Judul Notifikasi:** *"Pembayaran Gagal Diproses"*
- **Isi Pesan (Message):** *"Transaksi pembayaran via {{payment_method}} tidak berhasil diproses oleh bank penerbit. Silakan pilih metode lain atau ulangi pembayaran."*
- **Entitas Terkait:** `payment_transactions`.
- **Deep Link Route:** `/tenant/payments?id={{invoice_id}}`
- **Status Awal:** `is_read = false`.
- **Perilaku Realtime:** Menampilkan snackbar merah dan modal opsi mencoba metode lain.
- **Perilaku Push Notification:** Notifikasi prioritas sedang.

---

### 2.6 Event: `payment_expired`
- **Pemicu (Trigger):** Sesi waktu bayar QRIS (15 menit) atau VA (24 jam) terlampaui tanpa ada transfer masuk.
- **Penerima (Recipient):** Tenant.
- **Judul Notifikasi:** *"Sesi Pembayaran Kedaluwarsa"*
- **Isi Pesan (Message):** *"Sesi pembayaran tagihan periode {{billing_period}} telah kedaluwarsa. Silakan buat kode pembayaran baru."*
- **Entitas Terkait:** `payment_transactions`.
- **Deep Link Route:** `/tenant/payments?id={{invoice_id}}`
- **Status Awal:** `is_read = false`.
- **Perilaku Realtime:** Timer hitung mundur berubah menjadi warna abu-abu bertuliskan "Kedaluwarsa" dan menampilkan tombol [Buat QRIS/VA Baru].
- **Perilaku Push Notification:** Notifikasi informatif.

---

### 2.7 Event: `cash_confirmation_required`
- **Pemicu (Trigger):** Tenant memilih metode pembayaran Tunai di aplikasi (`/cash-payment`).
- **Penerima (Recipient):** Owner (Pemilik kos).
- **Judul Notifikasi:** *"Permintaan Konfirmasi Pembayaran Tunai"*
- **Isi Pesan (Message):** *"Penghuni {{tenant_name}} (Kamar {{room_number}}) mengajukan pembayaran tunai sebesar Rp {{amount_due}}. Silakan periksa penerimaan uang fisik."*
- **Entitas Terkait:** `payment_transactions` (Cash Transaction ID).
- **Deep Link Route:** `/owner/payments?filter=waiting_confirmation&id={{payment_id}}`
- **Status Awal:** `is_read = false`.
- **Perilaku Realtime:** Menampilkan badge kuning di tab Pembayaran Owner dan memunculkan tombol aksi satu-klik *"Konfirmasi Tunai"*.
- **Perilaku Push Notification:** Prioritas tinggi, getaran panjang.

---

### 2.8 Event: `cash_payment_confirmed`
- **Pemicu (Trigger):** Owner menekan tombol "Konfirmasi Pembayaran Diterima" pada modal persetujuan kas.
- **Penerima (Recipient):** Tenant.
- **Judul Notifikasi:** *"Pembayaran Tunai Dikonfirmasi Pemilik"*
- **Isi Pesan (Message):** *"Pemilik kos telah mengonfirmasi penerimaan uang tunai sewa kos periode {{billing_period}} sebesar Rp {{amount_paid}}. Kuitansi digital telah diterbitkan."*
- **Entitas Terkait:** `payments` (Invoice ID).
- **Deep Link Route:** `/tenant/payments/receipt?id={{invoice_id}}`
- **Status Awal:** `is_read = false`.
- **Perilaku Realtime:** Status di layar tenant seketika berubah dari "Menunggu Konfirmasi" menjadi "Lunas".
- **Perilaku Push Notification:** Suara notifikasi sukses.

---

### 2.9 Event: `rental_renewed`
- **Pemicu (Trigger):** Stored procedure `public.apply_rental_renewal` berhasil mengeksekusi penambahan masa sewa (+1 bulan).
- **Penerima (Recipient):** Tenant & Owner.
- **Judul Notifikasi:** *"Masa Sewa Kamar Diperpanjang"*
- **Isi Pesan (Message):** *"Masa sewa Kamar {{room_number}} berhasil diperpanjang hingga tanggal {{new_end_date}}."*
- **Entitas Terkait:** `rental_renewals` (Renewal Record ID).
- **Deep Link Route:** `/tenant/room` (untuk Tenant) dan `/owner/tenants?id={{tenant_id}}` (untuk Owner).
- **Status Awal:** `is_read = false`.
- **Perilaku Realtime:** Countdown sewa pada kartu "Kamar Saya" langsung terupdate dengan sisa hari yang baru.
- **Perilaku Push Notification:** Notifikasi konfirmasi pembaruan kontrak.

---

## 3. Database Schema for Notifications

```sql
-- Tabel Notifikasi Terpusat
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title VARCHAR(150) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(50) NOT NULL,
    data JSONB DEFAULT '{}'::jsonb,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indeks Kinerja
CREATE INDEX IF NOT EXISTS idx_notif_profile_unread ON public.notifications(profile_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notif_created_at ON public.notifications(created_at DESC);
```

### Format Payload Data JSONB:
```json
{
  "deep_link": "/tenant/payments/receipt?id=9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "invoice_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "transaction_id": "4e1a1234-abcd-4ef0-9123-abcdef012345",
  "amount": 1200000,
  "room_number": "101",
  "billing_period": "2026-11"
}
```
