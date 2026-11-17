import Foundation
import Testing
@testable import Curbside

@Test func apiBaseURLComesFromBuildSettings() {
    #expect(Config.apiBaseURL == URL(string: "https://api.curbside.xomware.com"))
}
