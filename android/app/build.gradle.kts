<<<<<<< HEAD
plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
=======
import java.util.Properties

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

val flutterRoot = localProperties.getProperty("flutter.sdk") ?: ""
val flutterVersionCode = localProperties.getProperty("flutter.versionCode") ?: "1"
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

plugins {
    id("com.android.application")
    id("kotlin-android")
>>>>>>> 5f33b952f513e202af05fcbe9a2199b5687e0803
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.caixa_pdv"
<<<<<<< HEAD
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
=======
    compileSdk = 34
>>>>>>> 5f33b952f513e202af05fcbe9a2199b5687e0803

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
<<<<<<< HEAD
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.caixa_pdv"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
=======
        applicationId = "com.example.caixa_pdv"
        minSdk = 21
        targetSdk = 34
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
>>>>>>> 5f33b952f513e202af05fcbe9a2199b5687e0803
    }

    buildTypes {
        release {
<<<<<<< HEAD
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
=======
>>>>>>> 5f33b952f513e202af05fcbe9a2199b5687e0803
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

<<<<<<< HEAD
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

=======
>>>>>>> 5f33b952f513e202af05fcbe9a2199b5687e0803
flutter {
    source = "../.."
}
