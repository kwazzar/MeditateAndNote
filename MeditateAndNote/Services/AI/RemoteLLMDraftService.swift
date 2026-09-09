//
//  RemoteLLMDraftService.swift
//  MeditateAndNote
//
//  Infrastructure implementation of AIDraftService using a remote LLM API
//  (e.g., OpenAI / Anthropic-compatible chat completions API).
//  Guarded by user opt-in, API key in Keychain, and daily rate caps.
//

import Foundation
import OSLog

struct RemoteLLMDraftService: AIDraftService, @unchecked Sendable {
    private let session: URLSession
    private let settingsStore: any AIDraftSettingsStore
    // UserDefaults isn't Sendable; all access is confined to async service
    // calls (no concurrent mutation), so unchecked conformance is safe here.
    private let userDefaults: UserDefaults
    private let logger = Logger(subsystem: Config.bundleID, category: "RemoteLLMDraft")

    private static let dailyUsageKey = "com.meditateandnote.ai.dailyUsage"
    private static let dailyUsageDateKey = "com.meditateandnote.ai.dailyUsageDate"

    init(
        session: URLSession = .shared,
        settingsStore: any AIDraftSettingsStore = UserDefaultsAIDraftSettingsStore(),
        userDefaults: UserDefaults = .standard
    ) {
        self.session = session
        self.settingsStore = settingsStore
        self.userDefaults = userDefaults
    }

    var isAvailable: Bool {
        get async {
            let settings = settingsStore.loadSettings()
            guard settings.useRemoteFallback else { return false }
            guard let apiKey = settingsStore.getAPIKey(), !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return false
            }
            guard checkAndIncrementDailyUsage(readOnly: true, limit: settings.dailyGenerationLimit) else {
                return false
            }
            return true
        }
    }

    func suggest(_ prompt: AIPrompt) async throws -> [AISuggestion] {
        let settings = settingsStore.loadSettings()
        guard settings.useRemoteFallback else {
            throw AIDraftError.providerUnavailable
        }

        guard let apiKey = settingsStore.getAPIKey(), !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIDraftError.providerUnavailable
        }

        guard checkAndIncrementDailyUsage(readOnly: false, limit: settings.dailyGenerationLimit) else {
            throw AIDraftError.rateLimited
        }

        guard let url = URL(string: settings.remoteEndpointURL) else {
            throw AIDraftError.providerUnavailable
        }

        let requestDTO = ChatCompletionRequest(
            model: settings.selectedModel,
            messages: [
                .init(role: "system", content: systemInstructions),
                .init(role: "user", content: composeUserMessage(for: prompt))
            ],
            temperature: 0.7
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestDTO)

        let (data, response) = try await executeWithRetry(request: request, maxRetries: 3)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIDraftError.providerUnavailable
        }

        if httpResponse.statusCode == 429 {
            throw AIDraftError.rateLimited
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            logger.error("Remote LLM error status code: \(httpResponse.statusCode)")
            throw AIDraftError.providerUnavailable
        }

        let responseDTO = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = responseDTO.choices.first?.message.content else {
            throw AIDraftError.emptyResponse
        }

        let suggestions = parseSuggestions(from: content, max: prompt.maxSuggestions)
        if suggestions.isEmpty {
            throw AIDraftError.emptyResponse
        }
        return suggestions
    }

    // MARK: - Retry Policy

    private func executeWithRetry(request: URLRequest, maxRetries: Int) async throws -> (Data, URLResponse) {
        var attempts = 0
        var lastError: Error?

        while attempts <= maxRetries {
            do {
                let (data, response) = try await session.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 500 {
                    // Retryable server error
                    attempts += 1
                    if attempts <= maxRetries {
                        let delayNanoseconds = UInt64(pow(2.0, Double(attempts)) * 500_000_000)
                        try await Task.sleep(nanoseconds: delayNanoseconds)
                        continue
                    }
                }
                return (data, response)
            } catch {
                lastError = error
                attempts += 1
                if attempts <= maxRetries {
                    let delayNanoseconds = UInt64(pow(2.0, Double(attempts)) * 500_000_000)
                    try await Task.sleep(nanoseconds: delayNanoseconds)
                }
            }
        }

        throw lastError ?? AIDraftError.providerUnavailable
    }

    // MARK: - Daily Usage Cap

    private func checkAndIncrementDailyUsage(readOnly: Bool, limit: Int) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastDate = userDefaults.object(forKey: Self.dailyUsageDateKey) as? Date ?? .distantPast
        var currentCount = userDefaults.integer(forKey: Self.dailyUsageKey)

        if !calendar.isDate(lastDate, inSameDayAs: today) {
            currentCount = 0
            if !readOnly {
                userDefaults.set(today, forKey: Self.dailyUsageDateKey)
            }
        }

        if currentCount >= limit {
            return false
        }

        if !readOnly {
            userDefaults.set(today, forKey: Self.dailyUsageDateKey)
            userDefaults.set(currentCount + 1, forKey: Self.dailyUsageKey)
        }

        return true
    }

    // MARK: - Helpers

    private var systemInstructions: String {
        """
        You are a reflective journaling assistant in an app called MeditateAndNote. \
        Read the user's note and their request, then offer concise, thoughtful \
        suggestions to help them continue. Never invent personal facts. Keep each \
        suggestion under 140 characters. Return suggestions as a JSON object in this format: \
        {"suggestions": [{"text": "suggestion text", "rationale": "short reason"}]}
        """
    }

    private func composeUserMessage(for prompt: AIPrompt) -> String {
        let context = prompt.context.rawValue.isEmpty ? "(no note content yet)" : prompt.context.rawValue
        return """
        Request: \(prompt.instructions)

        Current note content:
        \(context)
        """
    }

    private func parseSuggestions(from text: String, max: Int) -> [AISuggestion] {
        if let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let items = json["suggestions"] as? [[String: Any]] {
            return items.compactMap { item -> AISuggestion? in
                guard let text = item["text"] as? String, !text.isEmpty else { return nil }
                return AISuggestion(text: text, rationale: item["rationale"] as? String ?? "")
            }.prefix(max).map { $0 }
        }

        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(max)

        return lines.map { AISuggestion(text: String($0)) }
    }
}

// MARK: - DTOs

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
}

private struct ChatMessage: Encodable {
    let role: String
    let content: String
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }
        let message: Message
    }
    let choices: [Choice]
}
