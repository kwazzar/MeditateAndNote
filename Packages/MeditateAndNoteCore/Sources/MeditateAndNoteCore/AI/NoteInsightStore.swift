//
//  NoteInsightStore.swift
//  MeditateAndNote
//
//  Persistence contract for NoteInsight. Follows the per-domain
//  <X>Store shape (AIDraftSessionStore, StreakActivityStore): the Domain
//  owns the protocol, Persistence owns the CoreData implementation.
//

import Foundation

// MARK: - Store protocol

public protocol NoteInsightStore: Sendable {
    func fetchAll() async throws -> [NoteInsight]
    func fetch(noteID: NoteID) async throws -> NoteInsight?
    func save(_ insight: NoteInsight) async throws
    func delete(noteID: NoteID) async throws
    func deleteAll() async throws
}

// MARK: - In-Memory Implementation (tests + previews)

public final actor InMemoryNoteInsightStore: NoteInsightStore {
    private var collection: NoteInsightsCollection

    public init(seed: [NoteInsight] = []) {
        self.collection = NoteInsightsCollection(insights: seed)
    }

    public func fetchAll() async throws -> [NoteInsight] {
        collection.allInsights
    }

    public func fetch(noteID: NoteID) async throws -> NoteInsight? {
        collection[noteID]
    }

    public func save(_ insight: NoteInsight) async throws {
        collection.upsert(insight)
    }

    public func delete(noteID: NoteID) async throws {
        collection.remove(noteID: noteID)
    }

    public func deleteAll() async throws {
        collection.removeAll()
    }
}
