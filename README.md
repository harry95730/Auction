# ipl_app

A Flutter project.

---

## Admin — create & edit matches

Admins use the same login as everyone else. Access is controlled by the Firestore field **`users/{uid}.admin`** (boolean). When `admin` is `true`, a **MATCH MGMT** floating action button appears on the main shell; it opens **Match Management** where you can create fixtures and edit existing matches (stored in the **`matches`** collection). Home/away team pickers load only teams whose Firestore field **`tournament`** is **`IPL`**. A team cannot be selected as both sides (e.g. Mumbai vs Mumbai). Each fixture stores **`odds`** as a **list of two** payout multipliers — `[home, away]` for team 1 and team 2 (e.g. `[2.0, 1.85]`). **Venue** in match management is chosen from distinct **`venue`** (or `home_ground`) values on **IPL** team documents; **`status`** is one of **`OPEN`**, **`LOCKED`**, **`COMPLETED`**. New matches default to **`tournament`: `IPL`**, **`season`: `2026`**, **`result`** omitted until set (UI: Pending / selected home & away team names / Draw). **`bid_range`** is stored as **`[min, max]`** (₹) with **min &lt; max**, chosen in the admin form from **₹100–₹2000** in steps of **₹100**. Payout multipliers in the form are **0.25×** steps from **1.00×** to **15.00×**.

- **Grant admin:** in Firebase Console → Firestore → `users` → your user document → set **`admin`: `true`** (create the field if missing). New users still default to `admin: false` in code.
- **Security:** restrict `matches` writes in **Firestore rules** to authenticated users whose user document has `admin == true`. Client-side checks are not enough on their own.

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
