//
//  RemoteLLMDraftService.swift
//  MeditateAndNote
//
//  Infrastructure implementation of AIDraftService using a remote LLM API
//  (e.g., OpenAI / Anthropic-compatible chat completions API).
//  Guarded by user opt-in, API key in Keychain, and daily rate caps.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import MeditateAndNoteCore

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
        settingsStore: any AIDraftSettingsStore,
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

        let requestBody = AIDraftRemoteProtocol.requestBody(
            model: settings.selectedModel,
            system: AIDraftRemoteProtocol.systemInstructions(for: prompt),
            user: AIDraftRemoteProtocol.userMessage(for: prompt)
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = requestBody.data(using: .utf8)

        let (data, response) = try await executeWithRetry(request: request, maxRetries: 3)

        #if DEBUG
        debug("[AIDraftRemote] === grounded=\(prompt.isGrounded) contextChars=\(prompt.context.rawValue.count) ===")
        debug("[AIDraftRemote] --- system ---\n\(AIDraftRemoteProtocol.systemInstructions(for: prompt))")
        debug("[AIDraftRemote] --- user ---\n\(AIDraftRemoteProtocol.userMessage(for: prompt))")
        #endif

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

        guard let responseText = String(data: data, encoding: .utf8),
              let content = AIDraftRemoteProtocol.content(fromResponse: responseText) else {
            throw AIDraftError.emptyResponse
        }

        let suggestions = AIDraftRemoteProtocol.suggestions(from: content, max: prompt.maxSuggestions)
        #if DEBUG
        debug("[AIDraftRemote] --- raw response ---\n\(content)")
        debug("[AIDraftRemote] --- parsed \(suggestions.count)/\(prompt.maxSuggestions) ---")
        for (index, suggestion) in suggestions.enumerated() {
            debug("[AIDraftRemote] [\(index)] \(suggestion.text)")
        }
        #endif
        if suggestions.isEmpty {
            throw AIDraftError.emptyResponse
        }
        return suggestions
    }

    /// DEBUG-only trace: stdout for the Xcode console, os_log so the same
    /// trace can be streamed off the simulator. Logs the request body, which
    /// contains note text — DEBUG only, never a Release build.
    private func debug(_ line: String) {
        print(line)
        logger.info(line)
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

}
