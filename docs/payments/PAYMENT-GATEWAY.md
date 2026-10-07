# PAYMENT GATEWAY ABSTRACTION & MIDTRANS INTEGRATION
**KosManage Mobile Platform (Vendor-Agnostic Core API, Midtrans Adapter, and Future Multi-Gateway Architecture)**

- **Module:** Payment Gateway Engine
- **Version:** 1.0.0
- **Status:** Approved Technical Specification
- **Path:** `docs/payments/PAYMENT-GATEWAY.md`

---

## 1. Overview & Vendor-Agnostic Design Pattern

Arsitektur integrasi payment gateway KosManage Mobile dirancang menggunakan prinsip **Dependency Inversion** dan **Adapter Pattern**. Seluruh logika bisnis penagihan, status invoice, dan perpanjangan sewa hanya berkomunikasi dengan antarmuka abstrak `PaymentGatewayProvider`.

### Keuntungan Desain Abstrak:
1. **Tidak Ada Vendor Lock-In:** KosManage dapat dengan mudah berganti penyedia gateway (misal dari Midtrans ke Xendit, Doku, atau Faspay) tanpa perlu mengubah kode UI Flutter atau logika database.
2. **Multi-Gateway Routing (Masa Depan):** Memungkinkan rute transaksi dinamis (misal QRIS menggunakan Provider A karena biaya lebih murah, sedangkan Virtual Account menggunakan Provider B).
3. **Pengujian Mandiri (Mockable):** Pengujian unit dan integrasi dapat menggunakan mock provider tanpa harus memanggil API eksternal sungguhan.

---

## 2. Gateway Core Abstraction Interface

Definisi kontrak antarmuka diimplementasikan pada shared runtime Supabase Edge Functions (`/supabase/functions/_shared/payment-provider.ts`):

```typescript
export interface CreatePaymentParams {
  orderId: string;
  grossAmount: number;
  customerDetails: {
    firstName: string;
    email: string;
    phone?: string;
  };
  itemDetails: Array<{
    id: string;
    price: number;
    quantity: number;
    name: string;
  }>;
  customExpiryMinutes?: number;
}

export interface QrPaymentResult {
  provider: string;
  transactionId: string; // ID transaksi resmi dari vendor gateway
  orderId: string;
  qrString: string;      // Payload EMVCo standar QRIS Nasional
  qrImageUrl?: string;   // URL gambar QR Code
  expiresAt: string;     // ISO-8601 Timestamp batas bayar
  rawResponse: Record<string, unknown>;
}

export interface BankTransferResult {
  provider: string;
  transactionId: string;
  orderId: string;
  bank: 'bca' | 'bni' | 'bri' | 'mandiri' | 'permata';
  vaNumber: string;      // Nomor Virtual Account
  expiresAt: string;
  rawResponse: Record<string, unknown>;
}

export interface WebhookVerificationResult {
  isValid: boolean;
  orderId: string;
  transactionId: string;
  transactionStatus: 'settlement' | 'pending' | 'deny' | 'cancel' | 'expire' | 'failure';
  grossAmount: number;
  paymentType: string;
  rawBody: Record<string, unknown>;
}

export interface TransactionStatusResult {
  orderId: string;
  transactionId: string;
  transactionStatus: 'settlement' | 'pending' | 'deny' | 'cancel' | 'expire' | 'failure';
  grossAmount: number;
  paymentType: string;
  settlementTime?: string;
}

export interface PaymentGatewayProvider {
  readonly name: string;
  
  createQrPayment(params: CreatePaymentParams): Promise<QrPaymentResult>;
  
  createBankTransfer(
    params: CreatePaymentParams, 
    bank: 'bca' | 'bni' | 'bri' | 'mandiri' | 'permata'
  ): Promise<BankTransferResult>;
  
  getTransactionStatus(orderId: string): Promise<TransactionStatusResult>;
  
  verifyWebhook(rawBody: Record<string, unknown>, headers: Headers): Promise<WebhookVerificationResult>;
  
  cancelOrExpire(orderId: string): Promise<boolean>;
}
```

---

## 3. Midtrans Implementation Adapter (`MidtransPaymentProvider`)

Provider pertama yang diaktifkan adalah **Midtrans Sandbox** (dan Production).

### 3.1 Konfigurasi Environment & Endpoints
- **Sandbox Base URL:** `https://api.sandbox.midtrans.com/v2`
- **Production Base URL:** `https://api.midtrans.com/v2`
- **Header Otorisasi:** `Authorization: Basic base64(MIDTRANS_SERVER_KEY + ":")`
- **Content-Type:** `application/json`

---

### 3.2 Method: `createQrPayment(params)`
Memanggil Midtrans Core API `/v2/charge` untuk menghasilkan Dynamic QRIS:

#### A. Request Payload ke Midtrans:
```json
{
  "payment_type": "qris",
  "transaction_details": {
    "order_id": "KM-INV9B1DEB-1728345678",
    "gross_amount": 1200000
  },
  "item_details": [
    {
      "id": "ROOM-101",
      "price": 1200000,
      "quantity": 1,
      "name": "Sewa Kos Kamar 101 Periode 2026-11"
    }
  ],
  "customer_details": {
    "first_name": "Ahmad Dafa",
    "email": "dafa@example.com",
    "phone": "081234567890"
  },
  "qris": {
    "acquirer": "gopay"
  },
  "custom_expiry": {
    "expiry_duration": 15,
    "unit": "minute"
  }
}
```

#### B. Response Midtrans & Pemetaan:
Midtrans mengembalikan objek:
```json
{
  "status_code": "201",
  "status_message": "QRIS transaction is created",
  "transaction_id": "4e1a1234-abcd-4ef0-9123-abcdef012345",
  "order_id": "KM-INV9B1DEB-1728345678",
  "gross_amount": "1200000.00",
  "payment_type": "qris",
  "transaction_time": "2026-10-08 00:10:00",
  "transaction_status": "pending",
  "qr_string": "00020101021226680016ID.CO.MIDTRANS.WWW0118936009110022334455...",
  "actions": [
    {
      "name": "generate-qr-code",
      "method": "GET",
      "url": "https://api.sandbox.midtrans.com/v2/qris/4e1a1234-abcd-4ef0-9123-abcdef012345/qr-code"
    }
  ],
  "expiry_time": "2026-10-08 00:25:00"
}
```
Adapter memetakan `qr_string` dan `actions[0].url` ke dalam antarmuka `QrPaymentResult`.

---

### 3.3 Method: `createBankTransfer(params, bank)`
Memanggil Midtrans Core API `/v2/charge` untuk membuat Virtual Account bank.

#### A. Request Payload ke Midtrans:
```json
{
  "payment_type": "bank_transfer",
  "transaction_details": {
    "order_id": "KM-INV9B1DEB-1728345679",
    "gross_amount": 1200000
  },
  "bank_transfer": {
    "bank": "bca"
  },
  "custom_expiry": {
    "expiry_duration": 24,
    "unit": "hour"
  }
}
```

#### B. Response Midtrans:
```json
{
  "status_code": "201",
  "status_message": "Success, Bank Transfer transaction is created",
  "transaction_id": "8f2b5678-cdef-4ab1-8234-bcdefa123456",
  "order_id": "KM-INV9B1DEB-1728345679",
  "gross_amount": "1200000.00",
  "payment_type": "bank_transfer",
  "transaction_status": "pending",
  "va_numbers": [
    {
      "bank": "bca",
      "va_number": "9101212345678901"
    }
  ],
  "expiry_time": "2026-10-09 00:10:00"
}
```
Adapter mengambil `va_numbers[0].va_number` dan mengembalikannya ke `BankTransferResult`. *(Untuk bank Mandiri, Midtrans menggunakan kombinasi `bill_key` dan `biller_code` yang dinormalisasi menjadi format VA seragam).*

---

### 3.4 Method: `verifyWebhook(rawBody, headers)`
1. Mengambil parameter kunci dari `rawBody`:
   - `order_id`
   - `status_code`
   - `gross_amount`
   - `signature_key`
2. Menghitung kalkulasi hash SHA-512 secara lokal di server Edge Function:
   $$\text{Hash} = \text{SHA512}(\text{order\_id} + \text{status\_code} + \text{gross\_amount} + \text{MIDTRANS\_SERVER\_KEY})$$
3. Memverifikasi:
   $$\text{isValid} = (\text{Hash} == \text{signature\_key})$$
4. Menstandarisasi status transaksi:
   - `settlement` atau `capture` (dengan `fraud_status: accept`) $\rightarrow$ `'settlement'`
   - `pending` $\rightarrow$ `'pending'`
   - `deny` $\rightarrow$ `'deny'`
   - `expire` $\rightarrow$ `'expire'`
   - `cancel` $\rightarrow$ `'cancel'`

---

### 3.5 Method: `getTransactionStatus(orderId)`
Pemeriksaan aktif status transaksi ke Midtrans via HTTP `GET /v2/{order_id}/status`. Digunakan sebagai mekanisme cadangan (*fallback reconciliation*) jika webhook mengalami keterlambatan pengiriman.

---

### 3.6 Method: `cancelOrExpire(orderId)`
Membatalkan sesi transaksi aktif di Midtrans via HTTP `POST /v2/{order_id}/cancel`. Digunakan saat tenant berpindah metode pembayaran dari QRIS ke Bank Transfer agar nomor QRIS lama dinonaktifkan di sistem perbankan.

---

## 4. Error Handling & Gateway Retry Strategy

### 4.1 Penanganan Error HTTP Gateway
| Kode Status HTTP | Arti Masalah | Strategi Mitigasi Sistem |
|---|---|---|
| `400 Bad Request` | Payload pesanan tidak valid / format salah | Log error detail dan kembalikan pesan ramah ke klien. |
| `401 Unauthorized` | Server Key salah / expired | Alert kritis ke DevOps / Administrator sistem. |
| `406 Not Acceptable` | Order ID duplikat di Midtrans | Buat suffix order ID baru (misal: `-TX2`) dan ulangi. |
| `500 / 502 / 503 / 504` | Gateway sedang maintenance / overload | **Exponential Backoff Retry** (maksimal 3x: jeda 1s, 2s, 4s). |

---

## 5. Menambahkan Provider Lain di Masa Depan (Extensibility Guide)

Untuk menambahkan provider baru (contoh: **Xendit**):
1. Buat file baru `/supabase/functions/_shared/xendit-provider.ts`.
2. Implementasikan kelas `XenditPaymentProvider implements PaymentGatewayProvider`.
3. Tambahkan switch konfigurasi di factory function:
```typescript
export function getPaymentGateway(providerName = Deno.env.get("ACTIVE_PAYMENT_GATEWAY")): PaymentGatewayProvider {
  switch (providerName) {
    case "xendit":
      return new XenditPaymentProvider();
    case "midtrans":
    default:
      return new MidtransPaymentProvider();
  }
}
```
Tidak ada perubahan yang diperlukan pada tabel database, model Dart Flutter, atau antarmuka pengguna mobile.
