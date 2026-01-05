# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.kts.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile

# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class com.example.gst_bill_app.** { *; }

# Play Store split install (deferred components) - keep all classes
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# Keep data classes for serialization
-keep class com.example.gst_bill_app.models.** { *; }
-keep class com.example.gst_bill_app.services.** { *; }

# SQLite database
-keep class org.sqlite.** { *; }
-keep class org.sqlite.database.** { *; }

# PDF generation
-keep class com.itextpdf.** { *; }
-keep class org.bouncycastle.** { *; }

# File operations
-keep class androidx.core.content.FileProvider { *; }

# Shared preferences
-keep class android.content.SharedPreferences { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep custom exceptions
-keep public class * extends java.lang.Exception

# Keep annotations
-keepattributes *Annotation*

# Keep source file names for debugging (optional - remove for maximum size reduction)
-keepattributes SourceFile,LineNumberTable