# Development Guide

## Local environment

The repository targets Flutter 3.47.5 / Dart 3.13+.

On Windows:

    flutter doctor
    flutter create --platforms=android,ios,web .

The command above generates native platform folders using your installed Flutter SDK.

## Configuration

Use compile-time defines:

    flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-public-key

or:

    flutter run --dart-define-from-file=tool/env/local.json

tool/env/local.json is local-only and must not be committed.

## Checks

    dart format --output=none --set-exit-if-changed .
    flutter analyze
    flutter test

## Auth model

The identity chain is:

    auth.users
        ↓
    profiles.id
        ↓
    profiles.role

The profiles.role value must currently be owner or tenant.

Routing decides which UI shell is shown, but authorization is enforced by Supabase RLS, not by hidden navigation.

## Security

Never commit:

- service-role/secret key
- database password
- access tokens
- personal access tokens

The publishable/anon key is intended for client-side use, while row access remains controlled by RLS.

## Testing

Behavior should be added test-first. Pure logic belongs in unit tests; reusable screen behavior belongs in widget tests; Supabase and real-device flows should be covered by integration/security tests when those modules are implemented.
