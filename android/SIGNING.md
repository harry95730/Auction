# Android release signing (Play Store)

Google Play rejects bundles signed with the **debug** keystore. Release builds must use an **upload keystore** you create once.

## What belongs in Git vs secrets

| Safe to commit | Never commit |
|----------------|--------------|
| `gradle.properties` (heap, AndroidX, Gradle tuning — **no passwords**) | `key.properties`, `*.jks`, `*.keystore` |
| `app/build.gradle.kts`, `settings.gradle.kts`, manifests | `local.properties` (SDK paths on your machine) |

CI signing uses **GitHub Actions secrets** (`ANDROID_KEYSTORE_BASE64`, passwords, alias) — not checked-in files.

### All builds on GitHub (no Android Studio on your PC)

You do **not** need Android Studio or a local Android SDK to **produce the release `.aab`**. The workflow **Flutter Android Build** on GitHub:

- Installs **Java 17**, **Flutter**, accepts **Android licenses**, runs **`flutter build appbundle --release`** on `ubuntu-latest`.
- **Trigger:** push to branch `build`, or **Actions** → **Flutter Android Build** → **Run workflow** (`workflow_dispatch`).
- **Download:** completed run → **Artifacts** → `app-release` → `app-release.aab` → upload to Play Console.

You still must add the **four repository secrets** (upload keystore + passwords). The keystore file is created **once**, without Studio — see **§1a** below.

### Git: always `git add` from the **repository root**

If your shell is in `android/`, paths must **not** repeat `android/`:

```bash
# Wrong (from android/):  git add android/gradle.properties  → looks for android/android/...
# Right (from android/):
git add gradle.properties app/build.gradle.kts settings.gradle.kts
# Right (from repo root):
git add android/gradle.properties android/app/build.gradle.kts android/settings.gradle.kts
```

## 1. Create the upload keystore (once)

`keytool` is part of a **JDK** (not Android Studio). Use **§1a** if you have no IDE.

### 1a. Without Android Studio (pick one)

**A — GitHub Codespaces (browser; no local disk for Studio)**  
Repo → **Code** → **Codespaces** → **Create codespace**. In the terminal:

```bash
sudo apt-get update && sudo apt-get install -y openjdk-17-jdk
cd android
keytool -genkey -v -keystore upload-keystore.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload \
  -dname "CN=Auction, OU=App, O=NA, L=NA, ST=NA, C=US"
# Same password when prompted for key + store, or set explicitly with -storepass / -keypass (then remember them for GitHub secrets)
base64 -w0 upload-keystore.jks
```

Copy the **one-line** base64 → GitHub secret **`ANDROID_KEYSTORE_BASE64`**. Add password secrets + **`ANDROID_KEY_ALIAS`** (`upload`). Do **not** commit `upload-keystore.jks`.

**B — macOS: small JDK only** — `brew install openjdk@17`, then run **`keytool`** from Homebrew’s path (see `brew info openjdk@17`).

**C — Docker** — `eclipse-temurin:17-jdk` image, mount `android/`, run `keytool` as in **A**.

### 1b. Interactive `keytool` (any machine with a JDK)

```bash
cd android
keytool -genkey -v -keystore upload-keystore.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Answer **at least one** DN field (or use **`-dname`** as in §1a). Remember **store password**, **key password**, and **alias** — same values go into **GitHub secrets** (`ANDROID_STORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`).

## 2. Local `key.properties` (skip if you only use GitHub Actions)

**GitHub-only:** you can skip this — the workflow generates `key.properties` on the runner from secrets.

If you **do** run `flutter build` on your computer:

```bash
cp android/key.properties.example android/key.properties
# Edit: passwords, alias, storeFile=upload-keystore.jks
```

Put `upload-keystore.jks` in **`android/`**. Then:

```bash
flutter build appbundle --release
```

## 3. First upload to Play Console

Use **Play App Signing** (recommended). On first upload, Google uses your upload key; keep the keystore and backups safe—losing it complicates updates.

## 4. GitHub Actions (CI)

If the workflow fails with **`Set GitHub Actions secrets: ANDROID_KEYSTORE_BASE64...`**, those secrets are **missing or empty** for **this repository**. Add all four below (names must match **exactly**, case-sensitive).

### 4a. Where to click in GitHub

1. Open your repo on GitHub (e.g. `harry95730/Auction`).
2. **Settings** → **Secrets and variables** → **Actions**.
3. **Repository secrets** → **New repository secret** (add **four** separate secrets).

### 4b. Secrets to create

| Name | What to paste |
|------|----------------|
| `ANDROID_KEYSTORE_BASE64` | Full **single-line** base64 of `upload-keystore.jks` (see command below). No quotes in the value. |
| `ANDROID_STORE_PASSWORD` | Keystore password you chose in `keytool`. |
| `ANDROID_KEY_PASSWORD` | Key password (often same as store password). |
| `ANDROID_KEY_ALIAS` | The `-alias` you used (e.g. `upload`). |

**Forks:** Secrets do **not** copy from the upstream repo—you must add them on **your** fork.

### 4c. Generate `ANDROID_KEYSTORE_BASE64` (macOS)

From the project root, with `android/upload-keystore.jks` present:

```bash
base64 -i android/upload-keystore.jks | tr -d '\n' | pbcopy
```

Paste into Clipboard → GitHub secret **ANDROID_KEYSTORE_BASE64** → Save.  
**Linux:** `base64 -w0 android/upload-keystore.jks` (copy the whole line).

### 4d. After saving

Push to `build` again (or **Actions** → **Flutter Android Build** → **Re-run jobs**). The **Configure Android release signing** step should pass.

The workflow writes `android/key.properties` and `android/upload-keystore.jks` on the runner before `flutter build appbundle` (those files are **not** stored in git).

## Still seeing “signed in debug mode” on Play?

1. **Upload the new `.aab`** — Play keeps old versions; confirm you’re uploading the artifact from the latest CI run or a fresh local `flutter build appbundle --release`.
2. **Local builds** — You must have **`android/key.properties`** + **`android/upload-keystore.jks`** (not only CI). Without them, Gradle still signs **debug**.
3. **GitHub secret `ANDROID_KEYSTORE_BASE64`** — Must be **one line** of base64 (no line breaks). On macOS: `base64 -i upload-keystore.jks | tr -d '\n' | pbcopy`. Wrong encoding → corrupt `.jks` → signing can fall back or fail.
4. **Passwords / alias** — Must match the keystore (`keytool -list -keystore ... -alias <alias>`).
5. **CI logs** — Open the **“Verify release signing config”** step: it should show **`Config: release`** for **`Variant: release`**, not **`Config: debug`**.
