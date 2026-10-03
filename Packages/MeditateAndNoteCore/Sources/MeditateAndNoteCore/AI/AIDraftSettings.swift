//
//  AIDraftSettings.swift
//  MeditateAndNote
//
//  Domain value object representing user settings for AI draft generation,
//  including remote fallback configuration and privacy preferences.
//

import Foundation

public struct AIDraftSettings: Equatable, Codable, Sendable {
    /// Whether to use remote API fallback when on-device AI (Foundation Models) is unavailable.
    /// Default is false for privacy-first opt-in.
    public var useRemoteFallback: Bool
    
    /// Remote LLM provider endpoint URL (OpenAI / Anthropic compatible).
    public var remoteEndpointURL: String
    
    /// Selected model for remote generation.
    public var selectedModel: String
    
    /// Daily generation budget cap per user to prevent API cost runaway.
    public var dailyGenerationLimit: Int

    public static let defaultEndpointURL = "https://api.openai.com/v1/chat/completions"
    public static let defaultModel = "gpt-4o-mini"
    public static let defaultDailyLimit = 5

    public init(
        useRemoteFallback: Bool = false,
        remoteEndpointURL: String = defaultEndpointURL,
        selectedModel: String = defaultModel,
        dailyGenerationLimit: Int = defaultDailyLimit
    ) {
        self.useRemoteFallback = useRemoteFallback
        self.remoteEndpointURL = remoteEndpointURL
        self.selectedModel = selectedModel
        self.dailyGenerationLimit = max(1, min(50, dailyGenerationLimit))
    }
}

// MARK: - Settings Store Contract

public protocol AIDraftSettingsStore: Sendable {
    func loadSettings() -> AIDraftSettings
    func saveSettings(_ settings: AIDraftSettings)
    func getAPIKey() -> String?
    func saveAPIKey(_ key: String) throws
    func deleteAPIKey() throws
}
