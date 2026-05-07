# Cookpad FFmpegKit Build

This branch (`cookpad/v6.0-16kb`) carries Cookpad's build of FFmpegKit `full-gpl` binaries with Android 16 KB page-size alignment.

## Why

Google Play enforces 16 KB page-size compatibility from November 2025. The upstream NooruddinLakhani prebuilt AARs were published April 2025 (4 KB ELF alignment). This branch produces binaries with `-Wl,-z,max-page-size=16384` for `arm64-v8a` and `x86-64`, using NDK r27c and AGP 8.5.2+.

## Build environment

| Requirement | Version |
|---|---|
| macOS | 14+ (Apple Silicon) |
| Xcode | 15.4 |
| NDK | r27c (`27.2.12479018`) |
| JDK | 17 (Temurin) |
| Homebrew deps | `autoconf automake libtool pkg-config nasm yasm cmake gas-preprocessor` |

Install NDK:
```
sdkmanager "ndk;27.2.12479018"
```

## Build

```bash
git clone https://github.com/cookpad-research/ffmpeg-kit
cd ffmpeg-kit
git checkout cookpad/v6.0-16kb
./scripts/cookpad-build.sh
```

Artifacts land in `dist/`:
- `ffmpeg-kit-full-gpl.aar` — Android, 16 KB-aligned
- `ffmpeg-kit-ios-full-gpl.zip` — iOS xcframeworks

## Publish release

```bash
TAG=v6.0-cookpad.1   # bump suffix on each rebuild

# Android AAR
gh release create "$TAG" \
  --repo cookpad-research/ffmpeg-kit-full-gpl \
  --title "$TAG (16KB-aligned, NDK r27c)" \
  --notes "Source: cookpad-research/ffmpeg-kit@$(git rev-parse HEAD). NDK r27c (27.2.12479018), full-gpl, arm64-v8a+x86-64 max-page-size=16384." \
  dist/ffmpeg-kit-full-gpl.aar dist/SHA256SUMS

# iOS — replace xcframeworks in the artifact repo and push a new tag
cd /tmp
git clone https://github.com/cookpad-research/ffmpeg-kit-ios-full-gpl
cd ffmpeg-kit-ios-full-gpl
# Replace 6.0-80adc/ contents with newly built xcframeworks from dist/staging
rm -rf ffmpeg-kit-ios-full-gpl/6.0-80adc
mkdir -p ffmpeg-kit-ios-full-gpl/6.0-80adc
# (copy *.xcframework from your ffmpeg-kit/dist/staging/ffmpeg-kit-ios-full-gpl-<tag>/... here)
git add -A
git commit -m "chore: rebuild xcframeworks — NDK r27c compatible source"
git tag "$TAG"
git push origin main "$TAG"
```

## Update moment-mobile

After publishing, update `app.config.js` URLs and the plugin path constant in `ffmpeg-kit-plugin.js`:

```js
// app.config.js
iosUrl: 'https://github.com/cookpad-research/ffmpeg-kit-ios-full-gpl/archive/refs/tags/<TAG>.zip',
androidUrl: 'https://github.com/cookpad-research/ffmpeg-kit-full-gpl/releases/download/<TAG>/ffmpeg-kit-full-gpl.aar',
```

```js
// ffmpeg-kit-plugin.js — vendored_frameworks path prefix
// Change: ffmpeg-kit-ios-full-gpl-<OLD_TAG> → ffmpeg-kit-ios-full-gpl-<NEW_TAG>
```

## Verification

```bash
# 1. Alignment check on arm64-v8a
TMP=$(mktemp -d) && cd $TMP
unzip -p /path/to/ffmpeg-kit-full-gpl.aar jni/arm64-v8a/libffmpegkit.so > libffmpegkit.so
$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/darwin-arm64/bin/llvm-readelf -lW libffmpegkit.so | grep LOAD
# Every LOAD row must show Align 0x4000

# 2. zipalign check on built APK
zipalign -c -P 16 -v 4 app-release.apk

# 3. Runtime ABI check — log from app startup
FFmpegKitConfig.getFFmpegVersion()   // expect "6.x"
FFmpegKitConfig.getVersion()         // expect "6.x.x"
```
