plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.zmeul.sologallery"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.zmeul.sologallery"
        // Android 15+ only (CLAUDE.md Stack → Targets): no compatibility code
        // or permission fallbacks for older releases are written or tested, so
        // the floor is declared rather than inherited. Well above patrol's
        // own minimum of 23.
        minSdk = 35
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // patrol on-device integration tests (integration_test/*).
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
    }

    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
    }

    buildTypes {
        release {
            // TODO(release): replace with a real upload keystore before any
            // Play submission. Signing with the debug key keeps
            // `flutter run --release` and on-device release smokes working,
            // but Play rejects debug-signed uploads. Wire via a gitignored
            // android/key.properties — see docs/plans/publication-prep.md.
            signingConfig = signingConfigs.getByName("debug")
            // Stated explicitly rather than inherited: the Flutter Gradle
            // plugin turns both on by default today, so a plugin change could
            // silently ship an unminified build.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    androidTestUtil("androidx.test:orchestrator:1.5.1")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
