import Foundation

/// Jellyfin sends PascalCase keys. These coders map them to lowerCamelCase properties.
extension JSONDecoder {
    static let jellyfin: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .custom { keys in
            let key = keys.last?.stringValue ?? ""

            return AnyKey(stringValue: key.prefix(1).lowercased() + key.dropFirst())
        }

        return decoder
    }()
}

extension JSONEncoder {
    static let jellyfin: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .custom { keys in
            let key = keys.last?.stringValue ?? ""

            return AnyKey(stringValue: key.prefix(1).uppercased() + key.dropFirst())
        }

        return encoder
    }()
}

private struct AnyKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue _: Int) {
        nil
    }
}
