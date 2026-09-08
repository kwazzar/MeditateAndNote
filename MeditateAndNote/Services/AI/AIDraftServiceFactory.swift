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
        // REMOTE: RemoteLLMDraftService - TODO: add to Xcode project for full fallback support
        // For now, use the remote service if provided, else disabled
        let remoteService: any AIDraftService = remote ?? DisabledAIDraftService()

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