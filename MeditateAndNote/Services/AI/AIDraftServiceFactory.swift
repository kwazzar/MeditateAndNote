//
//  AIDraftServiceFactory.swift
//  MeditateAndNote
//
//  Runtime selection of the AI suggestion provider. Resolved at startup
//  by AppContainer. When Apple Intelligence isn't available on this device/OS,
//  it falls back to a remote API if configured, else to a disabled stub so the
//  UI can degrade gracefully.
//

import Foundation

enum AIDraftServiceFactory {

    static func make(remote: (any AIDraftService)? = nil) -> any AIDraftService {
        let onDevice: any AIDraftService = FoundationModelsAIDraftService()
        // RemoteLLMDraftService is opt-in gated inside (settings toggle +
        // Keychain key), so wiring it by default is safe: without opt-in it
        // reports unavailable and the UI degrades exactly as before.
        let remoteService: any AIDraftService = remote ?? RemoteLLMDraftService()

        if #available(iOS 26.0, *) {
            return CompositeFallbackAIDraftService(primary: onDevice, secondary: remoteService)
        }

        return CompositeFallbackAIDraftService(primary: remoteService, secondary: DisabledAIDraftService())
    }
}

// MARK: - Composite Fallback Service

struct CompositeFallbackAIDraftService: AIDraftService {
    let primary: any AIDraftService
    let secondary: any AIDraftService

    var isAvailable: Bool {
        get async {
            if await primary.isAvailable { return true }
            return await secondary.isAvailable
        }
    }

    func suggest(_ prompt: AIPrompt) async throws -> [AISuggestion] {
        if await primary.isAvailable {
            do {
                return try await primary.suggest(prompt)
            } catch let error as AIDraftError where error == .providerUnavailable || error == .rateLimited {
                if await secondary.isAvailable {
                    return try await secondary.suggest(prompt)
                }
                throw error
            } catch {
                if await secondary.isAvailable {
                    return try await secondary.suggest(prompt)
                }
                throw error
            }
        } else if await secondary.isAvailable {
            return try await secondary.suggest(prompt)
        } else {
            throw AIDraftError.providerUnavailable
        }
    }
}