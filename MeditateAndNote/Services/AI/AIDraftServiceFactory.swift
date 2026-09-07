//
//  AIDraftServiceFactory.swift
//  MeditateAndNote
//
//  Runtime selection of the AI suggestion provider. Resolved once at startup
//  by AppContainer. When Apple Intelligence isn't available on this device/OS,
//  it falls back to a remote API if configured, else to a disabled stub so the
//  UI can degrade gracefully.
//

import Foundation

enum AIDraftServiceFactory {

    static func make(remote: (any AIDraftService)? = nil) -> any AIDraftService {
        let onDevice: any AIDraftService = FoundationModelsAIDraftService()

        // Cheap synchronous gate first: even building the on-device service is
        // fine on < iOS 26 (guarded by canImport), but a Task hops are avoided
        // when we already know the OS can't run it.
        if #available(iOS 26.0, *) {
            return onDevice
        }

        if let remote {
            return remote
        }

        return DisabledAIDraftService()
    }
}