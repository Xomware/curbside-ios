import Foundation
import Testing
@testable import Curbside

@Test func keychainRoundTrip() throws {
    let store = KeychainTokenStore(service: "com.Xomware.CurbsideTests.\(UUID())")
    let tokens = Tokens(access: "a", id: "i", refresh: "r")

    #expect(try store.load() == nil)
    try store.save(tokens)
    #expect(try store.load() == tokens)

    let rotated = Tokens(access: "a2", id: "i2", refresh: "r")
    try store.save(rotated)
    #expect(try store.load() == rotated)

    try store.delete()
    #expect(try store.load() == nil)
}
