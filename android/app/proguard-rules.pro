# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.firebase.** { *; }

# Mobile Scanner & ML Kit
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-keep class dev.steenbakker.mobile_scanner.** { *; }

# Play Core (Flutter references these for deferred components)
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.gms.internal.**

# Suppress warnings
-dontwarn com.google.mlkit.**
-dontwarn dev.steenbakker.mobile_scanner.**
