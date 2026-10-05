//
//  ReverseJniProbeEntry.swift
//  MeditateAndNoteCoreJNI
//
//  The JNI entry point Kotlin calls to trigger the reverse direction.
//

import SwiftJava
import SwiftJavaJNICore

/// Returns 1 when Swift reached Kotlin's `ping()` and got the expected string
/// back, or the negated length of whatever it got instead.
///
/// Returns a length rather than the string itself: building a jstring here would
/// be extra machinery that could fail for its own reasons, and the exact string
/// Kotlin returns is already pinned by the comparison in callIntoKotlin().
///
/// Kotlin side: ReverseJniProbe.kt
@_cdecl("Java_com_mn_android_NativeProbe_reverseJNI")
public func Java_com_mn_android_NativeProbe_reverseJNI(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    thisClass: jclass
) -> jlong {
    let result = callIntoKotlin()
    if let failure = result.failure {
        print("[ReverseJni] FAILED: \(failure)")
        return -1
    }
    let pong = result.pong ?? "<nil>"
    let echoed = result.echoed.map(String.init) ?? "<nil>"
    print("[ReverseJni] Kotlin replied: \(pong) / echo(20)=\(echoed)")
    // Nonzero only if Kotlin returned exactly the expected string.
    return pong == "pong-from-kotlin-8f3a" ? 1 : 0
}