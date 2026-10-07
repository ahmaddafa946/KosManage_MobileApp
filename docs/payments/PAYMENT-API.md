# REST API & SUPABASE EDGE FUNCTIONS CONTRACT SPECIFICATION
**KosManage Mobile Platform (Client-to-Backend Interface, Payload Contracts, and Error Protocols)**

- **Module:** Payment API Contracts
- **Version:** 1.0.0
- **Status:** Approved Technical Specification
- **Path:** `docs/payments/PAYMENT-API.md`

---

## 1. Overview & General API Standards

Dokumen ini mendefinisikan kontrak komunikasi resmi antara aplikasi mobile Flutter dan backend Supabase Edge Functions.

### Standar Protokol Global:
- **Base URL:** `https://<project-ref>.supabase.co/functions/v1`
- **Format Pertukaran Data:** `application/json; charset=utf-8`
- **Autentikasi Klien:** Bearer Token via Header `Authorization: Bearer <user_jwt>`.
- **Standar Respon Sukses:**
  ```json
  {
    "success": true,
    "data": { ... },
    "message": "Deskripsi singkat dalam Bahasa Indonesia"
  }
  ```
- **Standar Respon Error:**
  ```json
  {
    "success": false,
    "error": {
      "code": "ERROR_CODE_STRING",
      "message": "Pesan ramah pengguna dalam Bahasa Indonesia",
      "details": { ... }
    }
  }
  ```

---

## 2. Endpoint 1: `POST /create-payment`

### 2.1 Tujuan (Purpose)
Membuat sesi transaksi digital baru (QRIS Dinamis atau Bank Transfer Virtual Account) untuk melunasi tagihan yang dipilih.

### 2.2 Autentikasi & Otorisasi
- **Autentikasi:** Supabase User JWT (Wajib).
- **Otorisasi:** Hanya Tenant yang terdaftar sebagai penyewa aktif tagihan tersebut (`auth.uid() == tenants.profile_id`).

### 2.3 Request Body
```json
{
  "invoice_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "payment_method": "qris", // atau "bank_transfer"
  "bank": "bca"            // Wajib jika payment_method == "bank_transfer"
}
```

### 2.4 Validasi Request
- `invoice_id`: Wajib format UUID v4 valid.
- `payment_method`: Harus salah satu dari `['qris', 'bank_transfer']`.
- `bank`: Jika method `bank_transfer`, harus salah satu dari `['bca', 'bni', 'bri', 'mandiri', 'permata']`.
- Nominal **TIDAK DITERIMA** dari client. Nominal ditarik langsung dari database: `amount_due - amount_paid`.

### 2.5 Respon Sukses (200 OK - QRIS)
```json
{
  "success": true,
  "data": {
    "transaction_id": "4e1a1234-abcd-4ef0-9123-abcdef012345",
    "order_id": "KM-INV9B1DEB-1728345678",
    "payment_method": "qris",
    "payment_provider": "midtrans",
    "gross_amount": 1200000,
    "qr_string": "00020101021226680016ID.CO.MIDTRANS.WWW0118936009110022334455...",
    "qr_url": "https://api.sandbox.midtrans.com/v2/qris/4e1a1234/qr-code",
    "expires_at": "2026-10-08T00:25:00.000Z"
  },
  "message": "Sesi pembayaran QRIS berhasil dibuat"
}
```

### 2.6 Respon Sukses (200 OK - Bank Transfer VA)
```json
{
  "success": true,
  "data": {
    "transaction_id": "8f2b5678-cdef-4ab1-8234-bcdefa123456",
    "order_id": "KM-INV9B1DEB-1728345679",
    "payment_method": "bank_transfer",
    "payment_provider": "midtrans",
    "gross_amount": 1200000,
    "bank": "bca",
    "va_number": "9101212345678901",
    "expires_at": "2026-10-09T00:10:00.000Z",
    "instructions": [
      "Buka aplikasi BCA Mobile / KlikBCA",
      "Pilih menu Transfer ke BCA Virtual Account",
      "Masukkan nomor 9101212345678901",
      "Periksa nama dan nominal lalu konfirmasi pembayaran"
    ]
  },
  "message": "Nomor Virtual Account berhasil dibuat"
}
```

### 2.7 Respon Error Umum
- `400 Bad Request`: `{"success": false, "error": {"code": "INVALID_PARAMS", "message": "Bank harus dipilih untuk transfer bank"}}`
- `403 Forbidden`: `{"success": false, "error": {"code": "FORBIDDEN", "message": "Anda tidak memiliki akses ke tagihan ini"}}`
- `409 Conflict`: `{"success": false, "error": {"code": "INVOICE_ALREADY_PAID", "message": "Tagihan ini sudah lunas sebelumnya"}}`

### 2.8 Efek Database
- Kunci baris pada `payments` (`SELECT FOR UPDATE`).
- Jika ada transaksi pending lama, statusnya diubah menjadi `cancelled`.
- Insert record baru ke `payment_transactions` dengan status `'pending'` dan `expires_at`.

---

## 3. Endpoint 2: `POST /payment-webhook`

### 3.1 Tujuan (Purpose)
Menerima callback status transaksi dari Midtrans secara asynchronous.

### 3.2 Autentikasi & Otorisasi
- **Autentikasi:** Kriptografis SHA-512 Signature Hash.
- **Otorisasi:** Terbuka untuk IP / Domain server Midtrans.

### 3.3 Request Body (dari Gateway)
```json
{
  "order_id": "KM-INV9B1DEB-1728345678",
  "status_code": "200",
  "gross_amount": "1200000.00",
  "signature_key": "a1b2c3d4e5f67890abcdef...",
  "transaction_status": "settlement",
  "transaction_id": "4e1a1234-abcd-4ef0-9123-abcdef012345",
  "payment_type": "qris",
  "settlement_time": "2026-10-08 00:12:30"
}
```

### 3.4 Validasi & Idempotensi
1. Verifikasi tanda tangan: `SHA512(order_id + status_code + gross_amount + SERVER_KEY) == signature_key`. Jika gagal $\rightarrow$ HTTP 401.
2. Cek apakah kombinasi `(order_id, transaction_status)` sudah tercatat di `payment_webhook_events`. Jika sudah ada $\rightarrow$ Return HTTP 200 (Skip duplicate).

### 3.5 Respon Sukses (200 OK)
```json
{
  "status": "ok",
  "message": "Webhook processed successfully"
}
```

### 3.6 Efek Database
- `payment_transactions`: Status berubah menjadi `'success'`, `paid_at = NOW()`.
- `payments`: Status berubah menjadi `'paid'`, `amount_paid = amount_due`, `paid_at = NOW()`.
- Menjalankan fungsi `public.apply_rental_renewal(payment_id)`.
- Mengisi tabel `payment_webhook_events`.
- Mengirim event notifikasi ke tabel `notifications`.

---

## 4. Endpoint 3: `GET /payment-status`

### 4.1 Tujuan (Purpose)
Memungkinkan aplikasi klien memeriksa status transaksi aktif secara langsung (*pull fallback query*) jika webhook lambat diterima.

### 4.2 Query Parameters & Otorisasi
- **Query:** `?transaction_id=UUID` atau `?order_id=STRING`
- **Autentikasi:** Supabase User JWT.

### 4.3 Respon Sukses (200 OK)
```json
{
  "success": true,
  "data": {
    "transaction_id": "4e1a1234-abcd-4ef0-9123-abcdef012345",
    "order_id": "KM-INV9B1DEB-1728345678",
    "status": "success",
    "invoice_status": "paid",
    "is_settled": true,
    "paid_at": "2026-10-08T00:12:30.000Z"
  }
}
```

---

## 5. Endpoint 4: `POST /cash-payment`

### 5.1 Tujuan (Purpose)
Pengajuan pembayaran tunai (*Cash Intent*) oleh penghuni kepada pemilik kos.

### 5.2 Autentikasi & Request Body
- **Autentikasi:** Supabase User JWT Tenant.
- **Request Body:**
```json
{
  "invoice_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "notes": "Uang tunai dititipkan ke penjaga kos"
}
```

### 5.3 Respon Sukses (200 OK)
```json
{
  "success": true,
  "data": {
    "transaction_id": "991a1234-abcd-4ef0-9123-abcdef012399",
    "status": "waiting_confirmation",
    "payment_method": "cash",
    "instructions": "Silakan lakukan pembayaran tunai kepada pemilik kos. Status tagihan akan lunas setelah dikonfirmasi pemilik."
  },
  "message": "Pengajuan pembayaran tunai berhasil dikirim"
}
```

### 5.4 Efek Database
- Insert ke `payment_transactions` dengan `payment_method = 'cash'`, `status = 'waiting_confirmation'`.
- Insert notifikasi `cash_confirmation_required` untuk Owner.

---

## 6. Endpoint 5: `POST /cash-payment/confirm`

### 6.1 Tujuan (Purpose)
Konfirmasi penerimaan uang tunai fisik oleh pemilik kos (*Owner Approval*).

### 6.2 Autentikasi & Request Body
- **Autentikasi:** Supabase User JWT Owner.
- **Request Body:**
```json
{
  "transaction_id": "991a1234-abcd-4ef0-9123-abcdef012399"
}
```

### 6.3 Otorisasi & Validasi
- Sistem memeriksa bahwa pemanggil adalah pemilik sah dari properti yang menaungi kamar terkait. Jika bukan $\rightarrow$ HTTP 403.
- Memastikan transaksi berstatus `'waiting_confirmation'`.

### 6.4 Respon Sukses (200 OK)
```json
{
  "success": true,
  "data": {
    "transaction_id": "991a1234-abcd-4ef0-9123-abcdef012399",
    "invoice_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
    "status": "success",
    "invoice_status": "paid",
    "rental_extended": true
  },
  "message": "Pembayaran tunai berhasil dikonfirmasi dan masa sewa telah diperpanjang"
}
```

### 6.5 Efek Database
- `payment_transactions`: `status = 'success'`, `paid_at = NOW()`.
- `payments`: `status = 'paid'`, `amount_paid = amount_due`.
- Eksekusi `apply_rental_renewal(payment_id)` (+1 bulan masa sewa).
- Insert notifikasi `cash_payment_confirmed` untuk Tenant.
