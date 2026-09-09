//
//  NoteInsightsViewModel.swift
//  MeditateAndNote
//
//  Presentation state for the background note-insights section.
//  Depends on the Providable/Manageable protocols — never on the concrete
//  NoteInsightManager type. Refreshes arrive via .noteInsightsUpdated.
//

import Foundation
import OSLog

@MainActor
@Observable
final class NoteInsightsViewModel {
    private let logger = Logger(subsystem: Config.bundleID, category: "NoteInsightsViewModel")
    private let provider: any NoteInsightProvidable
    private let manager: any NoteInsightManageable
    private let eventBus: DomainEventPublisher

    private var eventsTask: Task<Void, Never>?

    var insights: [NoteInsight] = []
    var isRefreshing = false
    var error: NoteAnalysisError?

    /// Aggregate theme labels across all insights, most frequent first.
    var topThemes: [String] {
        var counts: [String: Int] = [:]
        for insight in insights {
            for theme in insight.themes {
                counts[theme.label, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.prefix(5).map(\.key)
    }

    var isEmpty: Bool { insights.isEmpty && !isRefreshing }

    init(
        provider: any NoteInsightProvidable & NoteInsightManageable,
        eventBus: DomainEventPublisher = DomainEventBus.shared
    ) {
        self.provider = provider
        self.manager = provider
        self.eventBus = eventBus
        startEventListening()
    }

    /// Test/preview seam with separate read/write doubles.
    init(
        provider: any NoteInsightProvidable,
        manager: any NoteInsightManageable,
        eventBus: DomainEventPublisher = DomainEventBus.shared
    ) {
        self.provider = provider
        self.manager = manager
        self.eventBus = eventBus
        startEventListening()
    }

    func load() async {
        do {
            insights = try await provider.insights()
            error = nil
        } catch let analysisError as NoteAnalysisError {
            self.error = analysisError
            logger.error("Failed to load insights — \(analysisError)")
        } catch {
            logger.error("Failed to load insights — \(error.localizedDescription)")
        }
    }

    /// Force an immediate analysis pass (bypasses the manager's debounce),
    /// then reloads.
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await manager.refreshNow()
        await load()
    }

    func insight(for noteID: NoteID) -> NoteInsight? {
        insights.first { $0.noteID == noteID }
    }
}

// MARK: - Domain Events

@MainActor
private extension NoteInsightsViewModel {
    func startEventListening() {
        eventsTask = Task { [weak self] in
            guard let self else { return }
            for await event in self.eventBus.events {
                switch event {
                case .noteInsightsUpdated:
                    await self.load()
                case .noteCreated, .noteUpdated, .noteDeleted,
                     .meditationCompleted, .aiDraftGenerated, .aiDraftMetric:
                    break
                }
            }
        }
    }
}
