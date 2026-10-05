#!/bin/bash
#
# One command from a Swift change to an installed APK:
#
#   Scripts/build-android-apk.sh
#
# Builds the Swift core into jniLibs, then assembles and installs the APK. The
# two steps stay separate scripts because they answer different questions: is
# the Swift core still buildable, and does the Android app still build against
# it. The Gradle side also depends on :app:swiftCore, so `./gradlew
# assembleDebug` alone is never stale.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# gradlew needs JAVA_HOME, and this shell does not have one. Android Studio's
# bundled JDK is the right one (it is what AGP is tested against); override for a
# different install.
JAVA_HOME="${JAVA_HOME:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}"
export JAVA_HOME
[ -d "$JAVA_HOME" ] || { echo "error: JAVA_HOME is not a directory: $JAVA_HOME" >&2; exit 1; }

"$ROOT/Scripts/build-android.sh" "$@"

cd "$ROOT/Android"
exec ./gradlew "${GRADLE_ARGS:-:app:installDebug}"