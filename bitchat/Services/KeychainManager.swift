//
// KeychainManager.swift
// bitchat
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import BitLogger
import Foundation
import Security

protocol KeychainManagerProtocol {
    func saveIdentityKey(_ keyData: Data, forKey key: String) -> Bool
    func getIdentityKey(forKey key: String) -> Data?
    func deleteIdentityKey(forKey key: String) -> Bool
    func deleteAllKeychainData() -> Bool
    
    func secureClear(_ data: inout Data)
    func secureClear(_ string: inout String)
    
    func verifyIdentityKeyExists() -> Bool
}

final class KeychainManager: KeychainManagerProtocol {
    // Use consistent service name for all keychain items
    private let service = BitchatApp.bundleID
    private let appGroup = "group.\(BitchatApp.bundleID)"
    
    // MARK: - Identity Keys
    
    func saveIdentityKey(_ keyData: Data, forKey key: String) -> Bool {
        let fullKey = "identity_\(key)"
        let result = saveData(keyData, forKey: fullKey)
        SecureLogger.logKeyOperation(.save, keyType: key, success: result)
        return result
    }
    
    func getIdentityKey(forKey key: String) -> Data? {
        let fullKey = "identity_\(key)"
        return retrieveData(forKey: fullKey)
    }
    
    func deleteIdentityKey(forKey key: String) -> Bool {
        let result = delete(forKey: "identity_\(key)")
        SecureLogger.logKeyOperation(.delete, keyType: key, success: result)
        return result
    }
    
    // MARK: - Generic Operations
    
    private func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return saveData(data, forKey: key)
    }
    
    private func saveData(_ data: Data, forKey key: String) -> Bool {
        // Delete any existing item first to ensure clean state
        _ = delete(forKey: key)
        
        // Build base query
        var base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrService as String: service,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecAttrLabel as String: "bitchat-\(key)"
        ]
        #if os(macOS)
        base[kSecAttrSynchronizable as String] = false
        #endif

        // Try with access group where it is expected to work (iOS app builds)
        var triedWithoutGroup = false
        func attempt(addAccessGroup: Bool) -> OSStatus {
            var query = base
            if addAccessGroup { query[kSecAttrAccessGroup as String] = appGroup }
            return SecItemAdd(query as CFDictionary, nil)
        }

        #if os(iOS)
        var status = attempt(addAccessGroup: true)
        if status == -34018 { // Missing entitlement, retry without access group
            triedWithoutGroup = true
            status = attempt(addAccessGroup: false)
        }
        #else
        // On macOS dev/simulator default to no access group to avoid -34018
        let status = attempt(addAccessGroup: false)
        #endif

        if status == errSecSuccess { return true }
        if status == -34018 && !triedWithoutGroup {
            SecureLogger.error(NSError(domain: "Keychain", code: -34018), context: "Missing keychain entitlement", category: .keychain)
        } else if status != errSecDuplicateItem {
            SecureLogger.error(NSError(domain: "Keychain", code: Int(status)), context: "Error saving to keychain", category: .keychain)
        }
        return false
    }
    
    private func retrieve(forKey key: String) -> String? {
        guard let data = retrieveData(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    private func retrieveData(forKey key: String) -> Data? {
        // Base query
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        func attempt(withAccessGroup: Bool) -> OSStatus {
            var q = base
            if withAccessGroup { q[kSecAttrAccessGroup as String] = appGroup }
            return SecItemCopyMatching(q as CFDictionary, &result)
        }

        #if os(iOS)
        var status = attempt(withAccessGroup: true)
        if status == -34018 { status = attempt(withAccessGroup: false) }
        #else
        let status = attempt(withAccessGroup: false)
        #endif

        if status == errSecSuccess { return result as? Data }
        if status == -34018 {
            SecureLogger.error(NSError(domain: "Keychain", code: -34018), context: "Missing keychain entitlement", category: .keychain)
        }
        return nil
    }
    
    private func delete(forKey key: String) -> Bool {
        // Base delete query
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service
        ]

        func attempt(withAccessGroup: Bool) -> OSStatus {
            var q = base
            if withAccessGroup { q[kSecAttrAccessGroup as String] = appGroup }
            return SecItemDelete(q as CFDictionary)
        }

        #if os(iOS)
        var status = attempt(withAccessGroup: true)
        if status == -34018 { status = attempt(withAccessGroup: false) }
        #else
        let status = attempt(withAccessGroup: false)
        #endif
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Cleanup
    
    func deleteAllKeychainData() -> Bool {
        return deleteAllPasswords()
    }
    
    func deleteAllPasswords() -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword
        ]
        
        // Add service if not empty
        if !service.isEmpty {
            query[kSecAttrService as String] = service
        }
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Security Utilities
    
    /// Securely clear sensitive data from memory
    func secureClear(_ data: inout Data) {
        _ = data.withUnsafeMutableBytes { bytes in
            // Use volatile memset to prevent compiler optimization
            memset_s(bytes.baseAddress, bytes.count, 0, bytes.count)
        }
        data = Data() // Clear the data object
    }
    
    /// Securely clear sensitive string from memory
    func secureClear(_ string: inout String) {
        // Convert to mutable data and clear
        if var data = string.data(using: .utf8) {
            secureClear(&data)
        }
        string = "" // Clear the string object
    }
    
    // MARK: - Debug
    
    func verifyIdentityKeyExists() -> Bool {
        let key = "identity_noiseStaticKey"
        return retrieveData(forKey: key) != nil
    }
}
