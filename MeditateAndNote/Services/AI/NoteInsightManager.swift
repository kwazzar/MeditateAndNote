//
//  NoteInsightManager.swift
//  MeditateAndNote
//
//  Application layer: debounced background analysis of the note collection.
//  Consumes .noteCreated/.noteUpdated/.noteDeleted (via AppContainer's event
//  loop or handle(_:) directly), waits out the debounce window, then runs
//  the NoteAnalyzer once and persists per-note insights. Publishes
//  .noteInsightsUpdated so the UI refreshes without polling.
//
//  Battery guardrails: at most one analysis per `minInterval` (default 60s);
//  rapid edits collapse into a single pass via `debounceInterval` (30s).
//

import Foundation
import OSLog

// MARK: - Protocols for ViewModels

protocol NoteInsightProvidable {
    func insights() async throws -> [NoteInsight]
    func insight(for noteID: NoteID) async throws -> NoteInsight?
}

protocol NoteInsightManageable {
    /// Analyze and persist insights for the given notes.
    func refresh(notes: [Note]) async
    /// Drop the insight for a deleted note.
    func deleteInsights(for noteID: NoteID) async
    /// Collapse rapid note edits into one future analysis pass.
    func scheduleRefresh() async
    /// Force an immediate pass, bypassing the debounce (UI pull-to-refresh).
    func refreshNow() async
}

// MARK: - Manager

final actor NoteInsightManager: NoteInsightProvidable, NoteInsightManageable {

    private let logger = Logger(subsystem: Config.bundleID, category: "NoteInsightManager")
    private let analyzer: any NoteAnalyzer
    private let store: any NoteInsightStore
    private let eventBus: DomainEventPublisher
    /// Provides the current collection; injected as a closure so this actor
    /// never depends on the concrete NoteManager type.
    private let notesProvider: @Sendable () async -> [Note]

    private let debounceInterval: TimeInterval
    private let minInterval: TimeInterval
    private var pendingTask: Task<Void, Never>?
    private var lastRunAt: Date?

    init(
        analyzer: any NoteAnalyzer,
        store: any NoteInsightStore,
        notesProvider: @escaping @Sendable () async -> [Note],
        eventBus: DomainEventPublisher = DomainEventBus.shared,
        debounceInterval: TimeInterval = 30,
        minInterval: TimeInterval = 60
    ) {
        self.analyzer = analyzer
        self.store = store
        self.notesProvider = notesProvider
        self.eventBus = eventBus
        self.debounceInterval = debounceInterval
        self.minInterval = minInterval
    }

    // MARK: - NoteInsightProvidable

    func insights() async throws -> [NoteInsight] {
        try await store.fetchAll()
    }

    func insight(for noteID: NoteID) async throws -> NoteInsight? {
        try await store.fetch(noteID: noteID)
    }

    // MARK: - NoteInsightManageable

    func refresh(notes: [Note]) async {
        guard analyzer.isAvailable else {
            logger.info("Note analyzer unavailable — skipping pass")
            return
        }
        do {
            let fresh = try await analyzer.analyze(notes: notes)
            var savedIDs: [NoteID] = []
            for insight in fresh where !insight.isEmpty {
                try await store.save(insight)
                savedIDs.append(insight.noteID)
            }
            lastRunAt = Date()
            eventBus.publish(.noteInsightsUpdated(savedIDs))
        } catch let error as NoteAnalysisError where error == .insufficientData {
            logger.info("No analyzable note content — skipping persist")
        } catch {
            logger.error("Note analysis pass failed — \(error.localizedDescription)")
        }
    }

    func deleteInsights(for noteID: NoteID) async {
        do {
            try await store.delete(noteID: noteID)
            eventBus.publish(.noteInsightsUpdated([]))
        } catch {
            logger.error("Failed to delete insight — \(error.localizedDescription)")
        }
    }

    func scheduleRefresh() async {
        pendingTask?.cancel()
        let interval = debounceInterval
        pendingTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            } catch {
                return // superseded by a newer edit
            }
            if Task.isCancelled { return }
            await self.refreshNow()
        }
    }

    func refreshNow() async {
        pendingTask?.cancel()
        pendingTask = nil
        if let last = lastRunAt, Date().timeIntervalSince(last) < minInterval {
            logger.info("Analysis throttled — last pass was recent")
            return
        }
        let notes = await notesProvider()
        await refresh(notes: notes)
    }

    // MARK: - Domain Events

    /// Called by AppContainer's event loop. Edits collapse via debounce;
    /// deletes clean up the orphaned row immediately.
    func handle(_ event: DomainEvent) async {
        switch event {
        case .noteCreated, .noteUpdated:
            await scheduleRefresh()
        case .noteDeleted(let noteID):
            pendingTask?.cancel()
            pendingTask = nil
            await deleteInsights(for: noteID)
        case .meditationCompleted, .aiDraftGenerated, .aiDraftMetric, .noteInsightsUpdated:
            break
        }
    }
}
