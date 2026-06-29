pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-gradle-plugin")
    id("com.android.application") version "8.3.2"
    id("kotlin-android") version "1.9.22"
}

include(":app")
