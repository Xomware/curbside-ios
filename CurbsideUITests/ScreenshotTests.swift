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
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Juniper'")).firstMatch.tap()
        XCTAssert(app.navigationBars["Edit Juniper"].waitForExistence(timeout: 5))
        try snap("edit-person", app)
        app.buttons["Cancel"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Waffles'")).firstMatch.tap()
        XCTAssert(app.navigationBars["Edit Waffles"].waitForExistence(timeout: 5))
        try snap("edit-pet", app)
        app.buttons["Cancel"].tap()
        app.buttons["Add a note"].tap()
        let note = app.textFields["What did you learn?"]
        XCTAssert(note.waitForExistence(timeout: 5))
        note.tap()
        note.typeText("Their geode is from Arizona.")
        try snap("new-note", app)
    }

    /// The picker runs out of process, so the snap is all there is to check.
    func testContacts() throws {
        let app = launch("street")
        let plaque = app.buttons["11, Pumpernickel household"]
        XCTAssert(plaque.waitForExistence(timeout: 10))
        plaque.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Clementine'")).firstMatch.tap()
        XCTAssert(app.navigationBars["Edit Clementine"].waitForExistence(timeout: 5))
        app.swipeUp()
        XCTAssert(app.buttons["Share contact card"].waitForExistence(timeout: 5))
        try snap("person-contact", app)
        app.swipeDown()
        app.buttons["Import from Contacts"].tap()
        try snap("contact-picker", app)
        app.staticTexts["Kate Bell"].tap()
        XCTAssert(app.textFields["Name"].waitForExistence(timeout: 5))
        try snap("contact-imported", app)
    }

    /// Walk a route first for LEFT/RIGHT (the simulator has no compass, so course stands in):
    /// `xcrun simctl location <device> start --speed=1.4 37.4470,-122.1393 37.4482,-122.1393`
    func testNearMe() throws {
        let app = launch("street")
        let button = app.buttons["Near me"]
        XCTAssert(button.waitForExistence(timeout: 10))
        button.tap()
        XCTAssert(app.staticTexts["Next houses"].waitForExistence(timeout: 5))
        XCTAssert(app.buttons.matching(NSPredicate(format: "label CONTAINS ' M'")).firstMatch.waitForExistence(timeout: 10))
        try snap("near-me", app)
        app.swipeUp()
        try snap("near-me-large", app)
    }

    func testSelection() throws {
        let app = launch("street")
        XCTAssert(app.buttons["11, Pumpernickel household"].waitForExistence(timeout: 10))
        // The duplex opens at the screen's right edge; bring it in.
        let map = app.maps.firstMatch
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: map.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.5)))
        let duplex = app.buttons["10A, Hobnob household"]
        XCTAssert(duplex.waitForExistence(timeout: 10))
        // Just below the plaque: still the duplex outline, but not the plaque button.
        duplex.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 1.5)).tap()
        XCTAssert(app.buttons["Close"].waitForExistence(timeout: 5))
        try snap("building-selected", app)
        app.buttons["10B, Wigglesworth household"].firstMatch.tap()
        XCTAssert(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Delphine'")).firstMatch.waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["Close"].tap()
        try snap("before-tap", app)
        app.maps.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.62)).tap()
        XCTAssert(app.staticTexts["Nobody added here yet. Tap the map to move the pin."].waitForExistence(timeout: 5))
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

    /// A plaque sits on top of the map, so its tap must not also reach the map's tap and drop a pin.
    func testPlaqueTapDropsNoPin() throws {
        let app = launch("street")
        let plaque = app.buttons["11, Pumpernickel household"]
        XCTAssert(plaque.waitForExistence(timeout: 10))
        plaque.tap()
        XCTAssert(app.staticTexts["Clementine's mom is staying through Thanksgiving."].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssert(app.buttons["Add a house"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Close"].exists)
        try snap("back-from-card", app)
    }

    func testAddAHouse() throws {
        let app = launch("street")
        let add = app.buttons["Add a house"]
        XCTAssert(add.waitForExistence(timeout: 10))
        add.tap()
        XCTAssert(app.buttons["Add a household here"].waitForExistence(timeout: 5))
        try snap("add-a-house", app)
        app.buttons["Close"].tap()
        app.maps.firstMatch.swipeLeft()
        app.buttons["Recenter the map"].tap()
        try snap("recentered", app)
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
        XCTAssert(app.buttons["More"].waitForExistence(timeout: 10))
        try snap("setup-created", app)
    }

    /// The simulator has no on-device speech model, so this types and also shows the voice-unavailable message.
    /// Needs location granted first, like `testPlaceSetup`.
    func testCapture() throws {
        XCUIDevice.shared.location = XCUILocation(location: CLLocation(latitude: 37.4475, longitude: -122.1395))
        let app = launch("street")
        let talk = app.buttons["Talk: capture by voice or text"]
        XCTAssert(talk.waitForExistence(timeout: 10))
        talk.tap()
        let field = app.textFields["What happened"]
        XCTAssert(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Ran into Clementine Pumpernickel walking Waffles. Odo just turned five and starts kindergarten in the fall. Marguerite next door got a second cat named Pickles. Looks like a new family moved into the yellow house, the mom is Wren. Also the guy with the red truck asked about the block party.")
        app.buttons["Talk"].tap()
        XCTAssert(app.staticTexts["Voice isn't available on this iPhone. Type it instead."].waitForExistence(timeout: 5))
        try snap("capture-input", app)
        app.buttons["Read it"].tap()
        XCTAssert(app.staticTexts["CHANGES AHEAD"].waitForExistence(timeout: 10))
        try snap("capture-review", app)
        app.swipeUp()
        try snap("capture-review-scrolled", app)
        app.buttons["Edit: Wren, adult"].tap()
        let name = app.textFields["Name"]
        XCTAssert(name.waitForExistence(timeout: 5))
        name.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        name.typeText("n")
        try snap("capture-edit", app)
        app.buttons["Done"].tap()
        XCTAssert(app.staticTexts["Wrenn, adult"].waitForExistence(timeout: 5))
        app.buttons["Place it on the map"].tap()
        XCTAssert(app.buttons["Put it here"].waitForExistence(timeout: 5))
        app.maps.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.62)).tap()
        try snap("capture-place", app)
        app.buttons["Put it here"].tap()
        let save = app.buttons["Save 4 changes"]
        XCTAssert(save.waitForExistence(timeout: 5))
        try snap("capture-placed", app)
        save.tap()
        XCTAssert(talk.waitForExistence(timeout: 10))
        try snap("capture-saved", app)
    }

    /// Needs Face ID enrolled in the simulator; the test runner then answers the prompt with a match notification:
    /// `xcrun simctl spawn <device> notifyutil -s com.apple.BiometricKit.enrollmentChanged 1` and `-p` the same name.
    func testLock() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "street", "-lock"]
        app.launch()
        XCTAssert(app.buttons["Unlock"].waitForExistence(timeout: 10))
        try snap("locked", app)
    }

    func testOnboarding() throws {
        let app = launch("onboarding")
        XCTAssert(app.staticTexts["New here"].waitForExistence(timeout: 10))
        try snap("onboarding", app)
    }

    func testSettings() throws {
        let app = launch("street")
        let more = app.buttons["More"]
        XCTAssert(more.waitForExistence(timeout: 10))
        more.tap()
        try snap("more-menu", app)
        app.buttons["Settings"].tap()
        XCTAssert(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        try snap("settings", app)
        app.buttons["Remove"].tap()
        XCTAssert(app.staticTexts["Remove Apple sign-in?"].waitForExistence(timeout: 5))
        try snap("settings-remove", app)
        // iOS 26 shows the dialog as a popover with no Cancel; tapping outside dismisses it.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)).tap()
        app.swipeUp()
        try snap("settings-scrolled", app)
        app.buttons["Export my data"].tap()
        // The share sheet runs out of process, so there's nothing in it to wait on; snap() waits a beat.
        try snap("settings-export", app)
        app.swipeDown(velocity: .fast)
        let delete = app.buttons["Delete account"]
        XCTAssert(delete.waitForExistence(timeout: 5))
        delete.tap()
        XCTAssert(app.staticTexts["Delete your account?"].waitForExistence(timeout: 5))
        try snap("settings-delete", app)
    }

    func testActivity() throws {
        let app = launch("street")
        let bell = app.buttons["Activity, 2 new"]
        XCTAssert(bell.waitForExistence(timeout: 10))
        try snap("activity-badge", app)
        bell.tap()
        XCTAssert(app.staticTexts["You and Odette are friends"].waitForExistence(timeout: 5))
        try snap("activity", app)
        app.buttons["Done"].tap()
        XCTAssert(app.buttons["Activity"].waitForExistence(timeout: 5))
        app.buttons["More"].tap()
        app.buttons["Settings"].tap()
        XCTAssert(app.switches["Weekly hello reminder"].waitForExistence(timeout: 5))
        try snap("settings-notifications", app)
    }

    func testSharing() throws {
        let app = launch("street")
        let more = app.buttons["More"]
        XCTAssert(more.waitForExistence(timeout: 10))
        more.tap()
        app.buttons["Sharing"].tap()
        XCTAssert(app.staticTexts["Rosalind"].waitForExistence(timeout: 5))
        try snap("sharing", app)
        app.buttons["Invite someone"].tap()
        XCTAssert(app.buttons["Share invite link"].waitForExistence(timeout: 5))
        try snap("sharing-invite", app)
        app.buttons["Remove Rosalind"].tap()
        XCTAssert(app.staticTexts["Remove Rosalind?"].waitForExistence(timeout: 5))
        try snap("sharing-remove", app)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)).tap()
        app.buttons["Done"].tap()

        more.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Bramblewick Ct'")).firstMatch.tap()
        XCTAssert(app.staticTexts["Bramblewick Ct"].waitForExistence(timeout: 10))
        try snap("shared-street", app)
        more.tap()
        app.buttons["Sharing"].tap()
        XCTAssert(app.staticTexts["Odette"].waitForExistence(timeout: 5))
        try snap("sharing-member", app)
        app.buttons["Leave this street"].tap()
        XCTAssert(app.staticTexts["Leave Bramblewick Ct?"].waitForExistence(timeout: 5))
        try snap("sharing-leave", app)
    }

    func testFriends() throws {
        let app = launch("street")
        let more = app.buttons["More"]
        XCTAssert(more.waitForExistence(timeout: 10))
        more.tap()
        app.buttons["Friends"].tap()
        XCTAssert(app.staticTexts["Wendell"].waitForExistence(timeout: 5))
        try snap("friends", app)
        app.buttons["Make a friend link"].tap()
        XCTAssert(app.buttons["Share friend link"].waitForExistence(timeout: 5))
        try snap("friends-link", app)
        app.buttons["Done"].tap()

        more.tap()
        app.buttons["Sharing"].tap()
        let add = app.buttons["Add a friend"]
        XCTAssert(add.waitForExistence(timeout: 5))
        try snap("sharing-add-friend", app)
        add.tap()
        app.buttons["Wendell"].tap()
        XCTAssert(app.staticTexts["Wendell"].waitForExistence(timeout: 5))
        try snap("sharing-friend-added", app)
    }

    func testFriendLink() throws {
        let app = launch("street", "-friend", "4FRNDQ2K7M")
        let accept = app.buttons["Be friends"]
        XCTAssert(accept.waitForExistence(timeout: 10))
        try snap("friend-link", app)
        accept.tap()
        XCTAssert(app.staticTexts["You and Wendell are friends. Add them to a street from its sharing screen."].waitForExistence(timeout: 5))
        try snap("friend-link-accepted", app)

        app.terminate()
        let spent = launch("street", "-friend", "SPENT00000")
        XCTAssert(spent.staticTexts["Link used up"].waitForExistence(timeout: 10))
        try snap("friend-link-used-up", spent)
    }

    func testInvite() throws {
        let app = launch("street", "-invite", "7KQ2M9XH4D")
        let join = app.buttons["Join Bramblewick Ct"]
        XCTAssert(join.waitForExistence(timeout: 10))
        try snap("invite", app)
        join.tap()
        XCTAssert(app.staticTexts["Bramblewick Ct"].waitForExistence(timeout: 10))
        try snap("invite-joined", app)

        app.terminate()
        let spent = launch("street", "-invite", "SPENT00000")
        XCTAssert(spent.staticTexts["Invite used up"].waitForExistence(timeout: 10))
        try snap("invite-used-up", spent)
    }

    func launch(_ scenario: String, _ extra: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", scenario] + extra
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
