import Foundation
import Security

protocol KeychainStore: Sendable {
    func setData(_ data: Data, for key: String) throws
    func data(for key: String) throws -> Data?
    func delete(key: String) throws
}

extension KeychainStore {
    func setJSON(_ value: some Encodable, for key: String) throws {
        try setData(JSONEncoder().encode(value), for: key)
    }

    func json<T: Decodable>(_ type: T.Type, for key: String) throws -> T? {
        guard let data = try data(for: key) else {
            return nil
        }

        return try JSONDecoder().decode(type, from: data)
    }
}

struct KeychainError: Error {
    let status: OSStatus
}

struct LiveKeychainStore: KeychainStore {
    let service: String

    func setData(_ data: Data, for key: String) throws {
        try delete(key: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError(status: status)
        }
    }

    func data(for key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess: return item as? Data
        case errSecItemNotFound: return nil
        default: throw KeychainError(status: status)
        }
    }

    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }
}

final class InMemoryKeychainStore: KeychainStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]

    func setData(_ data: Data, for key: String) throws {
        lock.withLock { storage[key] = data }
    }

    func data(for key: String) throws -> Data? {
        lock.withLock { storage[key] }
    }

    func delete(key: String) throws {
        _ = lock.withLock { storage.removeValue(forKey: key) }
    }
}
