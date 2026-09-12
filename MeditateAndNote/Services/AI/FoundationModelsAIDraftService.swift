//
//  FoundationModelsAIDraftService.swift
//  MeditateAndNote
//
//  On-device AI suggestion provider built on Apple's Foundation Models
//  framework (iOS 26+). Guarded by `canImport` so the whole project still
//  compiles at its deployment target (17.6) where the framework is absent;
//  at runtime `isAvailable` reports false unless the OS + Apple Intelligence
//  are actually available.
//
//  The FoundationModels API surface is isolated here — nothing in Domain or
//  Application touches it — so a future SDK change only touches this file.
//

import Foundation
import OSLog

#if canImport(FoundationModels)
import FoundationModels
#endif

struct FoundationModelsAIDraftService: AIDraftService {

    private let logger = Logger(subsystem: Config.bundleID, category: "AIDraft")

    var isAvailable: Bool {
        get async {
            guard #available(iOS 26.0, *) else { return false }
            #if canImport(FoundationModels)
            let result = systemModelAvailability()
            #if DEBUG
            print("[AIDraft] isAvailable check: \(result) — \(SystemLanguageModel.default.availability)")
            #endif
            return result
            #else
            return false
            #endif
        }
    }

    func suggest(_ prompt: AIPrompt) async throws -> [AISuggestion] {
        guard #available(iOS 26.0, *) else {
            throw AIDraftError.providerUnavailable
        }
        #if canImport(FoundationModels)
        #if DEBUG
        print("[AIDraft] suggest() called — isAvailable: \(await isAvailable)")
        #endif
        return try await generate(prompt)
        #else
        throw AIDraftError.providerUnavailable
        #endif
    }

    // MARK: - FoundationModels backed implementation

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func systemModelAvailability() -> Bool {
        switch SystemLanguageModel.default.availability {
        case .available:
            return true
        case .unavailable(let reason):
            // DEBUG diagnostic: the exact reason (deviceNotEligible /
            // appleIntelligenceNotEnabled / modelNotReady) tells whether to
            // wait for a download or give up on this device. No content leaks.
            logger.info("System model unavailable: \(String(describing: reason))")
            return false
        }
    }

    @available(iOS 26.0, *)
    private func generate(_ prompt: AIPrompt) async throws -> [AISuggestion] {
        do {
            return try await respond(prompt)
        } catch {
            #if DEBUG
            print("[AIDraft] generate() error: \(error.localizedDescription) — isColdStartTransient: \(Self.isColdStartTransient(error))")
            #endif
            guard Self.isColdStartTransient(error) else {
                logger.error("Foundation Models generation failed — \(error.localizedDescription)")
                throw Self.mapError(error)
            }
            // First-touch cold start: availability reports ready while model
            // assets are still downloading (observed: instant assetsUnavailable
            // on a fresh sim). Wait out a bounded warmup window and retry once —
            // the retry then blocks until ready, like the analyzer's first call
            // did. Cancellation still propagates through Task.sleep, and a
            // second failure maps to the regular error below.
            logger.info("Model assets not ready — warmup retry in \(Self.warmupDelaySeconds)s")
            #if DEBUG
            print("[AIDraft] Warmup retry after 10s...")
            #endif
            try await Task.sleep(nanoseconds: Self.warmupDelayNanoseconds)
            do {
                let result = try await respond(prompt)
                #if DEBUG
                print("[AIDraft] Warmup retry SUCCESS — suggestions: \(result.count)")
                #endif
                return result
            } catch {
                #if DEBUG
                print("[AIDraft] Warmup retry FAILED — \(error.localizedDescription)")
                #endif
                logger.error("Foundation Models generation failed after warmup — \(error.localizedDescription)")
                throw Self.mapError(error)
            }
        }
    }

    @available(iOS 26.0, *)
    private func respond(_ prompt: AIPrompt) async throws -> [AISuggestion] {
        let session = LanguageModelSession(
            model: .default,
            tools: [],
            instructions: Self.systemInstructions
        )
        let userMessage = Self.composeUserMessage(for: prompt)
        let response = try await session.respond(to: userMessage)
        return Self.parseSuggestions(from: response.content, max: prompt.maxSuggestions)
    }

    /// Bounded warmup before the single retry (failure path only — the hot
    /// path pays nothing).
    @available(iOS 26.0, *)
    private static let warmupDelaySeconds = 10
    @available(iOS 26.0, *)
    private static var warmupDelayNanoseconds: UInt64 {
        UInt64(warmupDelaySeconds) * 1_000_000_000
    }

    /// True for transient not-ready failures worth one warmup retry.
    /// `rateLimited` is deliberately excluded — hammering the limit is wrong;
    /// `CompositeFallbackAIDraftService` routes those to the secondary
    /// provider instead. `if case` (no exhaustive switch) keeps this
    /// resilient to future `GenerationError` cases (non-frozen enum).
/// True for transient not-ready failures worth one warmup retry.
    /// `rateLimited` is deliberately excluded — hammering the limit is wrong;
    /// `CompositeFallbackAIDraftService` routes those to the secondary
    /// provider instead. `if case` (no exhaustive switch) keeps this
    /// resilient to future `GenerationError` cases (non-frozen enum).
    /// Internal (not private) so the classifier is unit-testable.
    @available(iOS 26.0, *)
    static func isColdStartTransient(_ error: Error) -> Bool {
        if let nsError = error as? NSError,
           nsError.domain == "com.apple.UnifiedAssetFramework" && nsError.code == 5000 {
            return true
        }
        guard let generationError = error as? LanguageModelSession.GenerationError else {
            return false
        }
        if case .assetsUnavailable = generationError { return true }
        if case .concurrentRequests = generationError { return true }
        // Handle GenerationError with code -1 (ModelCatalog "no assets" error)
        // which indicates assets are not yet downloaded on this device/simulator,
        // even though isAvailable may report .available. This is the case on
        // fresh iOS 26 simulators where availability reports ready while assets
        // are still downloading (observed: instant assetsUnavailable on first launch).
        if generationError.localizedDescription.contains("error -1") {
            return true
        }
        return false
    }

    @available(iOS 26.0, *)
    private static var systemInstructions: String {
        """
        You are a reflective journaling assistant in an app called MeditateAndNote. \
        Read the user's note and their request, then offer concise, thoughtful \
        suggestions to help them continue. Never invent personal facts. Keep each \
        suggestion under 140 characters.
        """
    }

    @available(iOS 26.0, *)
    private static func composeUserMessage(for prompt: AIPrompt) -> String {
        let context = prompt.context.rawValue.isEmpty ? "(no note content yet)" : prompt.context.rawValue
        return """
        Request: \(prompt.instructions)

        Current note content:
        \(context)
        """
    }

    @available(iOS 26.0, *)
    private static func parseSuggestions(from text: String, max: Int) -> [AISuggestion] {
        // Best-effort structured parse. If the tool output isn't JSON we fall
        // back to treating each non-empty line as a suggestion.
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["suggestions"] as? [[String: Any]] else {
            let lines = text
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(max)
            return lines.map { AISuggestion(text: String($0)) }
        }

        return items
            .compactMap { item -> AISuggestion? in
                guard let text = item["text"] as? String, !text.isEmpty else { return nil }
                return AISuggestion(text: text, rationale: item["rationale"] as? String ?? "")
            }
            .prefix(max)
            .map { $0 }
    }

    @available(iOS 26.0, *)
    private static func mapError(_ error: Error) -> AIDraftError {
        guard let generationError = error as? LanguageModelSession.GenerationError else {
            return .providerUnavailable
        }
        switch generationError {
        case .rateLimited:
            return .rateLimited
        case .decodingFailure, .exceededContextWindowSize:
            return .emptyResponse
        default:
            // Guardrails, refusals, unavailable assets or languages — the UI
            // only needs to know the provider didn't deliver.
            return .providerUnavailable
        }
    }
    #endif
}
