import CoreLocation
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

    func testCard() throws {
        let app = launch("street")
        let plaque = app.buttons["11, Pumpernickel household"]
        XCTAssert(plaque.waitForExistence(timeout: 10))
        plaque.tap()
        XCTAssert(app.staticTexts["Clementine's mom is staying through Thanksgiving."].waitForExistence(timeout: 5))
        try snap("card", app)
        app.swipeUp()
        try snap("card-scrolled", app)
    }

    func testSelection() throws {
        let app = launch("street")
        let duplex = app.buttons["10A, Hobnob household"]
        XCTAssert(duplex.waitForExistence(timeout: 10))
        // Just left of the plaque: still the duplex outline, but not the plaque button.
        duplex.coordinate(withNormalizedOffset: CGVector(dx: -0.4, dy: 0.3)).tap()
        XCTAssert(app.buttons["Close"].waitForExistence(timeout: 5))
        try snap("building-selected", app)
        app.buttons["10B, Wigglesworth household"].firstMatch.tap()
        XCTAssert(app.staticTexts["Delphine"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["Close"].tap()
        app.maps.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.62)).press(forDuration: 1)
        XCTAssert(app.staticTexts["Nobody added here yet."].waitForExistence(timeout: 5))
        try snap("pin-dropped", app)
        app.buttons["Add a household here"].tap()
        let name = app.textFields["Family or household name"]
        XCTAssert(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Newcombe")
        try snap("add-household", app)
        app.buttons["Add them"].tap()
        XCTAssert(app.staticTexts["Newcombe"].waitForExistence(timeout: 5))
        try snap("added-card", app)
    }

    /// Needs location granted first: `xcrun simctl privacy <device> grant location com.Xomware.Curbside`.
    func testPlaceSetup() throws {
        XCUIDevice.shared.location = XCUILocation(location: CLLocation(latitude: 37.4475, longitude: -122.1395))
        let app = launch("new")
        XCTAssert(app.staticTexts["New place"].waitForExistence(timeout: 10))
        try snap("setup", app)
        app.buttons["Use my location"].tap()
        XCTAssert(app.textFields["Place name"].waitForExistence(timeout: 10))
        try snap("setup-located", app)
        app.buttons["Make the map"].tap()
        XCTAssert(app.buttons["Map options"].waitForExistence(timeout: 10))
        try snap("setup-created", app)
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
