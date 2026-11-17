import XCTest

/// Walks each screen in `-demo` mode and writes a PNG per screen.
/// Run: `TEST_RUNNER_SCREENSHOT_DIR=/some/dir TEST_RUNNER_APPEARANCE=dark xcodebuild test -scheme Screenshots ...`
@MainActor
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testMap() throws {
        let app = launch("street")
        XCTAssert(app.staticTexts["Quillfeather Ln"].waitForExistence(timeout: 10))
        try snap("map", app)
        app.maps.firstMatch.pinch(withScale: 3, velocity: 2)
        try snap("map-zoomed", app)
    }

    func testMapWithNoPlace() throws {
        let app = launch("new")
        XCTAssert(app.staticTexts["New place"].waitForExistence(timeout: 10))
        try snap("no-place", app)
    }

    func launch(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", scenario]
        app.launch()
        return app
    }

    /// Writes `<name>-<TEST_RUNNER_APPEARANCE>.png`. Switching appearance mid-run left MapKit tiles light, so the
    /// caller sets it per run with `xcrun simctl ui <device> appearance dark`. Tiles render late; wait a beat.
    func snap(_ name: String, _ app: XCUIApplication) throws {
        let env = ProcessInfo.processInfo.environment
        let dir = try XCTUnwrap(env["SCREENSHOT_DIR"], "set TEST_RUNNER_SCREENSHOT_DIR")
        Thread.sleep(forTimeInterval: 2.5)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try png.write(to: URL(fileURLWithPath: dir).appending(path: "\(name)-\(env["APPEARANCE"] ?? "light").png"))
    }
}
