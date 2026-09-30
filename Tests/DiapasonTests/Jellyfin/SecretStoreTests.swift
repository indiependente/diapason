@testable import Diapason
import Foundation
import Testing

@Suite("SecretStore")
struct SecretStoreTests {
    @Test("file store round-trips JSON and keeps the file owner-only")
    func fileStore() throws {
        // A space in the path mirrors "Application Support", which percent-encoded paths break on.
        let directory = URL.temporaryDirectory.appending(path: "diapason test \(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileSecretStore(directory: directory)
        #expect(try store.data(for: "missing") == nil)

        try store.setJSON(["token": "abc"], for: "credentials")
        #expect(try store.json([String: String].self, for: "credentials") == ["token": "abc"])
        let path = directory.appending(path: "credentials.json").path(percentEncoded: false)
        let permissions = try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? Int
        #expect(permissions == 0o600)

        try store.delete(key: "credentials")
        #expect(try store.data(for: "credentials") == nil)
        try store.delete(key: "credentials")
    }

    @Test("in-memory store round-trips and deletes")
    func inMemoryStore() throws {
        let store = InMemorySecretStore()
        try store.setData(Data("hello".utf8), for: "key")
        #expect(try store.data(for: "key") == Data("hello".utf8))
        try store.delete(key: "key")
        #expect(try store.data(for: "key") == nil)
    }
}
