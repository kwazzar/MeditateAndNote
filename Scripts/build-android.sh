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
JNI="$ROOT/Packages/MeditateAndNoteCoreJNI"
JNI_LIBS="$ROOT/Android/app/src/main/jniLibs/arm64-v8a"

# --- Toolchain -------------------------------------------------------------
# Every path is overridable: none of this is guaranteed to exist on another
# machine, and a hard-coded path that silently points at the wrong SDK is worse
# than a loud failure.
SWIFT_TOOLCHAIN="${SWIFT_TOOLCHAIN:-$HOME/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain}"
TOOLCHAINS_ID="${TOOLCHAINS_ID:-org.swift.640202609131a}"
ANDROID_SDK_BUNDLE="${ANDROID_SDK_BUNDLE:-$HOME/.swiftpm/swift-sdks/swift-6.4.0-RELEASE_android.artifactbundle/swift-android}"
SWIFT_JAVA_HOME="${SWIFT_JAVA_HOME:-$HOME/Developer/swift-java}"
SWIFT_JAVA="${SWIFT_JAVA:-$SWIFT_JAVA_HOME/.build/arm64-apple-macosx/release/swift-java}"
TARGET_TRIPLE="aarch64-unknown-linux-android28"

# libc++_shared.so is NOT part of the Swift toolchain; it ships with the NDK.
# --static-swift-stdlib links the Swift runtime but leaves libMeditateAndNoteCore.so
# with a NEEDED entry for libc++_shared.so, so omitting it makes every Android
# launch die with: dlopen failed: library "libc++_shared.so" not found.
#
# The NDK version matters and is not cosmetic. The Swift Android runtime is built
# against r30's libc++ and references std::__ndk1::__hash_memory, which r27c's
# libc++_shared.so does not export. dlopen fails with:
#   cannot locate symbol "_ZNSt6__ndk113__hash_memoryEPKvm"
# which reads like a bug in our library and is not one.
ANDROID_NDK="${ANDROID_NDK:-$HOME/Library/Android/sdk/ndk/30.0.16248370}"
CXX_SHARED="$ANDROID_NDK/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so"

die() { echo "error: $*" >&2; exit 1; }

[ -d "$SWIFT_TOOLCHAIN" ] || die "swift toolchain not found: $SWIFT_TOOLCHAIN (set SWIFT_TOOLCHAIN)"
[ -d "$ANDROID_SDK_BUNDLE" ] || die "android swift-sdk not found: $ANDROID_SDK_BUNDLE (set ANDROID_SDK_BUNDLE)"
[ -f "$CXX_SHARED" ] || die "libc++_shared.so not found: $CXX_SHARED (set ANDROID_NDK)"

OBJ_COPY="$SWIFT_TOOLCHAIN/usr/bin/llvm-objcopy"
[ -x "$OBJ_COPY" ] || die "llvm-objcopy missing: $OBJ_COPY"
# Note: the NDK's llvm-strip is a broken symlink to a missing llvm-objcopy.
# Use the Swift toolchain's llvm-objcopy instead of the NDK's llvm-strip.

SCRATCH="$JNI/.build-android"
# SwiftPM only emits a loadable .so for a product declared `type: .dynamic`.
# The .so ships under the JNI package's product name, not MeditateAndNoteCore:
# SwiftPM rejects two products with the same name in one package graph
# ("Found multiple targets named 'MeditateAndNoteCore-product'"), so the product
# is renamed and the generated Java's LIB_NAME is rewritten to match.
PRODUCT="$SCRATCH/out/Products/Release-android-aarch64/libMeditateAndNoteCoreJNI.so"

# Generated bindings and the compiled thunks both have to exist before the .so is
# built, so jextract runs first and its Swift output is copied into the JNI target.
GENERATED="$CORE/.generated"
THUNKS="$JNI/Sources/MeditateAndNoteCoreJNI/Generated"

if [ "${1:-}" = "--jextract" ] || [ ! -d "$GENERATED/java" ]; then
  [ -x "$SWIFT_JAVA" ] || die "swift-java not built: $SWIFT_JAVA (cd $SWIFT_JAVA_HOME && swift build)"
  rm -rf "$GENERATED" && mkdir -p "$GENERATED/java" "$GENERATED/swift"
  echo "==> Running jextract (JNI mode)"
  (
    cd "$CORE"
    "$SWIFT_JAVA" jextract \
      --mode jni \
      --swift-module MeditateAndNoteCore \
      --java-package com.mn.core \
      --input-swift Sources/MeditateAndNoteCore \
      --output-swift "$GENERATED/swift" \
      --output-java "$GENERATED/java"
  )

  # jextract emits an unconditional load of libSwiftJava.so into every generated
  # class, because normally the Swift runtime lives in its own shared library.
  # We build --static-swift-stdlib, so it is already inside libMeditateAndNoteCore.so
  # and that load can only ever fail:
  #   dlopen failed: library "libSwiftJava.so" not found
  # It is a load, not a check, so leaving it in crashes the app at startup
  # whichever class happens to be touched first.
  SWIFTJAVA_FILES=$(grep -rl 'LIB_NAME_SWIFT_JAVA' "$GENERATED/java" | wc -l | tr -d ' ')
  grep -rl 'LIB_NAME_SWIFT_JAVA' "$GENERATED/java" | while read -r f; do
    sed -i '' '/LIB_NAME_SWIFT_JAVA/d' "$f"
  done
  echo "    removed SwiftJava load from $SWIFTJAVA_FILES generated files"

  # jextract derives LIB_NAME from the Swift module name, but the .so we ship is
  # the JNI package's product. System.loadLibrary(LIB_NAME) would not find it.
  LIB_FILES=$(grep -rl 'LIB_NAME = "MeditateAndNoteCore"' "$GENERATED/java" | wc -l | tr -d ' ')
  grep -rl 'LIB_NAME = "MeditateAndNoteCore"' "$GENERATED/java" | while read -r f; do
    sed -i '' 's/LIB_NAME = "MeditateAndNoteCore"/LIB_NAME = "MeditateAndNoteCoreJNI"/' "$f"
  done
  echo "    pointed LIB_NAME at MeditateAndNoteCoreJNI in $LIB_FILES files"
  echo "    java:  $(find "$GENERATED/java" -name '*.java' | wc -l | tr -d ' ') files"
fi

# The @_cdecl JNI entry points have to be compiled into the .so, so they are
# copied in as ordinary sources rather than being regenerated in place.
rm -rf "$THUNKS" && mkdir -p "$THUNKS"
cp "$GENERATED"/swift/*.swift "$THUNKS"/
# jextract assumes the thunks live in the same module as the types they wrap, so
# it emits no import for them. Ours live in a separate target (MeditateAndNoteCore
# must stay free of a swift-java dependency), which makes every reference fail
# with "cannot find type 'AIDraftMetric' in scope". Adding the import is the fix.
python3 - "$THUNKS" <<'PYEOF'
# Anchored on a column-0 `import`, not "the first import line": the first one
# sits inside a #if/#else block, so inserting there is conditional and silently
# does nothing when the other branch is taken.
import pathlib, sys
root = pathlib.Path(sys.argv[1])
for f in sorted(root.glob("*.swift")):
    lines = f.read_text().split("\n")
    if any(l == "import MeditateAndNoteCore" for l in lines):
        continue
    for i, l in enumerate(lines):
        if l.startswith("import "):
            lines.insert(i, "import MeditateAndNoteCore")
            break
    else:
        sys.exit(f"no top-level import to anchor on in {f}")
    f.write_text("\n".join(lines))
PYEOF

# jextract cannot express DomainEvent: the enum's payloads trip its JavaValue
# conformance and the emitted code references types it never declares
# ("requires that 'DomainEvent' conform to 'JavaValue'", "cannot find '_0Class'").
# Nothing on the Android side touches DomainEvent, so the thunks are dropped
# rather than worked around. Add them back if a Kotlin caller ever needs them.
rm -f "$THUNKS/DomainEvents+SwiftJava.swift"

echo "==> Compiled $(ls "$THUNKS" | wc -l | tr -d ' ') generated thunks into the JNI target"

echo "==> Building the JNI library for $TARGET_TRIPLE"
# Built from MeditateAndNoteCoreJNI, not MeditateAndNoteCore: the .so needs the
# jextract-generated @_cdecl thunks compiled in, and those import SwiftJava.
# Without them the library loads and then every call fails with "No implementation
# found for ... - is the library loaded".
(
  cd "$JNI"
  ANDROID_NDK="$ANDROID_NDK" \
  SWIFT_JAVA_PATH="$SWIFT_JAVA_HOME" \
  TOOLCHAINS="$TOOLCHAINS_ID" swift build \
    --swift-sdk "$ANDROID_SDK_BUNDLE/swift-sdk.json" \
    --swift-sdk "$TARGET_TRIPLE" \
    --static-swift-stdlib \
    --product MeditateAndNoteCoreJNI \
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
# The library used to be named libMeditateAndNoteCore.so before the product had to
# be renamed. Left in place it still ships, gets loaded by any stale binding, and
# fails with "No implementation found for ..." because it has no JNI thunks.
rm -f "$JNI_LIBS/libMeditateAndNoteCore.so"
cp "$STRIPPED" "$JNI_LIBS/libMeditateAndNoteCoreJNI.so"
cp "$CXX_SHARED" "$JNI_LIBS/libc++_shared.so"
echo "==> Copied into $JNI_LIBS"
ls -la "$JNI_LIBS"

echo "==> done"