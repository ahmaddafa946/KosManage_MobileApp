# ARCHITECTURE — KosManage Mobile

**Platform:** Flutter Mobile  
**Backend:** Supabase Auth + PostgreSQL + Storage  
**Targets:** Android & iOS  
**Status:** Proposed / Foundation

## 1. Architecture Goal

KosManage Mobile adalah mobile client untuk produk KosManage yang sudah ada. Flutter menggantikan presentation layer React/Tauri untuk mobile, sedangkan Supabase tetap menjadi cloud data plane dan single source of truth.

~~~text
KosManage Web/Desktop ──┐
                        ├── Supabase
KosManage Mobile ───────┘
~~~

Supabase menyediakan Authentication, PostgreSQL, Row Level Security, Storage, serta database constraints/triggers.

Aplikasi mobile tidak membuat backend kedua atau authorization model kedua.

## 2. Core Principles

1. Supabase authoritative.
2. RLS adalah security boundary.
3. Database constraints/triggers authoritative untuk data integrity.
4. Flutter menangani presentation, interaction, UI state, dan client validation.
5. Service-role/secret key tidak boleh berada di mobile client.
6. Feature-oriented structure.
7. Dependency harus minimal dan punya alasan.
8. Mobile-first; tabel desktop diubah menjadi list/card.
9. Perilaku penting memiliki automated tests.
10. Offline synchronization tidak dibuat sebelum ada requirement yang jelas.

## 3. Application Layers

~~~text
Presentation
    ↓
Feature/Application State
    ↓
Domain Models & Pure Logic
    ↓
Repositories
    ↓
Supabase
~~~

### Presentation

Bertanggung jawab atas screen, widget, form, navigation UI, responsive layout, accessibility, theme, dan loading/empty/error state.

Presentation tidak boleh berisi raw Supabase query.

### Application / Feature State

Bertanggung jawab atas async server state, filter, sorting, form state, refresh, session state, dan role-aware navigation state.

Recommended direction: Riverpod.

### Domain

Bertanggung jawab atas typed model dan pure logic seperti formatter, validation, rental countdown presentation, serta status labels.

Jangan membuat business rule database menjadi source of truth kedua.

### Repositories

Bertanggung jawab atas Supabase query, Storage operation, mapping, dan error translation.

Screen berkomunikasi dengan repository, bukan langsung ke Supabase.

## 4. Project Structure

~~~text
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme/
│       ├── app_theme.dart
│       ├── app_colors.dart
│       └── app_typography.dart
├── core/
│   ├── config/
│   ├── errors/
│   ├── formatters/
│   ├── validators/
│   ├── utils/
│   └── widgets/
├── data/
│   ├── supabase/
│   └── repositories/
├── domain/
│   ├── models/
│   └── services/
├── features/
│   ├── auth/
│   ├── owner/
│   │   ├── dashboard/
│   │   ├── rooms/
│   │   ├── tenants/
│   │   ├── payments/
│   │   ├── reports/
│   │   ├── financial_reports/
│   │   └── settings/
│   └── tenant/
│       ├── dashboard/
│       ├── room/
│       ├── payments/
│       ├── maintenance/
│       ├── history/
│       └── profile/
└── shared/
    ├── widgets/
    ├── states/
    └── extensions/
~~~

Struktur boleh disederhanakan pada feature kecil. Jangan membuat abstraksi kosong hanya untuk terlihat rapi.

## 5. State Management

Recommended: Riverpod.

Provider utama mencakup:

- auth/session
- profile dan role
- current property
- owner dashboard
- rooms
- tenants
- payments
- reports
- financial reports
- maintenance
- theme preference

Rules:

- provider memiliki async server state
- widget hanya mengonsumsi state
- mutation meng-invalidate/refetch state terkait
- hindari satu global state raksasa
- hindari global mutable state yang tidak terkontrol

## 6. Routing

Recommended: GoRouter.

Alur:

~~~text
/login
   ↓
Auth Guard
   ↓
Role Guard
   ├── Owner navigation
   └── Tenant navigation
~~~

Route guard adalah kontrol UX/navigation, bukan security boundary. Supabase RLS tetap wajib melindungi data.

Dukung deep navigation untuk detail screen.

## 7. Authentication

Supabase Auth mengelola:

- email/password
- session
- refresh
- logout

Flutter mengelola:

- login form
- loading/error UI
- auth redirect
- role-aware home

Identity chain:

~~~text
auth.users
    ↓
profiles.id
    ↓
profiles.role
~~~

Sumber email authentication adalah auth.users.email. profiles.email hanya display data.

Akun demo adalah fitur development/demo dan bukan production secret.

## 8. Authorization

Owner:

~~~text
auth.uid()
    ↓
profiles.id
    ↓
properties.owner_id
    ↓
property-scoped resources
~~~

Tenant:

~~~text
auth.uid()
    ↓
profiles.id
    ↓
tenants.profile_id
    ↓
own room / payments / maintenance
~~~

Jangan pernah mengandalkan hidden menu sebagai authorization.

Jangan:

- disable RLS
- menggunakan service-role key
- mempercayai editable user metadata untuk authorization
- membuat privileged endpoint hanya untuk bypass RLS

## 9. Supabase Data Compatibility

Mobile menggunakan schema KosManage yang sudah ada:

- profiles
- properties
- rooms
- tenants
- payments
- facilities
- room_facilities
- maintenance_reports

Storage maintenance:

~~~text
maintenance-reports/
    {property_id}/
        {tenant_id}/
            {report_id}/
                {filename}
~~~

Tidak menambah tabel hanya karena frontend berganti dari React menjadi Flutter.

## 10. Business Rule Boundary

### Database authoritative

- ownership
- RLS
- room occupancy
- one active tenant per room
- valid foreign keys
- payment status
- maintenance lifecycle
- Storage access policy

### Flutter validation

- required fields
- number/date formatting
- local form validation
- UX filtering
- friendly error messages

Jika Flutter berbeda dengan PostgreSQL, PostgreSQL menang.

## 11. Error Handling

Application-level categories:

- AuthenticationError
- AuthorizationError
- ValidationError
- NetworkError
- NotFoundError
- ConflictError
- ServerError
- UnknownError

User-facing messages menggunakan Bahasa Indonesia.

Jangan expose:

- access token
- password
- SQL
- stack trace
- secret key
- raw backend payload

## 12. Theme

Gunakan Material 3 dengan custom KosManage theme.

Themes:

- light
- dark

Theme preference disimpan lokal pada device.

Coverage:

- Scaffold/background
- AppBar
- cards
- navigation
- forms
- dialogs
- menus
- badges
- dividers
- text

Liquid Glass dapat digunakan secara selektif. Hindari blur berlebihan pada mobile.

## 13. Mobile Navigation

### Owner

Primary:

Dashboard, Kamar, Penghuni, Pembayaran, Laporan.

Secondary:

Laporan Keuangan, Pengaturan.

### Tenant

Primary:

Dashboard, Kamar Saya, Pembayaran, Laporan, Riwayat.

Profile tersedia dari account area.

Gunakan nested navigation ketika membantu mempertahankan context.

## 14. Responsive Layout

Gunakan logical pixels dan layout constraints, bukan resolusi fisik perangkat.

Reference QA:

- Xiaomi 15T Pro

Test classes:

- compact phones
- normal phones
- large phones
- portrait
- landscape
- accessibility text scaling

Guidelines:

- hindari fixed-width content
- gunakan SafeArea
- gunakan Expanded/Flexible dengan benar
- gunakan scrolling untuk long content
- hindari overflow
- stack form di layar sempit
- ubah desktop table menjadi card/list
- pastikan bottom navigation tidak menutup scrollable content

## 15. Screen Pattern

~~~text
Scaffold
 ├── AppBar
 ├── Body
 │    ├── Refresh
 │    ├── Loading
 │    ├── Error
 │    ├── Empty
 │    └── Content
 └── NavigationBar
~~~

Create/edit:

~~~text
List
  ↓
CTA / FAB
  ↓
Form
  ↓
Client validation
  ↓
Repository
  ↓
Supabase
  ↓
Refresh affected state
~~~

Full-screen form untuk form panjang. Bottom sheet untuk pilihan/filter singkat.

## 16. Dashboard Data Strategy

Jangan mengambil seluruh dataset hanya untuk membuat dashboard.

Prefer:

- aggregate query
- scoped filter
- bounded recent records
- bounded outstanding records
- bounded expiry/maintenance records

Owner dashboard:

- room summary
- tenant summary
- income
- outstanding
- recent payments
- upcoming payments
- maintenance
- rental expiry

Tenant dashboard:

- tenant name
- room
- rent
- rental countdown
- current/next bill
- maintenance summary

## 17. Lists and Pagination

Untuk data yang terus bertambah:

- lazy list rendering
- server-side filtering bila sesuai
- pagination/infinite scroll bila diperlukan
- bounded dashboard queries

Jangan mengunduh ribuan row ke smartphone hanya untuk filtering lokal.

## 18. Maintenance Photo

Flow:

~~~text
Create report
    ↓
report_id
    ↓
validate photo
    ↓
private Storage upload
    ↓
save object path
    ↓
signed URL for display
~~~

Rules:

- private bucket
- allowed MIME types
- file-size validation
- no service-role key
- signed URL bukan source of truth
- object path harus aman

## 19. Offline and Connectivity

MVP online-first.

Saat network gagal:

- tampilkan network error yang jelas
- pertahankan form input yang belum terkirim bila memungkinkan
- sediakan retry
- jangan menyatakan mutation berhasil sebelum server mengonfirmasi

Offline queue/sync membutuhkan architecture decision terpisah.

## 20. Testing

### Unit tests

- validators
- formatters
- sorting/filtering
- rental countdown
- role helpers
- error mapping

### Widget tests

- login
- dashboard states
- room list/detail
- tenant list/detail
- payment form
- maintenance form
- settings
- dark mode
- navigation

### Integration tests

- login → role home
- owner → room CRUD
- owner → tenant CRUD
- owner → payment CRUD
- tenant → own payment
- tenant → maintenance report + photo
- logout → login

### Security tests

- owner A tidak dapat mengakses owner B
- tenant A tidak dapat mengakses tenant B
- tenant tidak dapat mengubah protected payment fields
- maintenance photo mengikuti ownership policy

## 21. Initial Dependency Direction

Recommended initial packages:

- supabase_flutter
- flutter_riverpod
- go_router
- image_picker
- intl

Versi dipilih dan dipin saat bootstrap.

Dependency tambahan wajib memiliki alasan yang terdokumentasi.

## 22. Environment

Jangan hardcode secret.

Required configuration:

- Supabase URL
- Supabase publishable/anon key

Tidak boleh ada:

- service-role key
- database password
- personal access token

di aplikasi mobile atau Git.

## 23. Build Targets

Android adalah development target utama.

Artifacts:

- debug APK
- release APK
- AAB untuk Play Store

Final iOS build membutuhkan macOS/Xcode.

## 24. Release Environments

Preferred:

development → staging/test → production

Production data tidak digunakan untuk destructive local tests.

Demo data dipisahkan dari real production data.

## 25. Migration Strategy

Current:

~~~text
KosManage Web/Desktop → Supabase
~~~

Target:

~~~text
KosManage Web/Desktop ──┐
                        ├── Supabase
KosManage Mobile ───────┘
~~~

Migration adalah platform migration, bukan database rewrite.

Langkah:

1. create Flutter foundation
2. connect existing Supabase
3. implement authentication
4. implement role routing
5. implement owner modules
6. implement tenant modules
7. implement mobile UX
8. validate RLS
9. device QA
10. release mobile independently

## 26. Foundation Definition of Done

- Flutter project builds
- Android target launches
- Supabase initializes from configuration
- authentication/session works
- owner/tenant routing works
- light/dark theme works
- project structure exists
- unit/widget tests run
- no secrets committed
- static analysis passes
- development instructions exist

## 27. Decisions to Lock During Bootstrap

1. Flutter SDK/channel
2. minimum Android SDK
3. minimum iOS version
4. Riverpod version
5. GoRouter version
6. Supabase package version
7. Android application ID
8. iOS bundle ID
9. environment strategy
10. theme persistence mechanism
11. logging/error reporting approach
