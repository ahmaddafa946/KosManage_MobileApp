# END-TO-END PAYMENT FLOW SPECIFICATION
**KosManage Mobile Platform (Step-by-Step Sequence Flows & Edge Case Handlers)**

- **Module:** Payment & Billing Operational Flows
- **Version:** 1.0.0
- **Status:** Approved Technical Specification
- **Path:** `docs/payments/PAYMENT-FLOW.md`

---

## 1. Overview

Dokumen ini mendokumentasikan secara rinci 10 (sepuluh) alur kerja (*operational flows*) sistem penagihan otomatis dan pembayaran di KosManage Mobile, mencakup alur normal (*happy path*), penanganan kegagalan (*failure path*), dan penanganan kondisi batas (*edge cases*).

---

## 2. Flow A: Automatic Billing Workflow

Alur pembuatan tagihan otomatis secara terjadwal di level cloud backend (*server-side scheduled billing*).

```mermaid
sequenceDiagram
    autonumber
    participant Cron as Supabase pg_cron (Daily 00:05 WIB)
    participant Worker as Stored Procedure (generate_recurring_invoices)
    participant DB as PostgreSQL Database
    participant Stream as Supabase Realtime
    actor Tenant as Tenant (Mobile App)

    Cron->>Worker: Trigger Scheduled Job: SELECT generate_recurring_invoices()
    Worker->>DB: Query tenant aktif dengan end_date <= CURRENT_DATE
    loop Setiap Tenant yang Memenuhi Syarat
        Worker->>DB: Cek apakah sudah ada tagihan untuk billing_period berikutnya
        alt Tagihan Belum Ada (Unique Constraint Guard)
            Worker->>DB: Hitung period_start, period_end, due_date
            Worker->>DB: INSERT INTO payments (status: 'pending', amount_due: rent_price, is_renewal: true)
            Worker->>DB: INSERT INTO notifications (type: 'invoice_created', profile_id: tenant.profile_id)
            Worker->>Stream: Broadcast event DB Insert
        else Tagihan Sudah Ada
            Worker->>Worker: Lewati (ON CONFLICT DO NOTHING)
        end
    end
    Worker-->>Cron: Eksekusi Selesai (Logged)
    Stream-->>Tenant: Push Realtime Event ke Perangkat Tenant
    Tenant->>Tenant: Tampilkan Lencana Tagihan Baru & Notifikasi
```

### Penjelasan Langkah demi Langkah:
1. **Trigger Terjadwal:** Setiap hari pukul 00:05 WIB, `pg_cron` memanggil fungsi `public.generate_recurring_invoices()`.
2. **Identifikasi Tenant:** Sistem menyaring tabel `tenants` dengan kondisi `status = 'active'` dan `end_date <= CURRENT_DATE`.
3. **Pemeriksaan Idempotensi:** Sistem memeriksa apakah kombinasi `(tenant_id, billing_period)` sudah ada di tabel `payments`.
4. **Penerbitan Invoice:** Jika belum ada, sistem menerbitkan record invoice baru dengan nominal `amount_due = rent_price`, `due_date = period_start`, dan status awal `'pending'`.
5. **Notifikasi Otomatis:** Sistem membuat pesan di tabel `notifications` yang memicu push notification ke smartphone tenant.

---

## 3. Flow B: QRIS Dynamic Payment Workflow

Alur pembayaran menggunakan QRIS Dinamis standar EMVCo Nasional (Gopay, OVO, Dana, ShopeePay, BCA, dll).

```mermaid
sequenceDiagram
    autonumber
    actor Tenant as Tenant (Mobile App)
    participant EF_Create as Edge Function (/create-payment)
    participant DB as PostgreSQL Database
    participant Midtrans as Midtrans Core API
    participant EF_Hook as Edge Function (/payment-webhook)
    actor Owner as Owner (Mobile App)

    Tenant->>Tenant: Buka Tab Tagihan -> Tap [Bayar Sekarang]
    Tenant->>Tenant: Pilih Metode: [QRIS]
    Tenant->>EF_Create: POST /create-payment {invoice_id, payment_method: 'qris'}
    EF_Create->>DB: Cek Invoice & Kunci Baris (SELECT FOR UPDATE)
    EF_Create->>Midtrans: POST /v2/charge (payment_type: 'qris', gross_amount, order_id)
    Midtrans-->>EF_Create: Return 200 OK {qr_string, qr_url, expire_time: 15 menit}
    EF_Create->>DB: INSERT INTO payment_transactions (status: 'pending', qr_string, expires_at)
    EF_Create-->>Tenant: Return {transaction_id, qr_string, qr_url, expires_at}
    
    Tenant->>Tenant: Render QR Code Dinamis & Mulai Hitung Mundur (15 Menit)
    Tenant->>Tenant: Tenant melakukan scan & bayar via m-Banking / E-Wallet
    
    Midtrans->>EF_Hook: POST /payment-webhook {order_id, transaction_status: 'settlement', signature_key}
    EF_Hook->>EF_Hook: Verifikasi Signature SHA-512
    EF_Hook->>DB: Catat ke payment_webhook_events (Idempotency)
    EF_Hook->>DB: UPDATE payment_transactions SET status = 'success', paid_at = NOW()
    EF_Hook->>DB: UPDATE payments SET status = 'paid', amount_paid = amount_due, paid_at = NOW()
    EF_Hook->>DB: Eksekusi apply_rental_renewal (tenants.end_date + 1 bulan)
    EF_Hook->>DB: INSERT notifications untuk Tenant & Owner
    EF_Hook-->>Midtrans: Return 200 OK
    
    DB-->>Tenant: Supabase Realtime Stream: status -> 'paid'
    Tenant->>Tenant: Tampilkan Animasi Sukses & Kuitansi Digital
    DB-->>Owner: Supabase Realtime Stream: Tagihan Lunas
```

---

## 4. Flow C: Bank Transfer / Virtual Account Workflow

Alur pembayaran menggunakan nomor rekening Virtual Account bank terkemuka (BCA, BNI, BRI, Mandiri, Permata).

```mermaid
sequenceDiagram
    autonumber
    actor Tenant as Tenant (Mobile App)
    participant EF_Create as Edge Function (/create-payment)
    participant DB as PostgreSQL Database
    participant Midtrans as Midtrans Core API
    participant EF_Hook as Edge Function (/payment-webhook)

    Tenant->>Tenant: Buka Tagihan -> Pilih [Transfer Bank / Virtual Account]
    Tenant->>Tenant: Pilih Bank (contoh: BCA)
    Tenant->>EF_Create: POST /create-payment {invoice_id, payment_method: 'bank_transfer', bank: 'bca'}
    EF_Create->>DB: Query Nominal Resmi Invoice
    EF_Create->>Midtrans: POST /v2/charge (payment_type: 'bank_transfer', bank: 'bca')
    Midtrans-->>EF_Create: Return 200 OK {va_number: '123456789012', expire_time: 24 jam}
    EF_Create->>DB: Simpan payment_transactions (status: 'pending', va_number, bank)
    EF_Create-->>Tenant: Return {va_number, bank, expires_at, instructions}
    
    Tenant->>Tenant: Tampilkan Nomor VA, Tombol Salin, Petunjuk M-Banking / ATM
    Tenant->>Tenant: Melakukan Transfer Dana via M-Banking
    
    Midtrans->>EF_Hook: POST /payment-webhook {order_id, transaction_status: 'settlement'}
    EF_Hook->>DB: Verifikasi & Update payment_transactions -> 'success'
    EF_Hook->>DB: Update payments -> 'paid' & Perpanjang sewa
    EF_Hook-->>Midtrans: Return 200 OK
    
    DB-->>Tenant: Realtime Event: Status Lunas
    Tenant->>Tenant: Tampilkan Kuitansi Pembayaran
```

---

## 5. Flow D: Cash Payment Workflow

Alur pembayaran tunai langsung dengan verifikasi aman dua arah (*two-way handshake*).

```mermaid
sequenceDiagram
    autonumber
    actor Tenant as Tenant (Mobile App)
    participant EF_Cash as Edge Function (/cash-payment)
    participant DB as PostgreSQL Database
    actor Owner as Owner (Mobile App)
    participant EF_Confirm as Edge Function (/cash-payment-confirm)

    Tenant->>Tenant: Pilih Metode: [Tunai / Cash]
    Tenant->>EF_Cash: POST /cash-payment {invoice_id}
    EF_Cash->>DB: INSERT INTO payment_transactions (payment_method: 'cash', status: 'waiting_confirmation')
    EF_Cash->>DB: UPDATE payments SET payment_method = 'cash'
    EF_Cash->>DB: INSERT notifications untuk Owner: 'Konfirmasi Kas Diperlukan'
    EF_Cash-->>Tenant: Return 200 OK {status: 'waiting_confirmation'}
    
    Tenant->>Tenant: Tampilkan Status: 'Menunggu Konfirmasi Pemilik' + Instruksi Serah Terima
    Tenant->>Owner: Menyerahkan uang fisik langsung kepada Pemilik Kos
    
    Owner->>Owner: Buka Menu Pembayaran -> Tab [Menunggu Kas]
    Owner->>Owner: Melihat Card Permintaan Kas (Nama, Kamar, Nominal Rp 1.200.000)
    Owner->>Owner: Tap [Konfirmasi Pembayaran Diterima]
    Owner->>EF_Confirm: POST /cash-payment-confirm {transaction_id}
    Note over EF_Confirm: Validasi Hak Milik Properti (Owner Authorization)
    EF_Confirm->>DB: UPDATE payment_transactions SET status = 'success', paid_at = NOW()
    EF_Confirm->>DB: UPDATE payments SET status = 'paid', amount_paid = amount_due, paid_at = NOW()
    EF_Confirm->>DB: Eksekusi apply_rental_renewal (perpanjang sewa +1 bulan)
    EF_Confirm->>DB: INSERT notifications untuk Tenant: 'Pembayaran Kas Dikonfirmasi'
    EF_Confirm-->>Owner: Return 200 OK
    
    DB-->>Tenant: Realtime Event: Status Tagihan Berubah Menjadi 'Lunas'
    Tenant->>Tenant: Tampilkan Kuitansi Pembayaran Tunai
```

---

## 6. Flow E: Failed Payment Workflow

Alur ketika transaksi ditolak oleh pihak bank penerbit atau gateway (misal saldo tidak mencukupi atau limit kartu terlampaui).

```mermaid
sequenceDiagram
    autonumber
    actor Tenant as Tenant
    participant Gateway as Midtrans
    participant EF_Hook as Edge Function (/payment-webhook)
    participant DB as PostgreSQL Database

    Tenant->>Gateway: Mencoba menyelesaikan pembayaran
    Gateway->>Gateway: Transaksi Ditolak / Gagal (status: 'deny' / 'failure')
    Gateway->>EF_Hook: POST /payment-webhook {order_id, transaction_status: 'deny'}
    EF_Hook->>DB: UPDATE payment_transactions SET status = 'failed'
    EF_Hook->>DB: Pertahankan payments status = 'pending' (Tagihan belum terbayar)
    EF_Hook->>DB: INSERT notifications untuk Tenant: 'Pembayaran Gagal'
    EF_Hook-->>Gateway: Return 200 OK
    
    DB-->>Tenant: Realtime Event: Transaksi Gagal
    Tenant->>Tenant: Tampilkan Layar Error: "Pembayaran gagal diproses oleh bank"
    Tenant->>Tenant: Tampilkan Tombol [Coba Metode Lain]
```

---

## 7. Flow F: Expired Payment Workflow

Alur ketika batas waktu sesi pembayaran habis sebelum tenant mentransfer dana.

```mermaid
sequenceDiagram
    autonumber
    actor Tenant as Tenant
    participant Gateway as Midtrans
    participant EF_Hook as Edge Function (/payment-webhook)
    participant DB as PostgreSQL Database

    Note over Tenant,Gateway: Sesi QRIS (15 menit) atau VA (24 jam) terlampaui
    Gateway->>EF_Hook: POST /payment-webhook {order_id, transaction_status: 'expire'}
    EF_Hook->>DB: UPDATE payment_transactions SET status = 'expired'
    EF_Hook->>DB: Pertahankan payments status = 'pending'
    EF_Hook-->>Gateway: Return 200 OK
    
    DB-->>Tenant: Realtime Event: Sesi Kedaluwarsa
    Tenant->>Tenant: Banner QRIS/VA dinonaktifkan: "Sesi Pembayaran Telah Kedaluwarsa"
    Tenant->>Tenant: Tampilkan Tombol [Buat Pembayaran Baru]
```

---

## 8. Flow G: Retry Payment Workflow

Alur ketika tenant mencoba kembali setelah transaksi sebelumnya gagal atau kedaluwarsa.

```mermaid
sequenceDiagram
    autonumber
    actor Tenant as Tenant (Mobile App)
    participant EF as Edge Function (/create-payment)
    participant DB as PostgreSQL Database
    participant Gateway as Midtrans

    Tenant->>Tenant: Tap Tombol [Coba Lagi / Ganti Metode]
    Tenant->>EF: POST /create-payment {invoice_id, payment_method: 'bank_transfer', bank: 'bni'}
    EF->>DB: Query transaksi aktif untuk invoice_id tersebut
    alt Ada Transaksi Lama yang Berstatus 'pending'
        EF->>DB: UPDATE payment_transactions SET status = 'cancelled' WHERE id = old_tx_id
        EF->>Gateway: Optional: Panggil /v2/{old_order_id}/cancel
    end
    EF->>Gateway: Charge Transaksi Baru (order_id baru: KM-INV123-TX2)
    Gateway-->>EF: Return Detail Transaksi Baru
    EF->>DB: INSERT payment_transactions baru (status: 'pending')
    EF-->>Tenant: Tampilkan Instruksi Bayar Baru
```

---

## 9. Flow H: Duplicate Webhook Handling Workflow

Alur mitigasi ketika payment gateway mengirimkan payload webhook yang sama lebih dari satu kali karena kendala timeout jaringan.

```mermaid
sequenceDiagram
    autonumber
    participant Gateway as Midtrans Webhook Dispatcher
    participant EF_Hook as Edge Function (/payment-webhook)
    participant DB as PostgreSQL Database

    Note over Gateway,EF_Hook: Webhook Pertama Terkirim & Sukses Terproses
    Gateway->>EF_Hook: POST Webhook #1 {order_id: 'TX-1', status: 'settlement'}
    EF_Hook->>DB: Proses Settle & Simpan ke payment_webhook_events
    EF_Hook-->>Gateway: Return 200 OK
    
    Note over Gateway,EF_Hook: Gateway Mengirim Ulang Webhook yang Sama (Network Retry)
    Gateway->>EF_Hook: POST Webhook #2 {order_id: 'TX-1', status: 'settlement'}
    EF_Hook->>EF_Hook: Verifikasi Signature SHA-512 (Valid)
    EF_Hook->>DB: SELECT 1 FROM payment_webhook_events WHERE order_id = 'TX-1' AND transaction_status = 'settlement'
    DB-->>EF_Hook: Record Ditemukan! (Duplicate Event)
    Note over EF_Hook: Abaikan mutasi database untuk mencegah eksekusi ganda
    EF_Hook-->>Gateway: Return 200 OK {status: 'ok', message: 'Event already processed'}
```

---

## 10. Flow I: Out-of-Order Webhook Handling Workflow

Alur mitigasi ketika webhook tiba tidak berurutan (misal event `expire` tiba lebih lambat daripada event `settlement`, atau sebaliknya).

```mermaid
sequenceDiagram
    autonumber
    participant Gateway as Midtrans
    participant EF_Hook as Edge Function (/payment-webhook)
    participant DB as PostgreSQL Database

    Note over Gateway,DB: Kasus: Transaksi lokal sempat ditandai 'expired', namun dana ternyata masuk
    Gateway->>EF_Hook: POST /payment-webhook {order_id: 'TX-1', transaction_status: 'settlement'}
    EF_Hook->>DB: Query transaksi saat ini (status saat ini: 'expired')
    Note over EF_Hook,DB: Kebenaran Finansial Utama: Status 'settlement' memiliki prioritas tertinggi!
    EF_Hook->>DB: Promosikan transaksi: SET status = 'success'
    EF_Hook->>DB: SET payments status = 'paid' & Perpanjang sewa
    EF_Hook-->>Gateway: Return 200 OK
    
    Note over Gateway,DB: Kasus Sebaliknya: Webhook 'expire' tiba setelah transaksi sudah 'success'
    Gateway->>EF_Hook: POST /payment-webhook {order_id: 'TX-1', transaction_status: 'expire'}
    EF_Hook->>DB: Query transaksi (status saat ini: 'success')
    Note over EF_Hook: Tolak menurunkan status transaksi yang sudah 'success'!
    EF_Hook-->>Gateway: Return 200 OK {message: 'Ignored expire on settled transaction'}
```

---

## 11. Flow J: User Closes App During Payment Workflow

Alur ketika pengguna keluar dari aplikasi, baterai habis, atau koneksi terputus saat transaksi sedang berlangsung.

```mermaid
sequenceDiagram
    autonumber
    actor Tenant as Tenant
    participant Mobile as Tenant Flutter App
    participant DB as PostgreSQL Database
    participant Gateway as Midtrans / Bank

    Tenant->>Mobile: Membuka QRIS / VA (Transaksi status: 'pending')
    Tenant->>Mobile: Menutup aplikasi / Switch ke aplikasi Bank untuk transfer
    Note over Mobile: Aplikasi Mobile Offline / Di-terminate oleh OS
    
    Tenant->>Gateway: Menyelesaikan transfer di aplikasi Bank
    Gateway->>DB: Webhook diterima & diproses server-side secara independen
    DB->>DB: Status invoice diubah menjadi 'paid' & sewa diperpanjang
    
    Note over Tenant,Mobile: Beberapa jam kemudian, Tenant membuka kembali KosManage Mobile
    Tenant->>Mobile: Buka Aplikasi KosManage Mobile
    Mobile->>DB: Query getMyPayments() / getActiveBill()
    DB-->>Mobile: Return tagihan dengan status 'paid' & riwayat transaksi 'success'
    Mobile->>Mobile: UI secara otomatis merender status LUNAS & Kuitansi (Bukan halaman bayar)
```
