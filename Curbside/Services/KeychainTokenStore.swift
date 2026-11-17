import Foundation
import Security

struct KeychainError: Error, Equatable {
    let status: OSStatus
}

struct KeychainTokenStore: Sendable {
    var service = "com.Xomware.Curbside.tokens"

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: "cognito"]
    }

    func save(_ tokens: Tokens) throws {
        let data = try JSONEncoder().encode(tokens)
        try delete()
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    func load() throws -> Tokens? {
        var lookup = query
        lookup[kSecReturnData as String] = true
        var result: AnyObject?
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainError(status: status) }
        return try JSONDecoder().decode(Tokens.self, from: data)
    }

    func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }
}
