# Deployment Guide - Quincaillerie Pro OS

## 1. Supabase Cloud Configuration

1. Log in to [Supabase Dashboard](https://app.supabase.com) and create a new project.
2. Go to **SQL Editor** -> New Query.
3. Copy and run the entire script from [supabase_rls.sql](file:///c:/Users/mossa/Downloads/quincaillerie_app/quincaillerie_app/supabase_rls.sql).
4. Copy your project **URL** and **Anon Key** from `Project Settings > API`.
5. Update `lib/main.dart`:
```dart
await Supabase.initialize(
  url: 'https://YOUR_ACTUAL_PROJECT.supabase.co',
  publishableKey: 'YOUR_ACTUAL_ANON_KEY',
);
```

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
