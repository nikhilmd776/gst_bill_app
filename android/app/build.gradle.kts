plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.gst_bill_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.gst_bill_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion  // Reduced from flutter default to support more devices while keeping modern APIs
        targetSdk = 33  // Optimized target SDK
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Optimize for size
        multiDexEnabled = false  // Disable multidex for smaller apps
    }

    buildTypes {
        release {
            // Disable R8 minification to avoid ProGuard issues
            isMinifyEnabled = false
            isShrinkResources = false

            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
        debug {
            // Keep debug builds clean without shrinking to avoid issues
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Remove any unnecessary dependencies to reduce size
    // Core Flutter dependencies are handled by the Flutter Gradle Plugin
}
