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
import MeditateAndNoteCore

// MARK: - Protocols for ViewModels

protocol AIDraftProvidable: Sendable {
    func session(for noteID: NoteID) async throws -> AIDraftSession?
}

protocol AIDraftManageable: Sendable {
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
    /// Accept a single suggestion into the accepted pool and persist.
    func acceptSuggestion(sessionID: UUID, suggestionID: UUID) async throws -> AIDraftSession
    /// Accept all pending suggestions and persist.
    func acceptAllSuggestions(sessionID: UUID) async throws -> AIDraftSession
    /// Reject an accepted suggestion back to pending and persist.
    func rejectSuggestion(sessionID: UUID, suggestionID: UUID) async throws -> AIDraftSession
}

// MARK: - Manager

final actor AIDraftManager: AIDraftProvidable, AIDraftManageable {

    private let logger = Logger(subsystem: Config.bundleID, category: "AIDraftManager")
    private let service: any AIDraftService
    private let store: any AIDraftSessionStore
    private let eventBus: DomainEventPublisher
    /// Premium read for the free-quota rule. Closure (not the protocol) so
    /// this actor never depends on a @MainActor type — same seam as
    /// `notesProvider` in `NoteInsightManager`.
    private let isEntitled: @Sendable () async -> Bool
    private let quota: any AIDraftQuotaStore
    /// Notes with a generation currently claimed. Checked synchronously (no
    /// await between check and claim) so two concurrent requests for the same
    /// note can't both observe an empty store and start a duplicate draft.
    private var inFlight: Set<NoteID> = []
    /// Tracks whether any generation has already run in this process, so first
    /// usage can be flagged as a cold vs warm start in telemetry.
    private var hasAttemptedGeneration = false

    init(
        service: any AIDraftService,
        store: any AIDraftSessionStore,
        eventBus: DomainEventPublisher = DomainEventBus.shared,
        isEntitled: @escaping @Sendable () async -> Bool = { true },
        quota: any AIDraftQuotaStore = InMemoryAIDraftQuotaStore()
    ) {
        self.service = service
        self.store = store
        self.eventBus = eventBus
        self.isEntitled = isEntitled
        self.quota = quota
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
        // Synchronous claim — no await between check and insert, so a second
        // concurrent draft for the same note can't slip through the gap.
        guard inFlight.insert(noteID).inserted else {
            logger.warning("Draft already in flight for note \(noteID.rawValue)")
            throw AIDraftError.noContext
        }
        defer { inFlight.remove(noteID) }

        // A persisted in-flight session (e.g. app relaunch with a stale row)
        // still blocks a fresh draft.
        if let existing = try await store.fetch(noteID: noteID), existing.isInFlight {
            logger.warning("Draft session already in flight for note \(noteID.rawValue)")
            throw AIDraftError.noContext
        }

        let entitled = try await checkQuota()
        var session = AIDraftSession(
            noteID: noteID,
            prompt: AIPrompt(
                instructions: instructions,
                noteID: noteID,
                context: context,
                maxSuggestions: AIPrompt.defaultMaxSuggestions
            )
        )
        try await runGeneration(&session, countAgainstQuota: !entitled)
        return session
    }

    func regenerate(sessionID: UUID) async throws -> AIDraftSession {
        guard var session = try await store.fetch(id: sessionID) else {
            throw AIDraftError.noContext
        }
        guard session.canGenerate else {
            throw AIDraftError.noContext
        }

        // Synchronous claim on the note — also covers racing regenerate calls.
        guard inFlight.insert(session.noteID).inserted else {
            logger.warning("Draft already in flight for note \(session.noteID.rawValue)")
            throw AIDraftError.noContext
        }
        defer { inFlight.remove(session.noteID) }

        let entitled = try await checkQuota()
        try await runGeneration(&session, countAgainstQuota: !entitled)
        return session
    }

    func cancel(sessionID: UUID) async throws {
        guard var session = try await store.fetch(id: sessionID) else { return }
        session.cancel()
        inFlight.remove(session.noteID)
        try await store.save(session)
    }

    func acceptAllSuggestions(sessionID: UUID) async throws -> AIDraftSession {
        guard var session = try await store.fetch(id: sessionID) else {
            throw AIDraftError.noContext
        }
        session.acceptAll()
        try await store.save(session)
        return session
    }

    func rejectSuggestion(sessionID: UUID, suggestionID: UUID) async throws -> AIDraftSession {
        guard var session = try await store.fetch(id: sessionID) else {
            throw AIDraftError.noContext
        }
        let suggestion = session.acceptedSuggestions.first { $0.id == suggestionID }
        guard let suggestion else { throw AIDraftError.noContext }
        _ = session.reject(suggestion)
        try await store.save(session)
        return session
    }

    func acceptSuggestion(sessionID: UUID, suggestionID: UUID) async throws -> AIDraftSession {
        guard var session = try await store.fetch(id: sessionID) else {
            throw AIDraftError.noContext
        }
        let suggestion = session.suggestions.first { $0.id == suggestionID } ??
            session.acceptedSuggestions.first { $0.id == suggestionID }
        guard let suggestion else { throw AIDraftError.noContext }
        if !session.acceptedSuggestions.contains(where: { $0.id == suggestionID }) {
            _ = session.accept(suggestion)
        }
        try await store.save(session)
        return session
    }

    func discardSessions(for noteID: NoteID) async throws {
        try await store.delete(noteID: noteID)
    }

    // MARK: - Private

    /// Free-tier gate. Returns whether the caller is premium (so a successful
    /// generation can skip burning quota). Premium passes unconditionally.
    private func checkQuota() async throws -> Bool {
        let entitled = await isEntitled()
        guard AIDraftQuota.allowsDraft(isPremium: entitled, used: quota.used()) else {
            logger.info("Free draft quota exhausted (limit \(AIDraftQuota.freeLimit))")
            throw AIDraftError.freeQuotaExhausted
        }
        return entitled
    }

    /// Shared generation pipeline for start/regenerate: mark, call provider,
    /// persist, publish. Free users burn one quota unit per *successful*
    /// generation — failed attempts don't count against the allowance.
    /// ponytail: quota check and `record()` span an await, so two concurrent
    /// free drafts on different notes can overshoot `freeLimit` by one —
    /// acceptable for a client-side allowance; serialize if it ever matters.
    private func runGeneration(_ session: inout AIDraftSession, countAgainstQuota: Bool) async throws {
        session.beginGeneration()
        try await store.save(session)

        let start = generationStart()
        do {
            let suggestions = try await service.suggest(session.prompt)
            session.fulfil(with: suggestions)
            try await store.save(session)
            if countAgainstQuota { quota.record() }
            publishGenerated(session)
            publishCompleted(suggestionCount: suggestions.count, start: start)
        } catch {
            session.fail(error as? AIDraftError ?? .emptyResponse)
            try await store.save(session)
            publishFailed(error: error)
            throw error
        }
    }

    private func publishGenerated(_ session: AIDraftSession) {
        eventBus.publish(.aiDraftGenerated(noteID: session.noteID, sessionID: session.id))
    }

    /// Marks the start of a generation attempt and returns the monotonic
    /// timestamp used to measure provider latency.
    private func generationStart() -> UInt64 {
        let start = DispatchTime.now().uptimeNanoseconds
        eventBus.publish(.aiDraftMetric(event: .generationStarted(warmCold: !hasAttemptedGeneration)))
        hasAttemptedGeneration = true
        return start
    }

    private func publishCompleted(suggestionCount: Int, start: UInt64) {
        let elapsed = Int((DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
        eventBus.publish(.aiDraftMetric(event: .generationCompleted(
            latencyMs: elapsed,
            suggestionCount: suggestionCount
        )))
    }

    private func publishFailed(error: Error) {
        eventBus.publish(.aiDraftMetric(event: .generationFailed(errorKind: Self.errorKind(for: error))))
    }

    /// Maps a caught error to the sandboxed typed ErrorKind — never the raw
    /// error message — so telemetry rows can't leak note content or URLs.
    private static func errorKind(for error: Error) -> ErrorKind {
        guard let draftError = error as? AIDraftError else { return .unknown }
        switch draftError {
        case .noContext, .contextTooLong: return .unavailable
        case .rateLimited: return .rateLimited
        case .providerUnavailable: return .unavailable
        case .emptyResponse: return .emptyResponse
        case .cancelled: return .unknown
        case .noAcceptedProposals: return .unknown
        case .freeQuotaExhausted: return .rateLimited
        }
    }
}

// MARK: - Stub (for tests/previews)

struct AIDraftManagerStub: AIDraftProvidable, AIDraftManageable, Sendable {
    func session(for noteID: NoteID) async throws -> AIDraftSession? { nil }
    func startDraft(noteID: NoteID, instructions: String, context: NoteContent) async throws -> AIDraftSession {
        AIDraftSession(noteID: noteID, prompt: AIPrompt(instructions: instructions, noteID: noteID, context: context))
    }
    func regenerate(sessionID: UUID) async throws -> AIDraftSession {
        throw AIDraftError.noContext
    }
    func cancel(sessionID: UUID) async throws {}
    func discardSessions(for noteID: NoteID) async throws {}
    func acceptSuggestion(sessionID: UUID, suggestionID: UUID) async throws -> AIDraftSession {
        throw AIDraftError.noContext
    }
    func acceptAllSuggestions(sessionID: UUID) async throws -> AIDraftSession {
        throw AIDraftError.noContext
    }
    func rejectSuggestion(sessionID: UUID, suggestionID: UUID) async throws -> AIDraftSession {
        throw AIDraftError.noContext
    }
}
