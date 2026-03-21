# ipl_app

A Flutter project.

---

## Android release signing (do this first for a signed APK / App Bundle)

Play Store and production installs require a **release-signed** artifact. The **first setup step** is creating an upload keystore and wiring it through `key.properties`. Gradle then uses the signing config in `android/app/build.gradle.kts` (see excerpts below).

### 1. Generate the keystore (one-time)

Run `keytool` (comes with a JDK). Example using a file in your home directory:

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Follow the prompts (or add `-storepass` / `-keypass` if you use non-interactive scripts). Remember the **store password**, **key password**, and **alias** (`upload` in this example).

Then place the keystore where this project expects it:

- Copy `~/upload-keystore.jks` to **`android/app/upload-keystore.jks`** (or generate directly into that path).

**Do not commit** `*.jks` or `key.properties` — they are listed in `android/.gitignore`.

### 2. `key.properties` (next to the Android Gradle root)

Create **`android/key.properties`** (you can start from `android/key.properties.example`). Example:

```properties
storePassword=your-store-password
keyPassword=your-key-password
keyAlias=upload
storeFile=upload-keystore.jks
```

`storeFile` is relative to the **`android/app/`** module, so `upload-keystore.jks` means the file **`android/app/upload-keystore.jks`**.

### 3. Gradle snippets (`android/app/build.gradle.kts`)

**Kotlin JVM target (Java 17 alignment):**

```kotlin
    kotlinOptions {
        jvmTarget = "17"
    }
```

**Release signing:** loads passwords and keystore path from `key.properties` when that file exists.

```kotlin
    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
```

### 4. Build a signed release locally

```bash
flutter build apk --release          # signed APK
# or
flutter build appbundle --release    # signed .aab for Play Store
```

More detail and CI options: **`android/SIGNING.md`**.

---

## GitHub Actions workflow (`build` branch)

The workflow **Flutter Android Build** (`.github/workflows/flutter-build.yml`) runs on **push** to branch **`build`**. Steps:

1. **Checkout repository** — `actions/checkout@v4`
2. **Setup Flutter** — stable channel (`subosito/flutter-action@v2`)
3. **Install dependencies** — `flutter pub get`
4. **Build Android App Bundle** — `flutter build appbundle`
5. **Upload artifact** — `app-release` → `build/app/outputs/bundle/release/app-release.aab`

To get a **Play-ready signed `.aab` from CI**, you must supply signing on the runner (e.g. decode a keystore from GitHub Actions secrets and generate `android/key.properties` before the build) — see **`android/SIGNING.md`**. The default workflow builds without repo-injected secrets; use local `key.properties` + `android/app/upload-keystore.jks` for fully configured release signing on your machine.
