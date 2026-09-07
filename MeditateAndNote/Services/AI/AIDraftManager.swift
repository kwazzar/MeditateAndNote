//
//  AIDraftManager.swift
//  MeditateAndNote
//
//  Application layer: orchestrates AIDraftService (Infrastructure) and
//  AIDraftSessionStore (Infrastructure) over the AIDraftSession aggregate.
//  Exposes a read/write split (AIDraftProvidable / AIDraftManageable) that
//  ViewModels depend on — never on the concrete manager type.
//

import Foundation
import OSLog

// MARK: - Protocols for ViewModels

protocol AIDraftProvidable {
    func session(for noteID: NoteID) async throws -> AIDraftSession?
}

protocol AIDraftManageable {
    /// Start a generation for a note. Returns the newly created session.
    @discardableResult
    func startDraft(noteID: NoteID, instructions: String, context: NoteContent) async throws -> AIDraftSession
    /// Re-run generation for a previously completed session.
    @discardableResult
    func regenerate(sessionID: UUID) async throws -> AIDraftSession
    /// Cancel an in-flight generation.
    func cancel(sessionID: UUID) async throws
    /// Discard all sessions for a note (e.g. when it is deleted).
    func discardSessions(for noteID: NoteID) async throws
}

// MARK: - Manager

final actor AIDraftManager: AIDraftProvidable, AIDraftManageable {

    private let logger = Logger(subsystem: Config.bundleID, category: "AIDraftManager")
    private let service: any AIDraftService
    private let store: any AIDraftSessionStore
    private let eventBus: DomainEventPublisher
    private var inFlight: Set<UUID> = []

    init(
        service: any AIDraftService,
        store: any AIDraftSessionStore,
        eventBus: DomainEventPublisher = DomainEventBus.shared
    ) {
        self.service = service
        self.store = store
        self.eventBus = eventBus
    }

    // MARK: - AIDraftProvidable

    func session(for noteID: NoteID) async throws -> AIDraftSession? {
        try await store.fetch(noteID: noteID)
    }

    // MARK: - AIDraftManageable

    func startDraft(
        noteID: NoteID,
        instructions: String,
        context: NoteContent
    ) async throws -> AIDraftSession {
        // One active generation per note — a second concurrent draft is the
        // same race the state machine guards against. A ready/failed/cancelled
        // session does not block a fresh draft.
        if let existing = try await store.fetch(noteID: noteID), existing.isInFlight {
            logger.warning("Draft session already in flight for note \(noteID.rawValue)")
            throw AIDraftError.noContext
        }

        let prompt = AIPrompt(
            instructions: instructions,
            noteID: noteID,
            context: context,
            maxSuggestions: AIPrompt.defaultMaxSuggestions
        )
        var session = AIDraftSession(noteID: noteID, prompt: prompt)
        session.beginGeneration()
        inFlight.insert(session.id)
        try await store.save(session)

        do {
            let suggestions = try await service.suggest(prompt)
            session.fulfil(with: suggestions)
            inFlight.remove(session.id)
            try await store.save(session)
            publishGenerated(session)
            return session
        } catch {
            session.fail(error as? AIDraftError ?? .emptyResponse)
            inFlight.remove(session.id)
            try await store.save(session)
            throw error
        }
    }

    func regenerate(sessionID: UUID) async throws -> AIDraftSession {
        guard var session = try await store.fetch(id: sessionID) else {
            throw AIDraftError.noContext
        }
        guard session.canGenerate else {
            throw AIDraftError.noContext
        }

        session.beginGeneration()
        inFlight.insert(session.id)
        try await store.save(session)

        do {
            let suggestions = try await service.suggest(session.prompt)
            session.fulfil(with: suggestions)
            inFlight.remove(session.id)
            try await store.save(session)
            publishGenerated(session)
            return session
        } catch {
            session.fail(error as? AIDraftError ?? .emptyResponse)
            inFlight.remove(session.id)
            try await store.save(session)
            throw error
        }
    }

    func cancel(sessionID: UUID) async throws {
        guard var session = try await store.fetch(id: sessionID) else { return }
        session.cancel()
        inFlight.remove(session.id)
        try await store.save(session)
    }

    func discardSessions(for noteID: NoteID) async throws {
        try await store.delete(noteID: noteID)
    }

    // MARK: - Private

    private func publishGenerated(_ session: AIDraftSession) {
        eventBus.publish(.aiDraftGenerated(noteID: session.noteID, sessionID: session.id))
    }
}