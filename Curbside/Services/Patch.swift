/// A PATCH body: the item's `version` plus only the fields that changed. `.null` clears a field; a field left out
/// stays as it is. Swift's synthesized `Encodable` drops nil optionals, which can't express "clear", hence this.
struct Patch: Encodable, Sendable, Equatable {
    enum Value: Encodable, Sendable, Equatable {
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
        case null

        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let value): try container.encode(value)
            case .int(let value): try container.encode(value)
            case .double(let value): try container.encode(value)
            case .bool(let value): try container.encode(value)
            case .null: try container.encodeNil()
            }
        }
    }

    let version: Int
    var fields: [String: Value] = [:]

    var isEmpty: Bool { fields.isEmpty }

    /// Adds `key` only when `new` differs from `old`.
    mutating func set<T: Equatable>(_ key: String, _ old: T, _ new: T, as value: (T) -> Value) {
        if old != new { fields[key] = value(new) }
    }

    private struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(version, forKey: Key(stringValue: "version"))
        for (key, value) in fields {
            try container.encode(value, forKey: Key(stringValue: key))
        }
    }
}

extension Patch.Value {
    static func nullable(_ value: String?) -> Patch.Value { value.map(Patch.Value.string) ?? .null }
    static func nullable(_ value: Int?) -> Patch.Value { value.map(Patch.Value.int) ?? .null }
}

/// Capture ops carry fields of mixed types; JSON `true` never decodes as an Int, so the order here is safe.
extension Patch.Value: Decodable {
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    var text: String? {
        if case .string(let value) = self { value } else { nil }
    }
}
