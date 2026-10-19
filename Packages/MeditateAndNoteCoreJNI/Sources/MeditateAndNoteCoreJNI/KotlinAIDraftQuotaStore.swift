//
//  KotlinAIDraftQuotaStore.swift
//  MeditateAndNoteCoreJNI
//
//  The free-quota counter, stored by Kotlin.
//
//  Division of labour, same as `KotlinNoteDataSource`: Swift owns the bytes
//  and the rules, Kotlin owns the storage. The limit and the rule stay in
//  Core (`AIDraftQuota.freeLimit`, `AIDraftQuota.allowsDraft`); this type
//  only moves the count across the boundary, so a different storage (Room,
//  a server-side counter) can replace it without touching the rule.
//

import Foundation
import MeditateAndNoteCore
import SwiftJava
import SwiftJavaJNICore

/// The Kotlin object's JVM class. Bound to `AIDraftQuotaCounter`.
@JavaClass("com.mn.android.data.AIDraftQuotaCounter")
public class AIDraftQuotaCounter: JavaObject {}

/// SharedPreferences-backed implementation of `AIDraftQuotaStore`.
public struct KotlinAIDraftQuotaStore: AIDraftQuotaStore {

    public init() {}

    public func used() -> Int {
        guard let json = try? JavaClass<AIDraftQuotaCounter>()
            .dynamicJavaStaticMethodCall(methodName: "state", resultType: String.self),
              let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let used = object["used"] as? Int else {
            return 0
        }
        return used
    }

    public func record() {
        _ = try? JavaClass<AIDraftQuotaCounter>()
            .dynamicJavaStaticMethodCall(methodName: "record")
    }
}
