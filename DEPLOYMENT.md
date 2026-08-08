# Deployment Guide - Quincaillerie Pro OS

## 1. Supabase Cloud Configuration

1. Log in to [Supabase Dashboard](https://app.supabase.com) and create a new project.
2. Go to **SQL Editor** -> New Query.
3. Copy and run the entire script from [supabase_rls.sql](file:///c:/Users/mossa/Downloads/quincaillerie_app/quincaillerie_app/supabase_rls.sql).
   > ⚠️ **IMPORTANT**: `supabase_schema.sql` has been renamed to `supabase_schema.legacy.sql` — do NOT deploy it. It contains insecure policies (`USING (true)`).
4. Copy your project **URL** and **Anon Key** from `Project Settings > API`.
5. In `lib/core/app_config.dart`, credentials are read from `--dart-define` flags automatically. Pass them at build/run time:
   ```
   flutter run \
     --dart-define=SUPABASE_URL=https://YOUR_ACTUAL_PROJECT.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=YOUR_ACTUAL_ANON_KEY
   ```
   For release builds:
   ```
   flutter build apk --release \
     --dart-define=SUPABASE_URL=https://YOUR_ACTUAL_PROJECT.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=YOUR_ACTUAL_ANON_KEY
   ```
   If no `--dart-define` is provided, fallback development credentials are used and a warning is logged in debug mode.

---

## 2. Building Production Release Packages

### Android APK / Bundle:
```bash
flutter build apk --release
```
Target location: `build/app/outputs/flutter-apk/app-release.apk`

### Windows Desktop:
```bash
flutter build windows --release
```
Target location: `build/windows/x64/runner/Release/`