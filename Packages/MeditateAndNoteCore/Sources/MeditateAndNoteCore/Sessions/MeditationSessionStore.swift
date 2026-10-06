//
//  MeditationSessionStore.swift
//  MeditateAndNoteCore
//

import Foundation

// MARK: - MeditationSessionStore (persistence boundary / ACL)

/// Persistence contract for completed meditation sessions.
///
/// In the domain package for the same reason as `NoteDataSource` and
/// `StreakActivityStore`: the Android build compiles `MeditateAndNoteCore` and
/// `MeditateAndNoteCoreJNI` only, so a Swift adapter over Kotlin's SQLite has
/// nowhere to live if the contract sits in the app target.
///
/// `handle(_ event:)` is deliberately not part of this. Reacting to
/// `DomainEvent` is orchestration — `EventLoopCoordinator` hands events to the
/// scopes that own each store — not a persistence operation, and putting it
/// here would make every implementation subscribe to a bus it does not otherwise
/// need.
public protocol MeditationSessionStore: Sendable {
    /// Records a completed session. Saving an id that is already stored
    /// replaces it rather than adding a second row.
    func save(_ session: MeditationSession) async

    /// Sessions that completed on the same calendar day as `date`, newest
    /// first. The day boundaries come from the implementation's own calendar,
    /// so two implementations agree only if they share a time zone.
    func sessions(for date: Date) async -> [MeditationSession]

    /// One entry per calendar day that has at least one session, used for
    /// marking days in the history UI.
    func allSessionDates() async -> Set<Date>
}
