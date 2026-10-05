#!/bin/bash
#
# Builds MeditateAndNoteCore for Android and drops the result where Gradle
# expects it.
#
# Verified end-to-end on a Samsung SM-A245F (Android 16, API 36, arm64-v8a).
# Every non-obvious step below was found by breaking it on the device first;
# the comment says which failure it prevents.
#
# Usage:
#   Scripts/build-android.sh            # build + strip + copy into jniLibs
#   Scripts/build-android.sh --jextract # also regenerate the Java/Swift bindings
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE="$ROOT/Packages/MeditateAndNoteCore"
JNI_LIBS="$ROOT/Android/app/src/main/jniLibs/arm64-v8a"

# --- Toolchain -------------------------------------------------------------
# Every path is overridable: none of this is guaranteed to exist on another
# machine, and a hard-coded path that silently points at the wrong SDK is worse
# than a loud failure.
SWIFT_TOOLCHAIN="${SWIFT_TOOLCHAIN:-$HOME/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain}"
TOOLCHAINS_ID="${TOOLCHAINS_ID:-org.swift.640202609131a}"
ANDROID_SDK_BUNDLE="${ANDROID_SDK_BUNDLE:-$HOME/.swiftpm/swift-sdks/swift-6.4.0-RELEASE_android.artifactbundle/swift-android}"
SWIFT_JAVA="${SWIFT_JAVA:-/var/folders/w6/2dmd6vhj6m94x06bc_s035k00000gn/T/opencode/swifttest/sjpull/swift-java/.build/arm64-apple-macosx/release/swift-java}"
TARGET_TRIPLE="aarch64-unknown-linux-android28"

# libc++_shared.so is NOT part of the Swift toolchain; it ships with the NDK.
# --static-swift-stdlib links the Swift runtime but leaves libCore.so with a
# NEEDED entry for libc++_shared.so, so omitting it makes every Android launch
# die with: dlopen failed: library "libc++_shared.so" not found.
ANDROID_NDK="${ANDROID_NDK:-$HOME/Library/Android/sdk/ndk/27.2.12479018}"
CXX_SHARED="$ANDROID_NDK/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so"

die() { echo "error: $*" >&2; exit 1; }

[ -d "$SWIFT_TOOLCHAIN" ] || die "swift toolchain not found: $SWIFT_TOOLCHAIN (set SWIFT_TOOLCHAIN)"
[ -d "$ANDROID_SDK_BUNDLE" ] || die "android swift-sdk not found: $ANDROID_SDK_BUNDLE (set ANDROID_SDK_BUNDLE)"
[ -f "$CXX_SHARED" ] || die "libc++_shared.so not found: $CXX_SHARED (set ANDROID_NDK)"

OBJ_COPY="$SWIFT_TOOLCHAIN/usr/bin/llvm-objcopy"
[ -x "$OBJ_COPY" ] || die "llvm-objcopy missing: $OBJ_COPY"
# Note: the NDK's llvm-strip is a broken symlink to a missing llvm-objcopy.
# Use the Swift toolchain's llvm-objcopy instead of the NDK's llvm-strip.

SCRATCH="$CORE/.build-android"
# SwiftPM only emits a loadable .so for a product declared `type: .dynamic`,
# so we build MeditateAndNoteCoreDynamic, not the default static
# MeditateAndNoteCore (which comes out as .a and is what Xcode links).
PRODUCT="$SCRATCH/out/Products/Release-android-aarch64/libMeditateAndNoteCoreDynamic.so"

echo "==> Building MeditateAndNoteCore for $TARGET_TRIPLE"
(
  cd "$CORE"
  # SwiftPM aborts with "No Android NDK is installed at any of the standard
  # locations" unless ANDROID_NDK points at an NDK it can validate. Validation
  # needs source.properties plus meta/abis.json and meta/platforms.json; an NDK
  # missing any of them is silently filtered out of the candidate list.
  ANDROID_NDK="$ANDROID_NDK" \
  TOOLCHAINS="$TOOLCHAINS_ID" swift build \
    --swift-sdk "$ANDROID_SDK_BUNDLE/swift-sdk.json" \
    --swift-sdk "$TARGET_TRIPLE" \
    --static-swift-stdlib \
    --product MeditateAndNoteCoreDynamic \
    -c release \
    --scratch-path "$SCRATCH"
)
[ -f "$PRODUCT" ] || die "expected product missing: $PRODUCT"

echo "==> Stripping"
# 78.3 MB -> 56.1 MB (-28%). .symtab + .strtab + .debug_* were 21.1 MB of pure
# shipping waste; JNI entry points live in .dynsym, so they survive.
STRIPPED="$SCRATCH/libMeditateAndNoteCore.stripped.so"
"$OBJ_COPY" --strip-all "$PRODUCT" "$STRIPPED"
printf '    %s -> %s bytes\n' \
  "$(wc -c <"$PRODUCT" | tr -d ' ')" "$(wc -c <"$STRIPPED" | tr -d ' ')"

mkdir -p "$JNI_LIBS"
cp "$STRIPPED" "$JNI_LIBS/libMeditateAndNoteCore.so"
cp "$CXX_SHARED" "$JNI_LIBS/libc++_shared.so"
echo "==> Copied into $JNI_LIBS"
ls -la "$JNI_LIBS"

if [ "${1:-}" = "--jextract" ]; then
  [ -x "$SWIFT_JAVA" ] || die "swift-java not found: $SWIFT_JAVA (set SWIFT_JAVA)"
  OUT="$CORE/.generated"
  rm -rf "$OUT" && mkdir -p "$OUT/java" "$OUT/swift"
  echo "==> Running jextract (JNI mode) into $OUT"
  (
    cd "$CORE"
    "$SWIFT_JAVA" jextract \
      --mode jni \
      --swift-module MeditateAndNoteCore \
      --java-package com.mn.core \
      --input-swift Sources/MeditateAndNoteCore \
      --output-swift "$OUT/swift" \
      --output-java "$OUT/java"
  )
  echo "    java:  $(find "$OUT/java" -name '*.java' | wc -l | tr -d ' ') files"
  echo "    swift: $(find "$OUT/swift" -name '*.swift' | wc -l | tr -d ' ') files"
fi

echo "==> done"