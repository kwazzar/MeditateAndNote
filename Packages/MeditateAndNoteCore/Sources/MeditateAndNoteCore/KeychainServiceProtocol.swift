//
//  KeychainServiceProtocol.swift
//  MeditateAndNoteCore
//

import Foundation

/// Contract for secure storage of remote AI API keys. The concrete store is
/// platform-specific (Keychain on Apple, encrypted preferences on Android), so
/// only the protocol belongs in the domain.
public protocol KeychainServiceProtocol: Sendable {
    func save(key: String, value: String) throws
    func read(key: String) -> String?
    func delete(key: String) throws
}
