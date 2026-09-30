# PRD — KosManage Mobile (Flutter)

**Product:** KosManage Mobile  
**Platform:** Android & iOS  
**Technology:** Flutter + Dart  
**Backend:** Supabase Auth + PostgreSQL + Storage  
**Document status:** Proposed  
**Target release:** Mobile MVP / v3.0  
**Language:** Bahasa Indonesia for user-facing UI

---

## 1. Ringkasan Produk

KosManage Mobile adalah aplikasi manajemen kos berbasis Flutter untuk owner/pengelola kos kecil hingga menengah dan tenant. Aplikasi memindahkan kemampuan inti KosManage saat ini dari web/desktop ke pengalaman mobile yang lebih cepat, sederhana, dan nyaman digunakan melalui layar sentuh.

Aplikasi mobile menggunakan **Supabase sebagai single source of truth** untuk autentikasi, data operasional, RLS, integritas database, dan penyimpanan foto laporan maintenance.

Versi mobile tidak membuat backend baru. Data yang sudah ada pada Supabase tetap menjadi dasar aplikasi sehingga web/desktop dan mobile dapat menggunakan data yang sama selama keduanya tetap dipelihara.

### Nilai utama

Owner dapat menjawab tiga pertanyaan inti dengan cepat:

1. Kamar mana yang kosong?
2. Siapa yang tinggal di setiap kamar?
3. Siapa yang sudah atau belum membayar?

Tenant dapat melihat kondisi kamar, masa sewa, tagihan, riwayat, dan membuat laporan maintenance dari ponsel.

---

# 2. Problem Statement

Pengelolaan kos skala kecil-menengah sering masih mengandalkan WhatsApp, spreadsheet, catatan manual, dan ingatan pemilik. Masalah yang muncul:

- status kamar sulit dipantau ketika sedang berada di luar rumah/kos
- data penghuni tersebar
- tunggakan mudah terlewat
- riwayat pembayaran sulit ditemukan
- laporan kerusakan harus dicari melalui chat
- owner membutuhkan akses informasi tanpa harus membuka laptop

KosManage Mobile menyatukan informasi tersebut dalam satu aplikasi yang dioptimalkan untuk perangkat sentuh.

---

# 3. Vision

Menjadi aplikasi mobile sederhana untuk mengelola operasional kos sehari-hari tanpa kompleksitas software enterprise.

Produk harus terasa:

- sederhana
- cepat
- mudah dipelajari
- aman
- nyaman digunakan satu tangan
- informatif tanpa memenuhi layar dengan terlalu banyak elemen

---

# 4. Goals

## 4.1 Product Goals

1. Memindahkan seluruh alur inti KosManage ke mobile.
2. Menjadikan Dashboard sebagai pusat informasi harian.
3. Mengoptimalkan UI untuk layar smartphone.
4. Mempertahankan business rules dan RLS dari database.
5. Mendukung Owner dan Tenant dalam satu aplikasi dengan navigasi berbasis role.
6. Mendukung mode terang dan mode gelap.
7. Memungkinkan tenant membuat laporan maintenance dengan foto.
8. Menjaga alur CRUD tetap sederhana dan touch-friendly.

## 4.2 UX Goals

- Tugas utama dapat dilakukan dengan sedikit langkah.
- Informasi penting terbaca tanpa tabel desktop.
- CTA utama mudah dijangkau ibu jari.
- Form tidak terasa panjang atau rumit.
- Empty, loading, dan error state konsisten.
- Status selalu menggunakan teks + ikon/badge, bukan warna saja.

---

# 5. Non-Goals

Tidak termasuk Mobile MVP:

- payment gateway nyata
- QRIS otomatis/real payment processing
- WhatsApp API
- email notification engine
- booking online
- kontrak digital
- manajemen utilitas kompleks
- multi-property switcher penuh
- staff management / role staff
- offline-first penuh
- sinkronisasi dua arah dengan database lokal
- AI assistant
- analytics enterprise
- marketplace kos

Cache lokal terbatas untuk peningkatan UX boleh ditambahkan, tetapi sinkronisasi offline penuh bukan bagian MVP.

---

# 6. Target Users

## 6.1 Owner / Pengelola

Contoh:

**Budi — Owner kos 20 kamar**

- mengelola kos sendiri
- terbiasa menggunakan WhatsApp dan spreadsheet
- sering melakukan pengecekan dari smartphone
- ingin mengetahui kamar kosong dan tunggakan dengan cepat

Kebutuhan:

- Dashboard ringkas
- daftar kamar
- penghuni
- pembayaran
- laporan
- pengaturan
- akses data saat sedang berada di luar lokasi kos

## 6.2 Tenant / Penghuni

Contoh:

**Sari — Penghuni kos**

- menggunakan smartphone sebagai perangkat utama
- ingin mengetahui jatuh tempo dan status pembayaran
- ingin melihat informasi kamar dan masa sewa
- ingin melaporkan kerusakan tanpa harus menghubungi owner secara manual

Kebutuhan:

- dashboard pribadi
- detail kamar
- masa sewa
- tagihan
- riwayat
- laporan maintenance
- profil

---

# 7. Product Scope

## 7.1 Owner

Owner mobile memiliki modul:

1. Login
2. Dashboard
3. Kamar
4. Penghuni
5. Pembayaran
6. Laporan
7. Laporan Keuangan
8. Pengaturan
9. Logout

## 7.2 Tenant

Tenant mobile memiliki modul:

1. Login
2. Dashboard
3. Kamar Saya
4. Pembayaran
5. Laporan Saya
6. Riwayat
7. Profil
8. Logout

Role hanya menentukan pengalaman/navigasi. **Authorization tetap dilakukan oleh Supabase RLS**, bukan hanya dengan menyembunyikan menu.

---

# 8. Navigation

## 8.1 Owner Mobile Navigation

Gunakan bottom navigation untuk modul yang paling sering digunakan:

- Dashboard
- Kamar
- Penghuni
- Pembayaran
- Laporan

Modul sekunder:

- Laporan Keuangan
- Pengaturan

Modul sekunder dapat diakses melalui halaman "Lainnya" atau menu pengaturan tanpa memenuhi bottom navigation.

## 8.2 Tenant Mobile Navigation

Bottom navigation:

- Dashboard
- Kamar Saya
- Pembayaran
- Laporan
- Riwayat

Profil dapat diakses dari avatar/menu account di AppBar atau dari halaman Pengaturan/akun.

## 8.3 Deep Navigation

Gunakan navigation stack untuk:

- Dashboard → Detail pembayaran
- Dashboard → Detail kamar
- Kamar → Detail kamar
- Penghuni → Detail penghuni
- Penghuni → Riwayat pembayaran
- Pembayaran → Detail pembayaran
- Laporan → Detail laporan
- Profil → Edit profil

---

# 9. Authentication

## FR-MOB-001 — Login

User dapat login menggunakan:

- Email
- Password

Backend menggunakan Supabase Auth.

Acceptance criteria:

- kredensial valid menghasilkan session
- user diarahkan ke home sesuai role
- invalid credentials menampilkan pesan ramah
- tidak menampilkan stack trace atau detail internal

## FR-MOB-002 — Session Persistence

Session dipertahankan ketika aplikasi dibuka kembali selama session masih valid.

Acceptance criteria:

- user tidak harus login ulang setiap membuka aplikasi
- session expired → kembali ke login
- logout membersihkan session

## FR-MOB-003 — Role Routing

Setelah login:

- owner → Owner Dashboard
- tenant → Tenant Dashboard

Role berasal dari profile aplikasi dan authorization tetap diverifikasi oleh RLS.

## FR-MOB-004 — Demo Account

Pada build demo/development tersedia aksi:

**Gunakan Akun Demo**

Aksi mengisi kredensial demo secara otomatis.

Kredensial demo hanya boleh tersedia pada environment/build yang memang ditujukan untuk demo. Kredensial tidak boleh dijadikan secret production.

---

# 10. Owner Dashboard

## FR-MOB-010

Dashboard owner menampilkan ringkasan:

- Total Kamar
- Kamar Terisi
- Kamar Kosong
- Kamar Maintenance
- Total Penghuni
- Pendapatan Bulan Ini
- Total Tunggakan

## FR-MOB-011

Dashboard menampilkan:

- pembayaran terbaru
- pembayaran yang mendekati jatuh tempo
- tunggakan
- maintenance aktif
- kontrak sewa yang mendekati berakhir

## UX

Gunakan:

- KPI cards compact
- horizontal list untuk item penting
- tap card untuk membuka detail
- pull-to-refresh
- skeleton loading
- empty state

Jangan menggunakan tabel desktop pada layar smartphone.

---

# 11. Room Management

## FR-MOB-020 — Room List

Owner dapat:

- melihat semua kamar
- mencari berdasarkan nomor kamar
- filter berdasarkan status
- sort berdasarkan nomor/harga/status

Status:

- Available
- Occupied
- Maintenance

Tampilan utama menggunakan **list/card**, bukan tabel.

## FR-MOB-021 — Room Detail

Detail kamar menampilkan:

- nomor kamar
- lantai
- harga
- status
- fasilitas
- catatan
- penghuni aktif

## FR-MOB-022 — Create Room

Field:

- nomor kamar
- lantai
- harga
- status
- fasilitas
- catatan

Fasilitas ditampilkan sebagai checkbox/chip yang mudah disentuh.

## FR-MOB-023 — Edit/Delete Room

Owner dapat mengubah kamar dan menghapus kamar apabila business rule mengizinkan.

Business rules:

- nomor kamar unik dalam property
- kamar occupied tidak dapat dihapus
- kamar maintenance tidak dapat dipilih tenant baru
- database adalah source of truth

---

# 12. Tenant Management

## FR-MOB-030 — Tenant List

Owner dapat:

- melihat penghuni
- search nama/nomor telepon
- filter active/inactive
- membuka detail

## FR-MOB-031 — Add Tenant

Field utama:

- nama
- nomor telepon
- email
- identitas
- kamar
- tanggal mulai
- tanggal selesai
- harga sewa
- deposit
- catatan

Room picker hanya menampilkan kamar yang tersedia.

## FR-MOB-032 — Tenant Detail

Menampilkan:

- informasi penghuni
- kamar
- masa sewa
- status
- harga sewa
- riwayat pembayaran

## FR-MOB-033 — Archive Tenant

Owner dapat mengubah tenant menjadi inactive.

Saat tenant inactive:

- kamar kembali available apabila tidak ada tenant aktif
- riwayat pembayaran dipertahankan

---

# 13. Payments

## FR-MOB-040 — Payment List

Owner melihat:

- penghuni
- kamar
- periode
- jatuh tempo
- nominal tagihan
- nominal dibayar
- status

Filter:

- periode
- status
- metode pembayaran

## FR-MOB-041 — Add Payment

Input:

- tenant
- periode
- due date
- amount due
- amount paid
- payment method
- payment date
- notes

## FR-MOB-042 — Payment Status

Status authoritative dihitung database:

- unpaid
- partial
- paid
- overdue

Client tidak boleh menjadi source of truth untuk status.

## FR-MOB-043 — Tenant Payment

Tenant dapat melihat tagihan miliknya.

Untuk alur simulasi yang sudah ada:

- pilih metode
- klik Bayar Sekarang
- tampilkan dialog simulasi
- label harus eksplisit: **SIMULASI**

Payment gateway nyata tetap di luar scope.

---

# 14. Rental Period

Untuk tenant aktif:

- tanggal mulai
- tanggal berakhir
- jumlah hari tersisa

days_remaining dihitung, bukan disimpan.

Kategori:

| Hari | Tampilan |
|---:|---|
| >30 | Normal |
| 15–30 | Perhatian |
| 7–14 | Segera berakhir |
| 1–6 | Sangat dekat |
| 0 | Berakhir |
| <0 | Lewat masa sewa |

Perhitungan menggunakan kalender Asia/Jakarta.

---

# 15. Maintenance Reports

## FR-MOB-050 — Tenant Create Report

Tenant dapat membuat laporan:

- judul
- deskripsi
- kategori
- prioritas
- foto

Kategori:

- AC
- Electrical
- Plumbing
- Furniture
- Internet
- Other

Prioritas:

- Low
- Medium
- High

## FR-MOB-051 — Report Lifecycle

Status:

submitted → in_progress → resolved → closed

Tenant tidak dapat menentukan status resolved atau closed.

Owner dapat memproses laporan sesuai lifecycle.

## FR-MOB-052 — Photo

Tenant dapat mengambil atau memilih foto dari perangkat.

Aturan:

- private Storage bucket
- MIME terbatas
- batas ukuran sesuai security baseline
- signed URL untuk display
- path object tidak boleh berisi traversal

Foto bukan public asset.

---

# 16. Reports

## FR-MOB-060 — Operational Reports

Menampilkan:

- occupancy
- room distribution
- tenant distribution
- maintenance overview
- expiry overview

Filter berdasarkan periode bila relevan.

## FR-MOB-061 — Financial Reports

Menampilkan:

- total tagihan
- total pembayaran
- outstanding
- ringkasan per periode

Tampilan mobile menggunakan:

- summary cards
- period selector
- list
- simple visualization hanya bila benar-benar membantu

Tidak membuat chart dekoratif tanpa nilai informasi.

---

# 17. Settings

## FR-MOB-070

Pengaturan owner:

- nama kos
- alamat
- mode tampilan
- informasi akun
- logout

## FR-MOB-071 — Dark Mode

User dapat memilih:

- Mode terang
- Mode gelap

Preferensi disimpan lokal pada perangkat.

Tema harus mencakup:

- background
- cards
- app bars
- navigation
- forms
- dialogs
- dropdowns
- status components

Kontras teks dan komponen harus tetap dapat dibaca dalam kedua mode.

---

# 18. Tenant Profile

## FR-MOB-080

Tenant dapat mengubah:

- nama
- nomor telepon

Email login hanya ditampilkan dan dikelola oleh Supabase Auth.

---

# 19. Mobile UX Principles

## 19.1 Touch First

- target tap nyaman untuk jari
- tombol utama mudah dijangkau
- jarak antar control cukup
- swipe/scroll digunakan hanya ketika natural

## 19.2 No Desktop Tables

Tabel desktop diganti dengan:

- Card
- ListTile-like rows
- grouped list
- bottom sheet
- detail screen

## 19.3 App Bar

Mobile menggunakan AppBar yang:

- tetap terlihat pada halaman penting
- memiliki judul yang jelas
- dapat berisi back button
- dapat berisi action utama
- tidak mengambil terlalu banyak tinggi layar

## 19.4 Bottom Sheet

Gunakan bottom sheet untuk:

- filter
- sort
- quick actions
- pilihan metode pembayaran
- confirmation sederhana

## 19.5 FAB

Floating Action Button digunakan hanya ketika aksi create adalah aksi utama halaman, misalnya:

- Tambah Kamar
- Tambah Penghuni
- Tambah Pembayaran
- Buat Laporan

Jangan menggunakan FAB pada setiap halaman.

---

# 20. Design System

Visual mengikuti prinsip KosManage yang sudah ada:

- minimal
- modern
- clean
- professional
- calm
- readable

Status tidak boleh dibedakan menggunakan warna saja.

Gunakan kombinasi:

**ikon + label + warna/badge**

Contoh:

- ✓ Lunas
- ! Sebagian
- ⚠ Terlambat

### Typography

Gunakan font sistem/platform atau Inter bila secara visual diperlukan.

### Liquid Glass

Liquid Glass dapat dipertahankan sebagai arah visual, tetapi harus lebih ringan pada mobile agar:

- performa tetap baik
- teks tetap terbaca
- backdrop blur tidak berlebihan
- komponen tidak terlihat seperti dekorasi

Glass effect bukan requirement untuk setiap component.

---

# 21. Responsive Device Targets

Prioritas perangkat:

### Primary

- smartphone Android
- layar sekitar 6–7 inci
- portrait sebagai default

### Reference device

Xiaomi 15T Pro digunakan sebagai salah satu reference device QA.

Target layout:

- portrait
- landscape sebagai secondary
- small Android phones
- large Android phones
- iPhone ukuran kecil hingga besar

Aplikasi tidak boleh bergantung pada resolusi fisik tertentu.

Layout harus menggunakan logical pixels dan responsive constraints Flutter.

---

# 22. Flutter Technical Direction

## Frontend

- Flutter
- Dart
- Material 3 sebagai base component system
- custom theme KosManage

## Backend

- Supabase Auth
- Supabase PostgreSQL
- Supabase Storage

## State Management

Gunakan state management yang:

- predictable
- testable
- ringan
- mendukung async server state

**Recommended direction:** Riverpod.

Keputusan final dapat dikunci pada architecture phase.

## Navigation

Gunakan declarative routing dengan dukungan:

- auth guard
- role guard
- deep links
- nested navigation

**Recommended direction:** GoRouter.

## Local Storage

Gunakan local storage hanya untuk:

- theme preference
- non-sensitive UI preferences
- session/cache yang diperlukan library resmi

Jangan menyimpan password.

---

# 23. Backend Compatibility

Mobile menggunakan schema Supabase yang sama dengan aplikasi KosManage saat ini.

Tidak membuat tabel baru hanya karena perubahan platform.

Tetap menggunakan schema inti:

auth.users → profiles → properties → rooms / tenants / payments / maintenance_reports

Business rules tetap berada di database:

- room occupancy
- payment status
- ownership
- tenant isolation
- maintenance lifecycle

Frontend hanya memberi UX validation sebelum request.

---

# 24. Security Requirements

## SEC-MOB-001

Tidak ada service-role key pada aplikasi Flutter.

## SEC-MOB-002

Publishable/anon key boleh digunakan sesuai arsitektur Supabase client, dengan RLS tetap aktif.

## SEC-MOB-003

Password tidak disimpan sendiri oleh aplikasi.

## SEC-MOB-004

Authorization tidak bergantung pada menu hiding atau client-side role check saja.

## SEC-MOB-005

Semua data operasional tetap dilindungi RLS.

## SEC-MOB-006

Tenant hanya dapat membaca/mengubah resource miliknya sesuai policy.

## SEC-MOB-007

Maintenance photo memakai private Storage dan signed URL.

## SEC-MOB-008

Error user-facing tidak menampilkan token, SQL, stack trace, atau credential.

---

# 25. Offline & Connectivity

MVP tidak mendukung offline-first penuh.

Saat koneksi bermasalah:

- tampilkan offline indicator
- jangan menghapus data lokal pengguna
- tampilkan retry
- jangan berpura-pura request berhasil
- operasi tulis membutuhkan koneksi

Future scope:

- cached dashboard
- cached room list
- queued mutations
- conflict resolution
- offline synchronization

---

# 26. Loading / Empty / Error State

Semua screen wajib memiliki:

### Loading

Skeleton atau progress indicator ringan.

### Empty

Contoh:

> Belum ada kamar  
> Tambahkan kamar pertama Anda.

### Error

Contoh:

> Gagal memuat data kamar.  
> Coba lagi.

Tersedia CTA **Coba Lagi** pada error yang dapat dipulihkan.

---

# 27. Accessibility

Target:

- readable text
- semantic labels
- focus order
- screen reader support
- touch target memadai
- icon-only button memiliki semantic label
- kontras yang cukup
- jangan menggunakan warna saja sebagai status

Text scaling Flutter harus diuji agar layout tidak rusak pada ukuran font besar.

---

# 28. Performance Requirements

Target MVP:

- startup screen tampil cepat
- scrolling list tetap smooth
- tidak melakukan query besar tanpa pagination/filter ketika data meningkat
- image maintenance dikompresi/ditangani secara efisien
- hindari rebuild widget yang tidak perlu
- dashboard tidak melakukan query berulang tanpa kebutuhan

Untuk list besar:

- gunakan pagination/infinite scroll bila diperlukan
- gunakan lazy building
- batasi jumlah item dashboard

---

# 29. Data Integrity Rules

Semua aturan berikut tetap berlaku:

1. nomor kamar unik dalam property
2. satu kamar hanya memiliki satu tenant aktif
3. kamar maintenance tidak dapat diberikan tenant baru
4. tenant aktif wajib memiliki kamar
5. tenant inactive tetap memiliki history
6. payment terkait tenant/property valid
7. amount payment tidak boleh negatif
8. status payment dihitung database
9. owner hanya dapat mengakses property miliknya
10. tenant tidak boleh melihat tenant lain
11. room occupancy dipelihara trigger/database rule
12. maintenance report mengikuti lifecycle yang ditentukan

---

# 30. Success Metrics

Mobile MVP dianggap berhasil ketika:

1. Owner dapat mengetahui kondisi kos dari Dashboard tanpa membuka laptop.
2. Owner dapat menambah kamar dalam satu alur tanpa error.
3. Owner dapat menambah tenant ke kamar available.
4. Owner dapat mencatat payment dalam satu alur.
5. Tenant dapat melihat tagihan sendiri.
6. Tenant dapat membuat maintenance report dengan foto.
7. Tidak ada cross-owner data exposure.
8. UI tetap usable pada smartphone kecil hingga besar.
9. Dark mode bekerja konsisten.
10. Session login bertahan sesuai mekanisme Supabase.

### Target UX

- Dashboard → informasi utama dapat dipahami dalam <10 detik.
- Create room → maksimal alur singkat tanpa halaman yang tidak perlu.
- Create payment → maksimal satu form utama + confirmation.
- Tenant report → submit dalam beberapa langkah yang jelas.

---

# 31. Acceptance Criteria MVP

## Authentication

- [ ] login email/password
- [ ] session persistence
- [ ] logout
- [ ] auth guard
- [ ] role routing
- [ ] demo account untuk build demo

## Owner

- [ ] dashboard
- [ ] room CRUD
- [ ] tenant CRUD/archive
- [ ] payment CRUD
- [ ] operational reports
- [ ] financial reports
- [ ] settings
- [ ] dark mode

## Tenant

- [ ] dashboard
- [ ] own room
- [ ] own payment
- [ ] payment simulation
- [ ] maintenance report
- [ ] maintenance photo
- [ ] history
- [ ] profile

## Security

- [ ] RLS tetap aktif
- [ ] tenant isolation
- [ ] owner isolation
- [ ] no service-role key
- [ ] private storage
- [ ] no password persistence in app code

## Quality

- [ ] unit tests
- [ ] widget tests
- [ ] integration tests untuk alur kritis
- [ ] Android build berhasil
- [ ] iOS build berhasil pada environment macOS
- [ ] QA pada reference device Android
- [ ] no blocking crash pada core flow

---

# 32. Testing Strategy

## Unit Tests

Untuk:

- payment status presentation
- rental countdown presentation
- filtering
- sorting
- validation
- role routing helpers

## Widget Tests

Untuk:

- LoginScreen
- Dashboard
- RoomList
- TenantList
- PaymentForm
- MaintenanceReportForm
- Settings/Dark Mode

## Integration Tests

Minimal:

1. Login → Dashboard
2. Owner → create room
3. Owner → create tenant
4. Owner → create payment
5. Tenant → open own payment
6. Tenant → create maintenance report
7. Logout → Login

## Security Verification

Dengan environment test:

- owner A tidak dapat melihat property owner B
- tenant A tidak dapat melihat tenant B
- tenant tidak dapat mengubah payment amount/status miliknya secara ilegal

---

# 33. Migration from Existing KosManage

Migration diperlakukan sebagai **platform migration**, bukan database rewrite.

### Existing

React Web/Desktop  
↓  
Supabase

### Target Mobile

Flutter Mobile  
↓  
Supabase

Database existing tetap digunakan.

Tahapan:

1. audit current Supabase schema
2. lock business rules
3. buat Flutter project
4. konfigurasi Supabase
5. implement auth
6. implement owner flow
7. implement tenant flow
8. implement mobile UX
9. implement dark theme
10. testing
11. Android QA
12. release

---

# 34. Recommended Development Phases

## Phase 0 — Foundation

- Flutter project
- architecture
- theme
- routing
- Supabase client
- environment handling
- testing setup

## Phase 1 — Authentication

- login
- session
- logout
- role guard
- demo build configuration

## Phase 2 — Owner Core

- dashboard
- rooms
- tenants
- payments

## Phase 3 — Owner Reports

- operational reports
- financial reports
- settings
- dark mode

## Phase 4 — Tenant Core

- tenant dashboard
- room
- payments
- history
- profile

## Phase 5 — Maintenance

- create report
- lifecycle
- photo upload
- owner processing

## Phase 6 — QA & Polish

- responsive behavior
- accessibility
- error handling
- loading/empty states
- performance
- reference device testing

## Phase 7 — Release

- Android release build
- signing
- store preparation
- release notes
- production environment verification

---

# 35. Future Scope

Setelah mobile MVP stabil:

### Notifications

- jatuh tempo pembayaran
- masa sewa mendekati berakhir
- maintenance status updated

### Payment Gateway

- QRIS
- virtual account
- e-wallet
- webhook
- payment reconciliation

### Offline

- local cache
- offline queue
- sync/conflict handling

### Owner Expansion

- multiple properties
- staff account
- permissions
- audit logs

### Tenant Expansion

- announcement
- documents
- digital contract

### Platform

- tablet optimization
- web admin
- push notification
- deep linking

---

# 36. Product Principles

Saat ada konflik requirement, prioritaskan:

1. Security
2. Data integrity
3. Core functionality
4. Usability
5. Performance
6. Maintainability
7. Visual polish
8. Nice-to-have

Prinsip utama:

> **Mobile-first, database-authoritative, simple-by-default.**

---

# 37. Definition of Done

Fitur dianggap selesai apabila:

- UI mobile sesuai design system
- state loading/empty/error tersedia
- validasi client tersedia
- business rule database tetap berlaku
- RLS tidak dilewati
- unit/widget test sesuai kebutuhan tersedia
- integration flow kritis teruji
- tidak ada secret/service-role di aplikasi
- build berhasil
- diuji pada perangkat Android reference
- tidak ada regresi pada fitur inti

---

## 38. Referensi SSOT Existing

PRD ini merupakan adaptasi mobile dari baseline KosManage yang sudah ada.

Dokumen terkait:

- PRD.md
- REQUIREMENTS.md
- ASSUMPTIONS.md
- ARCHITECTURE.md
- DATABASE.md
- SECURITY.md
- UI-UX.md
- DEVELOPMENT.md

Perubahan dari desktop/Tauri ke Flutter bersifat **platform migration**. Supabase tetap menjadi data plane dan database source of truth.
