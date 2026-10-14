# KosManage Mobile

Flutter mobile client untuk KosManage dengan Supabase yang sama dengan aplikasi web/desktop.

## Foundation

Repository ini sekarang memiliki:

- PRD mobile
- dokumen knowledge domain pengelolaan rumah kos
- arsitektur feature-oriented
- Flutter application shell
- Material 3 light/dark theme
- Riverpod state management
- GoRouter routing
- Supabase Auth + profile/role routing
- owner dan tenant navigation shell
- konfigurasi Supabase via compile-time defines
- unit + widget test foundation
- GitHub Actions CI
- struktur untuk Android/iOS/web; application ID Android menggunakan prefix provisional `id.kosmanage` saat platform folders digenerate

## Fitur Aplikasi

Daftar berikut merangkum fitur yang sudah tersedia pada kode aplikasi saat ini. Kelengkapan alur tetap perlu divalidasi melalui pengujian di perangkat dan koneksi Supabase.

### Autentikasi dan tampilan umum
- Login menggunakan email dan kata sandi melalui Supabase Auth.
- Pengarahan halaman berdasarkan peran akun: pemilik kos (Owner) atau penghuni (Tenant).
- Pengelolaan sesi dan logout.
- Navigasi mobile menggunakan bottom navigation.
- Tema Material 3 dengan pilihan mode terang, gelap, atau mengikuti sistem.
- Halaman profil dan pengaturan akun.

### Fitur pemilik kos (Owner)
- **Dashboard kos:** ringkasan dan informasi operasional kos.
- **Manajemen kamar:** melihat daftar kamar, mencari dan memfilter kamar, menambah/mengubah data kamar, serta menghapus kamar dengan pemeriksaan penghuni aktif.
- **Manajemen penghuni:** melihat, mencari, memfilter, menambah, mengubah, menonaktifkan/checkout, dan menghapus data penghuni.
- **Pembayaran:** melihat catatan pembayaran, mencari berdasarkan nama penghuni/kamar, memfilter periode/status/metode, serta menambah, mengubah, dan menghapus catatan pembayaran.
- **Laporan operasional:** ringkasan kondisi operasional dan laporan maintenance.
- **Laporan keuangan:** ringkasan tagihan, pembayaran, dan tunggakan sesuai data yang tersedia.
- **Pemrosesan laporan maintenance:** memperbarui status melalui tahapan diajukan, diproses, selesai, dan ditutup.
- **Format dan tampilan data:** komponen antarmuka mobile, indikator loading/error, konfirmasi tindakan penting, serta penyegaran daftar.

### Fitur penghuni kos (Tenant)
- **Beranda penghuni:** ringkasan informasi pribadi terkait kos.
- **Kamar saya:** akses informasi kamar yang terkait dengan akun penghuni.
- **Tagihan dan riwayat pembayaran:** melihat informasi pembayaran milik penghuni serta alur pembayaran simulasi.
- **Bantuan dan laporan:** akses fitur bantuan/laporan maintenance dari area penghuni.
- **Profil dan pengaturan:** melihat profil akun, memilih tema, dan logout.

### Integrasi dan fondasi teknis
- Supabase digunakan sebagai sumber data utama untuk autentikasi dan data aplikasi.
- Repository terpisah untuk akses data kamar, penghuni, pembayaran, laporan, profil, dan dashboard.
- State management menggunakan Riverpod dan navigasi menggunakan GoRouter.
- Konfigurasi URL dan publishable/anon key Supabase melalui compile-time defines.
- Fondasi unit/widget test serta GitHub Actions untuk pemeriksaan dan build.
- Workflow GitHub Actions disiapkan untuk membangun APK Android.

### Batasan yang perlu diketahui
- Pembayaran dari sisi penghuni masih **simulasi**, bukan transaksi QRIS/payment gateway sungguhan.
- Status build APK dan keberhasilan seluruh alur fitur harus dikonfirmasi melalui hasil workflow dan pengujian pada perangkat.
- Fitur yang masih berupa rancangan, placeholder, atau belum lolos pengujian end-to-end tidak dianggap sebagai fitur produksi yang sudah terverifikasi.

## Stack

- Flutter stable 3.47.5
- Dart 3.13+
- supabase_flutter
- flutter_riverpod
- go_router
- image_picker
- intl
- shared_preferences

Versi dependency foundation dipilih berdasarkan versi stabil yang tersedia saat bootstrap. go_router 18.0.2 membutuhkan Dart 3.12+, dan flutter_riverpod 3.4.3 juga menargetkan Dart 3.12+.

## Setup Windows

Install Flutter SDK dan Git terlebih dahulu, lalu pastikan perintah flutter dan dart tersedia di terminal.

Periksa:

    flutter --version
    dart --version
    flutter doctor

Untuk target Android, pastikan Android SDK Command-line Tools (latest), Platform-Tools, dan Build-Tools terpasang melalui Android Studio → SDK Manager. Setelah itu validasi dengan:

    flutter doctor

Buat platform folders dari root repository satu kali:

    flutter create --platforms=android,ios,web --org id.kosmanage .

## Supabase configuration

Jangan commit secret. Mobile hanya membutuhkan URL Supabase dan publishable/anon key.

Cara yang direkomendasikan untuk local development adalah --dart-define-from-file.

Salin:

    tool/env/local.json.example

menjadi:

    tool/env/local.json

lalu isi nilai environment lokal.

Jalankan:

    flutter run -d chrome --dart-define-from-file=tool/env/local.json

atau target Android:

    flutter run -d <device-id> --dart-define-from-file=tool/env/local.json

Source menggunakan String.fromEnvironment sehingga konfigurasi tidak diperlakukan sebagai asset .env. Publishable/anon key adalah credential client-side; service-role/secret key tidak boleh pernah dimasukkan ke aplikasi mobile.

## Tests

    flutter pub get
    dart format --output=none --set-exit-if-changed .
    flutter analyze
    flutter test

## Architecture and Domain

Dokumen pengembangan terkait:

- [Knowledge Domain — Pengelolaan Rumah Kos](docs/KNOWLEDGE-DOMAIN.md)
- [PRD Mobile](PRD.md)
- [Architecture](ARCHITECTURE.md)

Struktur utama:

    lib/
    ├── app/
    ├── core/
    ├── data/
    ├── domain/
    ├── features/
    └── shared/

Screen tidak melakukan raw Supabase query. Query akan masuk melalui repository.

## Development order

Foundation yang sudah disiapkan:

1. App shell
2. Configuration
3. Theme
4. Authentication foundation
5. Role routing
6. Owner/tenant navigation
7. Test foundation

Berikutnya implementasi bertahap mengikuti PRD:

1. Auth penuh
2. Owner dashboard
3. Rooms
4. Tenants
5. Payments
6. Reports
7. Tenant experience
8. Maintenance + photo
9. QA/RLS verification
10. Android release

## Android release

    flutter build apk --release --dart-define-from-file=tool/env/local.json
    flutter build appbundle --release --dart-define-from-file=tool/env/local.json

iOS release membutuhkan macOS/Xcode.

## Notes

Repository ini tetap menggunakan single source of truth Supabase. Mobile tidak membuat database/API backend kedua.


### Download APK dari GitHub

Workflow **Build Android APK** otomatis berjalan saat ada push ke branch `main`, dan dapat dijalankan manual dari tab **Actions**. File APK tersedia di bagian **Artifacts** pada hasil workflow.

Sebelum build pertama, atur konfigurasi repository di **Settings → Secrets and variables → Actions**:
- Tambahkan repository variable `SUPABASE_URL` dengan URL project Supabase.
- Tambahkan repository secret `SUPABASE_ANON_KEY` dengan publishable/anon key Supabase. Jangan gunakan service-role key.

**Cara download APK:**
1. Buka tab **Actions** pada repository.
2. Pilih workflow **Build Android APK** lalu buka run yang berstatus sukses.
3. Di bagian **Artifacts**, download `KosManage-Android-APK` (file ZIP).
4. Ekstrak ZIP untuk memperoleh `KosManage.apk`, lalu buka APK di Android untuk memasangnya. Jika diminta, izinkan pemasangan aplikasi dari sumber tersebut.

Untuk membuat halaman **Releases** berisi APK yang bisa diunduh langsung, buat dan push tag versi, misalnya `v0.1.0`. Jika workflow sukses, APK akan dilampirkan ke GitHub Release. APK dari workflow ini belum ditandatangani dengan kunci rilis pribadi; sebelum distribusi produksi, siapkan signing key Android yang aman.


### Download APK langsung

Setelah workflow build Android berhasil, APK terbaru dapat diunduh langsung melalui tautan permanen berikut:

**[Download KosManage.apk](https://github.com/ahmaddafa946/KosManage_MobileApp/releases/latest/download/KosManage.apk)**

Tautan ini mengarah ke APK pada GitHub Release terbaru. Build otomatis memerlukan repository variable `SUPABASE_URL` dan repository secret `SUPABASE_ANON_KEY` yang sudah diatur di Settings → Secrets and variables → Actions. Jika tautan belum tersedia, jalankan workflow **Build Android APK** dari tab Actions dan pastikan build berhasil.
