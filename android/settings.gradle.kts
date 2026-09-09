pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // AGP 9 removed getDefaultProguardFile("proguard-android.txt"), which
    // flutter_inappwebview_android still calls, so the Android build fails
    // while evaluating that plugin before any of this project is compiled. The
    // 6.2 line of that plugin fixes it and breaks the macOS build instead, in
    // every prerelease so far. Raise this back the moment 6.2.0 ships stable
    // with a macOS implementation that compiles.
    id("com.android.application") version "8.13.0" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")
