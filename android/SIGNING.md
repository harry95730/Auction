# Android release signing (Play Store)

Google Play rejects bundles signed with the **debug** keystore. Release builds must use an **upload keystore** you create once.

## What belongs in Git vs secrets

| Safe to commit | Never commit |
|----------------|--------------|
| `gradle.properties` (heap, AndroidX, Gradle tuning — **no passwords**) | `key.properties`, `*.jks`, `*.keystore` |
| `app/build.gradle.kts`, `settings.gradle.kts`, manifests | `local.properties` (SDK paths on your machine) |

CI signing uses **GitHub Actions secrets** (`ANDROID_KEYSTORE_BASE64`, passwords, alias) — not checked-in files.

### Git: always `git add` from the **repository root**

If your shell is in `android/`, paths must **not** repeat `android/`:

```bash
# Wrong (from android/):  git add android/gradle.properties  → looks for android/android/...
# Right (from android/):
git add gradle.properties app/build.gradle.kts settings.gradle.kts
# Right (from repo root):
git add android/gradle.properties android/app/build.gradle.kts android/settings.gradle.kts
```

## 1. Create the keystore (once)

From the project root:

```bash
cd android
keytool -genkey -v -keystore upload-keystore.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

- Remember the **store password**, **key password**, and **alias** (`upload` in the example—you can change it, but stay consistent in `key.properties` and GitHub secrets).
- Keep `upload-keystore.jks` **private**; it is listed in `.gitignore`.

## 2. Local `key.properties`

```bash
cp key.properties.example key.properties
# Edit key.properties with your passwords and alias; storeFile=upload-keystore.jks
```

Put `upload-keystore.jks` in the **`android/`** directory (same level as `key.properties`).

Then:

```bash
flutter build appbundle --release
```

## 3. First upload to Play Console

Use **Play App Signing** (recommended). On first upload, Google uses your upload key; keep the keystore and backups safe—losing it complicates updates.

## 4. GitHub Actions (CI)

Add these **repository secrets** (Settings → Secrets and variables → Actions):

| Secret | Value |
|--------|--------|
| `ANDROID_KEYSTORE_BASE64` | Base64 of `upload-keystore.jks` (see below) |
| `ANDROID_STORE_PASSWORD` | Keystore store password |
| `ANDROID_KEY_PASSWORD` | Key password |
| `ANDROID_KEY_ALIAS` | e.g. `upload` |

Encode the keystore (run locally, paste output into the secret):

```bash
base64 -i android/upload-keystore.jks | pbcopy   # macOS: copies to clipboard
# Linux: base64 -w0 android/upload-keystore.jks
```

The workflow writes `android/key.properties` and `android/upload-keystore.jks` before `flutter build appbundle`.

## Still seeing “signed in debug mode” on Play?

1. **Upload the new `.aab`** — Play keeps old versions; confirm you’re uploading the artifact from the latest CI run or a fresh local `flutter build appbundle --release`.
2. **Local builds** — You must have **`android/key.properties`** + **`android/upload-keystore.jks`** (not only CI). Without them, Gradle still signs **debug**.
3. **GitHub secret `ANDROID_KEYSTORE_BASE64`** — Must be **one line** of base64 (no line breaks). On macOS: `base64 -i upload-keystore.jks | tr -d '\n' | pbcopy`. Wrong encoding → corrupt `.jks` → signing can fall back or fail.
4. **Passwords / alias** — Must match the keystore (`keytool -list -keystore ... -alias <alias>`).
5. **CI logs** — Open the **“Verify release signing config”** step: it should show **`Config: release`** for **`Variant: release`**, not **`Config: debug`**.
