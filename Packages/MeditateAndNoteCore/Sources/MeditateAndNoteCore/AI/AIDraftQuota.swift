//
//  AIDraftQuota.swift
//  MeditateAndNoteCore
//

import Foundation

/// Free-tier allowance for AI draft generations. Premium users are unlimited;
/// free users get a lifetime allowance counted by `AIDraftQuotaStore`.
public enum AIDraftQuota {
    /// Lifetime free generations. Product value — bump to widen the funnel.
    public static let freeLimit = 5

    public static func allowsDraft(isPremium: Bool, used: Int) -> Bool {
        isPremium || used < freeLimit
    }
}

/// Persistence contract for the free-quota counter. A counter, never an
/// authority: it can only *restrict* access, never grant it.
public protocol AIDraftQuotaStore: Sendable {
    func used() -> Int
    func record()
}

// MARK: - In-Memory Implementation (tests + previews)

public final class InMemoryAIDraftQuotaStore: AIDraftQuotaStore, @unchecked Sendable {
    private let lock = NSLock()
    private var count: Int

    public init(used: Int = 0) {
        count = used
    }

    public func used() -> Int {
        lock.lock(); defer { lock.unlock() }
        return count
    }

    public func record() {
        lock.lock(); defer { lock.unlock() }
        count += 1
    }
}
