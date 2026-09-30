import Foundation

/// Where the session token lives.
protocol SecretStore: Sendable {
    func setData(_ data: Data, for key: String) throws
    func data(for key: String) throws -> Data?
    func delete(key: String) throws
}

extension SecretStore {
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

/// Owner-only files in Application Support. The Keychain would ask for permission after every
/// rebuild, because an ad-hoc signed app gets a new code signature each time.
struct FileSecretStore: SecretStore {
    let directory: URL

    static let `default` = FileSecretStore(
        directory: URL.applicationSupportDirectory.appending(path: "Diapason", directoryHint: .isDirectory)
    )

    func setData(_ data: Data, for key: String) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try data.write(to: url(for: key), options: [.atomic, .completeFileProtection])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path(for: key))
    }

    func data(for key: String) throws -> Data? {
        guard FileManager.default.fileExists(atPath: path(for: key)) else {
            return nil
        }

        return try Data(contentsOf: url(for: key))
    }

    func delete(key: String) throws {
        if FileManager.default.fileExists(atPath: path(for: key)) {
            try FileManager.default.removeItem(at: url(for: key))
        }
    }

    private func url(for key: String) -> URL {
        directory.appending(path: "\(key).json")
    }

    /// `URL.path()` percent-encodes spaces ("Application%20Support"), which FileManager does not accept.
    private func path(for key: String) -> String {
        url(for: key).path(percentEncoded: false)
    }
}

final class InMemorySecretStore: SecretStore, @unchecked Sendable {
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
