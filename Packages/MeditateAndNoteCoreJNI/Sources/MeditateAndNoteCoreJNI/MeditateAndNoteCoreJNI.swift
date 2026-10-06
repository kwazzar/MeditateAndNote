//
//  MeditateAndNoteCoreJNI.swift
//  MeditateAndNoteCoreJNI
//
//  Android-only target. Its whole job is to compile the jextract-generated
//  thunks so the JNI entry points actually exist inside
//  libMeditateAndNoteCoreJNI.so.
//
//  Without this, the Java side loads fine and then fails at the first call with:
//
//    No implementation found for long
//    com.mn.core.InMemoryAIDraftMetricStore.$init(long[])
//      - is the library loaded, e.g. System.loadLibrary?
//
//  The `@_cdecl("Java_...")` functions live in the generated files; nothing in
//  MeditateAndNoteCore references them, so without a target that compiles them
//  they get dropped and the .so has no entry points for Kotlin to call.
//

// Swift's generated thunks are compiled from this directory; see
// Scripts/build-android.sh --jextract, which copies them in.
// MARK: - JNI out-param helper

import Foundation
import MeditateAndNoteCore
import SwiftJava
import SwiftJavaJNICore

private let jniWriterLogger = Logger(subsystem: "com.mn.core", category: "JNI")

/// Writes `values` into a `jlongArray` allocated by Kotlin.
///
/// The bound is read from the array itself rather than a constant. Kotlin sizes
/// the buffer before it knows how many values there will be, and writing past
/// the end corrupts whatever the allocator placed next — the only thing standing
/// between a bad count and a heap corruption is this check.
///
/// `SetLongArrayRegion` rather than `GetLongArrayElements`: it writes straight
/// into the buffer, with no copy and no matching Release to get wrong.
func writeValues(_ values: [Int64], to out: jlongArray, in environment: UnsafeMutablePointer<JNIEnv?>!) {
    let capacity = Int(environment.interface.GetArrayLength(environment, out))
    guard values.count <= capacity else {
        jniWriterLogger.warning(
            "payload needs \(values.count) slots but the Kotlin buffer holds \(capacity)"
        )
        return
    }

    let setRegion = Int64.jniSetArrayRegion(in: environment)
    values.withUnsafeBufferPointer { source in
        setRegion(environment, out, 0, jsize(values.count), source.baseAddress)
    }
}
