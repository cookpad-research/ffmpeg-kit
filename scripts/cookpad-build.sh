#!/usr/bin/env bash
# Reproducible build script for Cookpad's ffmpeg-kit-full-gpl binaries.
# Run from the root of cookpad-research/ffmpeg-kit on branch cookpad/v6.0-16kb.
#
# Requirements:
#   macOS 14+, Apple Silicon (M2/M3+)
#   Xcode 15.4
#   NDK r27+ -- default auto-detects 27.1 (r27b) or 27.2 (r27c), override via ANDROID_NDK_ROOT
#   JDK 17
#   Homebrew: autoconf automake libtool pkg-config nasm yasm cmake gas-preprocessor
#
# Usage:
#   bash scripts/cookpad-build.sh
#   RELEASE_TAG=v6.0-cookpad.2 bash scripts/cookpad-build.sh   # custom tag
#
# Output artifacts:
#   dist/ffmpeg-kit-full-gpl.aar         -- Android AAR (16 KB-aligned)
#   dist/ffmpeg-kit-ios-full-gpl.zip     -- iOS xcframeworks zip
#   dist/SHA256SUMS
#   dist/build-info.txt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASEDIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$BASEDIR/dist"
TAG="${RELEASE_TAG:-v6.0-cookpad.1}"

mkdir -p "$DIST_DIR"

# ---------------------------------------------------------------------------
# Android
# ---------------------------------------------------------------------------

export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"

# Auto-detect NDK r27 (prefer r27c, fall back to r27b, r27a)
if [[ -z "${ANDROID_NDK_ROOT:-}" ]]; then
  for NDK_VER in 27.2.12479018 27.1.12297006 27.0.12077973; do
    CANDIDATE="$ANDROID_SDK_ROOT/ndk/$NDK_VER"
    if [[ -d "$CANDIDATE" ]]; then
      export ANDROID_NDK_ROOT="$CANDIDATE"
      break
    fi
  done
fi

if [[ -z "${ANDROID_NDK_ROOT:-}" ]] || [[ ! -d "$ANDROID_NDK_ROOT" ]]; then
  echo "[error] NDK r27+ not found under $ANDROID_SDK_ROOT/ndk/."
  echo "  Install with: sdkmanager 'ndk;27.1.12297006'"
  exit 1
fi

echo "[build] Android NDK : $ANDROID_NDK_ROOT"
echo "[build] Building Android full-gpl ..."

"$BASEDIR/android.sh" \
  --full-gpl \
  --enable-android-media-codec \
  --enable-android-zlib \
  --enable-x264 \
  --enable-x265 \
  --enable-xvidcore \
  --enable-libvpx \
  --enable-lame \
  --enable-fdk-aac \
  --enable-libass \
  --enable-libiconv \
  --enable-libtheora \
  --enable-libvorbis \
  --enable-opus \
  --enable-shine \
  --enable-snappy \
  --enable-soxr \
  --enable-speex \
  --enable-twolame \
  --enable-vo-amrwbenc \
  --enable-wavpack \
  --api-level=24 \
  --speed

AAR_SRC="$BASEDIR/prebuilt/bundle-android-aar/ffmpeg-kit/ffmpeg-kit.aar"
cp "$AAR_SRC" "$DIST_DIR/ffmpeg-kit-full-gpl.aar"
echo "[ok] Android AAR: $DIST_DIR/ffmpeg-kit-full-gpl.aar"

# ---------------------------------------------------------------------------
# iOS
# ---------------------------------------------------------------------------

echo "[build] Building iOS full-gpl ..."

"$BASEDIR/ios.sh" \
  --full-gpl \
  --enable-ios-audiotoolbox \
  --enable-ios-avfoundation \
  --enable-ios-bzip2 \
  --enable-ios-libiconv \
  --enable-ios-videotoolbox \
  --enable-ios-zlib \
  --enable-x264 \
  --enable-x265 \
  --enable-xvidcore \
  --enable-libvpx \
  --enable-lame \
  --enable-fdk-aac \
  --enable-libass \
  --enable-libtheora \
  --enable-libvorbis \
  --enable-opus \
  --enable-shine \
  --enable-snappy \
  --enable-soxr \
  --enable-speex \
  --enable-twolame \
  --enable-vo-amrwbenc \
  --enable-wavpack \
  --xcframework \
  --speed

XCF_SRC="$BASEDIR/prebuilt/bundle-apple-xcframework-ios"

# Package in the layout ffmpeg-kit-plugin.js expects:
#   ffmpeg-kit-ios-full-gpl-<tag>/ffmpeg-kit-ios-full-gpl/6.0-80adc/<fw>.xcframework
STAGE="$BASEDIR/staging/ffmpeg-kit-ios-full-gpl-$TAG/ffmpeg-kit-ios-full-gpl/6.0-80adc"
mkdir -p "$STAGE"

for fw in ffmpegkit libavcodec libavdevice libavfilter libavformat libavutil libswresample libswscale; do
  cp -R "$XCF_SRC/${fw}.xcframework" "$STAGE/"
done

(cd "$BASEDIR/staging" && zip -r "$DIST_DIR/ffmpeg-kit-ios-full-gpl.zip" "ffmpeg-kit-ios-full-gpl-$TAG")
echo "[ok] iOS zip: $DIST_DIR/ffmpeg-kit-ios-full-gpl.zip"

# ---------------------------------------------------------------------------
# Checksums + build info
# ---------------------------------------------------------------------------

(cd "$DIST_DIR" && shasum -a 256 ffmpeg-kit-full-gpl.aar ffmpeg-kit-ios-full-gpl.zip > SHA256SUMS)

XCODE_VER=$(xcodebuild -version 2>/dev/null | tr '\n' ' ' || echo "unknown")
SOURCE_SHA=$(git -C "$BASEDIR" rev-parse HEAD 2>/dev/null || echo "unknown")
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > "$DIST_DIR/build-info.txt" <<BUILD_INFO
tag: $TAG
ndk: $ANDROID_NDK_ROOT
xcode: $XCODE_VER
source: $SOURCE_SHA
date: $BUILD_DATE
BUILD_INFO

echo ""
echo "[done] Artifacts in $DIST_DIR/"
ls -lh "$DIST_DIR"
