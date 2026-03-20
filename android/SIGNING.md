# Android release signing (Play Store)

Google Play rejects bundles signed with the **debug** keystore. Release builds must use an **upload keystore** you create once.

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
