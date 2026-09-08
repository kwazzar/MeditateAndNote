//
//  KeychainService.swift
//  MeditateAndNote
//
//  Infrastructure wrapper around Security framework (Keychain) for secure
//  storage of remote AI API keys and configuration tokens.
//

import Foundation
import Security
import OSLog

protocol KeychainServiceProtocol: Sendable {
    func save(key: String, value: String) throws
    func read(key: String) -> String?
    func delete(key: String) throws
}

struct KeychainService: KeychainServiceProtocol {
    private let serviceName: String
    private let logger = Logger(subsystem: Config.bundleID, category: "KeychainService")

    init(serviceName: String = "com.meditateandnote.ai") {
        self.serviceName = serviceName
    }

    func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)

        if status == errSecSuccess {
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data
            ]
            let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            guard updateStatus == errSecSuccess else {
                logger.error("Failed to update keychain item for \(key): \(updateStatus)")
                throw KeychainError.unhandledError(status: updateStatus)
            }
        } else if status == errSecItemNotFound {
            var newQuery = query
            newQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(newQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                logger.error("Failed to add keychain item for \(key): \(addStatus)")
                throw KeychainError.unhandledError(status: addStatus)
            }
        } else {
            logger.error("Keychain read error for \(key): \(status)")
            throw KeychainError.unhandledError(status: status)
        }
    }

    func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        guard status == errSecSuccess, let data = dataTypeRef as? Data, let result = String(data: data, encoding: .utf8) else {
            return nil
        }
        return result
    }

    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Failed to delete keychain item for \(key): \(status)")
            throw KeychainError.unhandledError(status: status)
        }
    }
}

enum KeychainError: Error, Equatable {
    case unhandledError(status: OSStatus)
}
