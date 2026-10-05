//
//  ReverseJniProbe.swift
//  MeditateAndNoteCoreJNI
//
//  Probe for the reverse JNI direction: Swift calling *into* Kotlin.
//
//  Everything proven so far is Kotlin calling Swift, which is the only direction
//  jextract generates. Phase 2 option B (Kotlin implementing a Swift `<X>Store`
//  protocol, Swift domain code driving it) needs the opposite direction, and
//  nobody had checked whether it works.
//
//  The probe hand-writes the Java class binding rather than running
//  `swift-java wrap-java`, because that is a code generator and this question is
//  "does the runtime direction work", not "does the generator work". If this
//  passes, generating the wrappers is a separate, smaller problem.
//
//  Kotlin side: com.mn.android.ReverseJniProbe
//

import SwiftJava
import SwiftJavaJNICore

/// Binds the Kotlin object's JVM class so its static methods can be looked up.
@JavaClass("com.mn.android.ReverseJniProbe")
public class ReverseJniProbe: JavaObject {}

/// Result handed back to Kotlin, so the test does not depend on logging.
public struct ReverseJniResult {
    /// The exact string Kotlin returned, or nil if the call threw.
    public let pong: String?
    /// `echo(20)` computed by Kotlin, or nil if the call threw.
    public let echoed: Int64?
    /// The failure, if any. A nil here with a nil pong means the call failed
    /// rather than returned.
    public let failure: String?
}

/// Calls `ReverseJniProbe.ping()` and `ReverseJniProbe.echo(20)` from Swift.
///
/// Runs on whatever thread Kotlin called it from, which for the probe is the
/// main thread. Room calls in Phase 2 would be the interesting case.
public func callIntoKotlin() -> ReverseJniResult {
    let probe: JavaClass<ReverseJniProbe> = try! JavaClass()

    do {
        let pong = try probe.dynamicJavaStaticMethodCall(
            methodName: "ping",
            resultType: String.self
        )
        let echoed = try probe.dynamicJavaStaticMethodCall(
            methodName: "echo",
            arguments: Int64(20),
            resultType: Int64.self
        )
        return ReverseJniResult(pong: String(pong), echoed: echoed, failure: nil)
    } catch {
        return ReverseJniResult(pong: nil, echoed: nil, failure: "\(error)")
    }
}