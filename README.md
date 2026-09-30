# KosManage Mobile

Flutter mobile client untuk KosManage dengan Supabase yang sama dengan aplikasi web/desktop.

## Foundation

Repository ini sekarang memiliki:

- PRD mobile
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

Untuk target Android, lanjutkan setup Android SDK/Android Studio lalu:

    flutter doctor --android-licenses

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

## Architecture

Lihat:

- PRD.md
- ARCHITECTURE.md

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
