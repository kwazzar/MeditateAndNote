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
            return systemModelAvailability()
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
        return try await generate(prompt)
        #else
        throw AIDraftError.providerUnavailable
        #endif
    }

    // MARK: - FoundationModels backed implementation

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func systemModelAvailability() -> Bool {
        SystemLanguageModel.default.availability == .available
    }

    @available(iOS 26.0, *)
    private func generate(_ prompt: AIPrompt) async throws -> [AISuggestion] {
        let session = LanguageModelSession(
            model: .default,
            tools: [],
            instructions: Self.systemInstructions
        )
        let userMessage = Self.composeUserMessage(for: prompt)

        do {
            let response = try await session.respond(to: userMessage)
            return Self.parseSuggestions(from: response.content, max: prompt.maxSuggestions)
        } catch {
            logger.error("Foundation Models generation failed — \(error.localizedDescription)")
            throw Self.mapError(error)
        }
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
