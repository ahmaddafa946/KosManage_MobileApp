# WhatsApp Billing — Setup & Operations

Fitur ini mengirim pesan tagihan pertama setelah disetujui owner, mengirim hingga tiga pengingat terjadwal, dan menyediakan chatbot untuk melihat tagihan serta memilih QRIS, transfer bank, atau tunai. WhatsApp tidak pernah menetapkan tagihan sebagai lunas sendiri.

## Meta WhatsApp Cloud API

1. Siapkan Meta Business Portfolio, WhatsApp Business Account, nomor Cloud API, dan aplikasi Meta.
2. Buat serta dapatkan persetujuan untuk template kategori **utility** bernama seperti yang ditetapkan pada `WHATSAPP_BILLING_TEMPLATE_NAME`. Bahasa default adalah `id`.
3. Isi template harus memiliki empat placeholder body dalam urutan: nama penyewa, nomor tagihan (fallback ke periode tagihan), sisa pembayaran, dan tanggal jatuh tempo.
4. Atur webhook Callback URL ke:
   `https://<project-ref>.supabase.co/functions/v1/whatsapp-webhook`
5. Isi Verify Token sama dengan `WHATSAPP_WEBHOOK_VERIFY_TOKEN`; berlangganan ke event WhatsApp Business Account `messages`. Endpoint melakukan verifikasi GET menggunakan token dan memeriksa header `X-Hub-Signature-256` pada POST berdasarkan raw body dan Meta App Secret.
6. Jangan mengaktifkan pengingat untuk penyewa sebelum persetujuan eksplisit diperoleh. Status opt-in di database default `false`.

## Supabase Edge Function secrets

Konfigurasikan semua secrets di Supabase Dashboard → Edge Functions → Secrets. Jangan menaruh kredensial ini di Flutter atau Git.

- `WHATSAPP_ACCESS_TOKEN`: Meta access token dengan permission messaging untuk Cloud API.
- `WHATSAPP_PHONE_NUMBER_ID`: ID nomor telepon Cloud API, bukan nomor yang ditampilkan.
- `WHATSAPP_API_VERSION`: versi Graph API yang didukung aplikasi Meta, misalnya format `vNN.0`.
- `WHATSAPP_BILLING_TEMPLATE_NAME`: nama template utility yang disetujui.
- `WHATSAPP_TEMPLATE_LANGUAGE`: opsional, default `id`.
- `WHATSAPP_APP_SECRET`: App Secret aplikasi Meta untuk memverifikasi HMAC webhook.
- `WHATSAPP_WEBHOOK_VERIFY_TOKEN`: string acak kuat untuk verifikasi GET subscription.
- `WHATSAPP_REMINDER_CRON_SECRET`: secret acak kuat untuk pemanggilan scheduler tepercaya.

## Deployment & authentication

- Terapkan migration sebelum deploy fungsi.
- Deploy `whatsapp-billing` dengan verifikasi JWT platform **disabled** karena mendukung scheduler dan permintaan owner; fungsi sendiri memverifikasi JWT owner lewat Supabase Auth. Action scheduler mengharuskan `Authorization: Bearer <WHATSAPP_REMINDER_CRON_SECRET>`.
- Deploy `whatsapp-billing-consent` dengan verifikasi JWT platform enabled.
- Deploy `whatsapp-webhook` dengan verifikasi JWT platform disabled karena Meta melakukan verifikasi callback token untuk GET dan HMAC untuk POST. Jangan membuka fungsi melalui jalur lain tanpa verifikasi ini.
- Jalankan scheduler harian hanya setelah semua secret disetel, template disetujui, migrasi diterapkan, persetujuan penyewa tercatat, dan test nomor berhasil.

## Perintah chatbot

Penyewa yang mengirim pesan ke nomor WhatsApp bisnis dapat memakai:

- `TAGIHAN`: menampilkan maksimal 10 tagihan aktif untuk nomor penyewa yang cocok tepat satu dengan profil aktif di KosManage.
- Pilih tagihan lalu pilih **QRIS**, **Transfer bank**, atau **Tunai**. Untuk transfer bank, chatbot meminta pilihan BCA, BNI, BRI, Mandiri, atau Permata.
- `STOP`: mencabut persetujuan pengingat dan menghentikan pengingat yang masih antre. `START` tidak otomatis memberi persetujuan; persetujuan reminder dikelola dari aplikasi.
- Perintah yang tidak dikenal membalas menu bantuan; webhook mengabaikan nomor yang tidak cocok atau cocok dengan lebih dari satu tenant untuk mencegah kebocoran data.

Balasan interaktif hanya diproses dari pesan masuk yang telah diverifikasi lewat signature Meta. ID pesan masuk disimpan dengan constraint unique dan klaim pemrosesan untuk menahan pengiriman balasan duplikat ketika Meta mengulangi webhook. Status pengiriman `sent`, `delivered`, `read`, dan `failed` dicatat pada outbox bila cocok dengan message ID terakhir.

## Payment flow

- **QRIS dinamis:** backend menghitung sisa tagihan dari database, meminta transaksi QRIS kepada Midtrans, lalu mengirim gambar QR yang dikembalikan gateway. Bila gambar tidak dapat dikirim ke WhatsApp, penyewa diminta melihat QR di aplikasi KosManage.
- **Transfer bank:** backend membuat VA melalui Midtrans dan mengirim instruksi transfer.
- **Tunai:** chatbot membuat transaksi `waiting_confirmation` dan notifikasi untuk owner. Status tetap belum lunas sampai owner mengonfirmasi di KosManage.
- Settlement QRIS/VA tetap diproses oleh Edge Function `payment-webhook` yang memverifikasi signature Midtrans. Pesan WhatsApp, balasan penyewa, atau status delivery WhatsApp **tidak** menandai invoice sebagai dibayar.

Sebelum membuat transaksi dari chatbot, backend menyimpan reservation `created` untuk memanfaatkan unique index transaksi aktif. Jika hasil panggilan gateway tidak pasti akibat koneksi terputus, reservation sengaja tetap ada agar retry tidak membuat tagihan kedua. Kasus ini harus direkonsiliasi melalui aplikasi atau pemeriksaan owner; jangan langsung mencoba membuat transaksi kedua.

## Owner approval and reminder schedule

Persetujuan awal owner (pakai JWT owner):

```json
{ "action": "approve-invoice", "invoice_id": "<payments.id>" }
```

Pemanggilan scheduler tepercaya:

```json
{ "action": "run-reminders" }
```

Scheduler mengirim paling banyak tiga reminder yang berhasil, berjarak tiga hari. Claim memakai conditional database update untuk mengurangi duplikasi scheduler paralel. Kegagalan pengiriman/pembacaan dijadwalkan ulang setelah 24 jam, tanpa menaikkan counter reminder berhasil. Klaim scheduler yang macet lebih dari 15 menit dipulihkan. Pesan awal dihitung terpisah dari tiga reminder itu.

Persetujuan tenant (pakai JWT tenant):

```json
{ "opt_in": true }
```

Kirim `false` untuk mencabut persetujuan.

## Checklist sebelum production

- [ ] Review PR dan merge perubahan.
- [ ] Verifikasi migration pada database staging/branch terlebih dahulu. Project saat ini tidak memiliki Supabase development branch; jangan gunakan database produksi sebagai sandbox.
- [ ] Deploy ketiga Edge Function dan periksa konfigurasi `verify_jwt`.
- [ ] Set secrets Meta, verifikasi webhook pada dashboard Meta, dan dapatkan persetujuan template.
- [ ] Uji nomor test untuk TAGIHAN, persetujuan/STOP, QRIS dinamis, VA, permintaan tunai, webhook Midtrans, delivery status, dan retry webhook.
- [ ] Baru setelah pengujian tersebut aktifkan cron pengingat untuk penyewa yang sudah opt-in.

Integrasi ini belum dianggap aktif di produksi sampai migration, deployment, Meta webhook, secret, dan uji end-to-end benar-benar selesai.
