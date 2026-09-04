# Play Store upload keystore + release AAB build

## Context

The release buildType in `android/app/build.gradle.kts` was still wired to
`signingConfigs.getByName("debug")` — a `TODO(release)` comment left over
from the completed `publication-prep.md` plan, with the explicit note that
Play rejects debug-signed uploads. The blocker was acknowledged in three
places: the build.gradle.kts TODO, the completed publication-prep plan's
"Decisions taken" section, and `docs/sologallery_store_listings.md` line
167 ("Play blocker").

This plan landed the missing piece: a real upload keystore, a wired
`signingConfigs` block that falls back to debug only when
`android/key.properties` is absent, and a verified release AAB.

## Decisions

- **Locally generated upload keystore (PKCS12, JBR-built).** The
  Play App Signing path was investigated mid-task and rejected because
  Play Console's "Download upload key" wasn't immediately accessible
  from this session; the user opted for a locally generated key and
  chose to enable Play App Signing later in the Console for the
  recovery-safety benefit.
- **PKCS12, not JKS.** The JBR's `keytool` silently ignores
  `-storetype JKS` (its `engineLoad` stack shows `PKCS12KeyStore`
  regardless). `pkcs12` is what the JBR actually creates; AGP's
  signing config accepts both.
- **`storeFile=upload-keystore.jks` (bare filename), not
  `app/upload-keystore.jks`.** The Gradle DSL's `file(...)` call inside
  `signingConfigs` resolves relative to the **app module's** working
  directory (`android/app/`), not the root project. The original
  `rootProject.file("key.properties")` was right for *finding* the
  properties file (from `android/`); the `storeFile` value must be
  relative to `android/app/`.
- **Conditional fallback to debug signing** in the `release` buildType.
  Lets `flutter run --release` keep working on-device when
  `key.properties` is later deleted; a release AAB built without the
  file is debug-signed and would be caught by the verification step.

## Edits

**`android/app/build.gradle.kts`** — three changes:

1. Imports at the top of the file:
   ```kotlin
   import java.util.Properties
   import java.io.FileInputStream
   ```

2. New `Properties` + `signingConfigs` block between `testOptions` and
   `buildTypes` (signingConfigs must be declared before they're
   referenced):
   ```kotlin
   val keystoreProperties = Properties()
   val keystorePropertiesFile = rootProject.file("key.properties")
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(FileInputStream(keystorePropertiesFile))
   }

   signingConfigs {
       create("release") {
           if (keystorePropertiesFile.exists()) {
               storeFile = file(keystoreProperties["storeFile"] as String)
               storePassword = keystoreProperties["storePassword"] as String
               keyAlias = keystoreProperties["keyAlias"] as String
               keyPassword = keystoreProperties["keyPassword"] as String
           }
       }
   }
   ```

3. `release` buildType `signingConfig` line flipped to a conditional
   ternary; the TODO comment is replaced with a pointer to this plan:
   ```kotlin
   signingConfig = if (keystorePropertiesFile.exists()) {
       signingConfigs.getByName("release")
   } else {
       signingConfigs.getByName("debug")
   }
   ```

**`android/key.properties`** (new, gitignored) — four fields:

```properties
storePassword=<see your password manager>
keyPassword=<see your password manager>
keyAlias=upload
storeFile=upload-keystore.jks
```

**`android/app/upload-keystore.jks`** (new, gitignored) — 2760 bytes,
PKCS12, 2048-bit RSA, 25-year validity (`-validity 10950`), alias
`upload`. Generated with:

```sh
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export DYLD_LIBRARY_PATH="$JAVA_HOME/lib"
$JAVA_HOME/bin/keytool -genkey -v \
  -storetype pkcs12 \
  -keystore upload-keystore.jks \
  -alias upload \
  -keyalg RSA -keysize 2048 \
  -sigalg SHA256withRSA \
  -validity 10950 \
  -dname "CN=Zach Meulenberg, OU=SoloGallery, O=Zach Meulenberg, L=Berlin, ST=Berlin, C=DE"
```

**`docs/gotchas.md`** — new "Release / Play signing" section appended
with three bullets (Play App Signing recovery, `keytool` 90-day default,
JBR `DYLD_LIBRARY_PATH` requirement).

## Verification

- `git check-ignore -v android/key.properties android/app/upload-keystore.jks`
  reports matching rules (`key.properties` line 12, `**/*.jks` line 14
  of `android/.gitignore`). Both files are out of git.
- `flutter build appbundle --release` produces
  `build/app/outputs/bundle/release/app-release.aab` (130.8 MB, built
  in 6.4 s with warm gradle cache).
- AAB signature verification:
  ```
  $ unzip -p build/app/outputs/bundle/release/app-release.aab META-INF/UPLOAD.RSA \
      | DYLD_LIBRARY_PATH=.../jbr/Contents/Home/lib .../jbr/Contents/Home/bin/keytool -printcert
  Owner: CN=Zach Meulenberg, OU=SoloGallery, O=Zach Meulenberg, L=Berlin, ST=Berlin, C=DE
  Valid from: Mon Jul 27 19:12:19 EEST 2026 until: Wed Jul 19 19:12:19 EEST 2056
  SHA1:   E8:0F:33:3A:4B:55:BF:2F:9E:06:CF:03:16:17:A8:A7:91:6D:A5:E6
  SHA256: 8E:03:B1:1D:D0:A2:F9:C7:91:BF:48:38:A0:50:1C:32:40:05:CA:C5:3B:6D:6C:02:61:5D:22:88:50:AA:78:4F
  ```
  The Owner matches the `keytool -dname` argument exactly; validity is
  25 years out; not the debug cert (`CN=Android Debug`). The
  `META-INF/UPLOAD.RSA` filename (not `BNDLTOOL.RSA` as the standard
  Flutter signing template assumes) reflects the keystore's alias
  name.

## Key material

- **Keystore file**: `android/app/upload-keystore.jks` (PKCS12, 2760 bytes)
- **Keystore alias**: `upload`
- **Upload-key SHA-256** (paste into Play Console → Setup → App signing
  if you enable App Signing there):
  `8E:03:B1:1D:D0:A2:F9:C7:91:BF:48:38:A0:50:1C:32:40:05:CA:C5:3B:6D:6C:02:61:5D:22:88:50:AA:78:4F`
- **Keystore SHA-1**: `E8:0F:33:3A:4B:55:BF:2F:9E:06:CF:03:16:17:A8:A7:91:6D:A5:E6`
- **Offline backup location(s)**: user-managed (password manager,
  encrypted USB, etc.). Without a backup, a lost keystore means the
  app identity on Play is unrecoverable. This is the single biggest
  risk in the whole release process.

## Next step

Upload the AAB via Play Console → your app → Release → Production →
Create new release (or Internal testing first if you want a smoke
before going live). Play will check the upload-key SHA-256 against
the one registered on Setup → App signing; if you haven't enabled
App Signing yet, this upload will create the upload-key record
automatically and Google will offer App Signing enrollment afterward
(recommended — see the gotcha entry).

If you regenerate `upload-keystore.jks` later (e.g. to rotate the
upload key after enabling Play App Signing), update this doc's SHA-256
so the next upload can be diffed against the previous one.
