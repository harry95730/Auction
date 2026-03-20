import java.io.FileInputStream
import java.io.InputStreamReader
import java.nio.charset.StandardCharsets
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// key.properties lives next to the keystore under android/ (see android/key.properties.example).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(
        InputStreamReader(FileInputStream(keystorePropertiesFile), StandardCharsets.UTF_8),
    )
}

// GitHub Actions sets CI=true — never ship a debug-signed bundle from CI by accident.
val isCi = System.getenv("CI") == "true"
if (isCi && !hasReleaseKeystore) {
    error(
        "android/key.properties is missing. The configure-signing step must run before " +
            "flutter build (see .github/workflows and android/SIGNING.md).",
    )
}

android {
    namespace = "com.auction.lilly"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.auction.lilly"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")!!.trim()
                keyPassword = keystoreProperties.getProperty("keyPassword")!!.trim()
                storePassword = keystoreProperties.getProperty("storePassword")!!.trim()
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile")!!.trim())
            }
        }
    }

    buildTypes {
        release {
            // Play Console rejects "debug-signed" bundles; release must not be debuggable.
            isDebuggable = false
            signingConfig =
                if (hasReleaseKeystore) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.10.0"))

    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
}
