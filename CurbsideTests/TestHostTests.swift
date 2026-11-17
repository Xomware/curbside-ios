import Foundation
import Testing

// Tests that read app resources (fonts, Info.plist keys) only work when hosted in the app.
@Test func testsRunInsideTheApp() {
    #expect(Bundle.main.bundleIdentifier == "com.Xomware.Curbside")
}
