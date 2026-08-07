# Flutter Wrapper ProGuard rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.internal.** { *; }
-keep class io.flutter.provider.** { *; }

# Workmanager plugin rules
-keep class dev.fluttercommunity.workmanager.** { *; }
-keepclassmembers class * extends dev.fluttercommunity.workmanager.** { *; }

# SQLite & Drift rules
-keep class org.sqlite.** { *; }
-keep class com.sqlite.** { *; }

# Application rules
-keep class com.example.quincaillerie_app.** { *; }
