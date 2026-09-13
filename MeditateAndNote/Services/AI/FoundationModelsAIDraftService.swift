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
            let nsError = error as NSError
            print("[AIDraft] generate() error: \(error.localizedDescription) — domain: \(nsError.domain), code: \(nsError.code), isColdStartTransient: \(Self.isColdStartTransient(error))")
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
    /// Internal (not private) so the classifier is unit-testable.
    @available(iOS 26.0, *)
    static func isColdStartTransient(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == "com.apple.UnifiedAssetFramework" && nsError.code == 5000 {
            return true
        }
        // "Model assets not ready" failure: generation throws a bridged NSError
        // named after the public enum — domain "FoundationModels.LanguageModelSession.GenerationError",
        // code -1 — even though isAvailable reports .available. This happens on
        // fresh iOS 26 simulators where assets are still downloading. Match the
        // bridge, not a cast: `error as? GenerationError` never matches an NSError,
        // which kept this branch dead before.
        if nsError.code == -1 && nsError.domain.hasSuffix("GenerationError") {
            return true
        }
        guard let generationError = error as? LanguageModelSession.GenerationError else {
            return false
        }
        if case .assetsUnavailable = generationError { return true }
        if case .concurrentRequests = generationError { return true }
        return false
    }

    @available(iOS 26.0, *)
    private static var systemInstructions: String {
        """
        You are a reflective journaling assistant in an app called MeditateAndNote. \
        Read the user's note and their request, then offer concise, thoughtful \
        suggestions to help them continue. Never invent personal facts. Keep each \
        suggestion under 140 characters.

        Respond with ONLY a single JSON object and nothing else — no markdown, no \
        explanations, no reasoning or inner monologue before or after. Use exactly \
        this shape: {"suggestions":[{"text":"...","rationale":"..."}]}
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

    /// Best-effort structured parse. Internal (not private) so it's unit-testable.
    @available(iOS 26.0, *)
    static func parseSuggestions(from text: String, max: Int) -> [AISuggestion] {
        // Best-effort structured parse. The model wraps pure JSON in a markdown
        // code fence (or occasionally prose), so locate the object anywhere in
        // the text instead of requiring the whole string to be JSON.
        if let json = extractJSONObject(from: text),
           let items = json["suggestions"] as? [[String: Any]] {
            let parsed = items.compactMap { item -> AISuggestion? in
                guard let text = item["text"] as? String, !text.isEmpty else { return nil }
                return AISuggestion(text: text, rationale: item["rationale"] as? String ?? "")
            }
            if !parsed.isEmpty { return Array(parsed.prefix(max)) }
        }

        // No JSON: fall back to treating each plausible line as a suggestion,
        // stripping list markers and reasoning/noise lines.
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { line in
                line
                    .replacingOccurrences(of: #"^[-•*]\s+"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"^\d+[.)]\s+"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { isSuggestiveLine($0) }
        return Array(lines.prefix(max).map { AISuggestion(text: String($0)) })
    }

    /// Extracts the first JSON object found anywhere in `text` (code fences,
    /// prose delimiters, leading/following chatter all tolerated).
    @available(iOS 26.0, *)
    private static func extractJSONObject(from text: String) -> [String: Any]? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"),
              start < end else { return nil }
        let slice = String(text[start...end])
        guard let data = slice.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    /// Filter for the line fallback: drops reasoning/"thinking" breadcrumbs,
    /// headers and other non-suggestion noise.
    @available(iOS 26.0, *)
    private static func isSuggestiveLine(_ line: String) -> Bool {
        guard !line.isEmpty else { return false }
        let lower = line.lowercased()
        let noisePrefixes = [
            "```", "let me", "i think", "i feel", "i would", "thinking",
            "first,", "here", "suggestion", "reasoning", "approach",
            "the user", "one idea", "maybe i", "my goal", "to help", "okay",
            "note:", "ideas to", "in this", "sure,", "of course", "no problem"
        ]
        if noisePrefixes.contains(where: { lower.hasPrefix($0) }) { return false }
        if line.contains(where: { "\"{}[]".contains($0) }) { return false }
        return true
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
