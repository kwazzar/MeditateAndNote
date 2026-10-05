//
//  StreakActivityStore.swift
//  MeditateAndNoteCore
//

// MARK: - StreakActivityStore (persistence boundary / ACL)

/// Persistence contract for the streak snapshot.
///
/// In the domain package for the same reason as `NoteDataSource`: the Android
/// build never compiles the app target, so the contract has to be visible to
/// `MeditateAndNoteCoreJNI`.
public protocol StreakActivityStore: Sendable {
    /// Loads the last saved snapshot, or nil when nothing valid is stored.
    /// Implementations must never return a partially populated snapshot.
    func load() -> StreakSnapshot?
    /// Persists the snapshot atomically: either every field lands in storage,
    /// or none does.
    func save(_ snapshot: StreakSnapshot) async
}