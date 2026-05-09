import XCTest

final class DittyUITests: XCTestCase {

    /// Smoke check: the new layout shows DITTY title + camera controls. Camera permission
    /// in the simulator surfaces a system alert; we dismiss it and confirm the controls exist.
    func testLaunchAndChrome() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-DisableCamera", "-SkipSplash", "-SkipOnboarding"]
        app.launch()

        // Splash plays for ~2s — let it finish before we look for chrome.
        XCTAssertTrue(app.staticTexts["DITTY"].waitForExistence(timeout: 8))

        XCTAssertTrue(app.buttons["Upload from gallery"].exists)
        XCTAssertTrue(app.buttons["Settings"].exists)
        XCTAssertTrue(app.buttons["Effects"].exists)
        XCTAssertTrue(app.buttons["Switch camera"].exists)
        // Capture when live; Save when viewing a still.
        XCTAssertTrue(app.buttons["Capture"].exists || app.buttons["Save"].exists)

        let png = app.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "/tmp/ditty-launch.png"))
    }

    /// Settings tap toggles the inline effect editor (no covering sheet).
    func testEffectEditorOpens() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-DisableCamera", "-SkipSplash", "-SkipOnboarding"]
        app.launch()
        XCTAssertTrue(app.staticTexts["DITTY"].waitForExistence(timeout: 8))

        // The bottom-left FX button now opens the inline editor.
        app.buttons["Effects"].tap()
        XCTAssertTrue(app.buttons["Done editing"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Cancel edits"].exists)
        let png = app.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "/tmp/ditty-editor.png"))

        // Done collapses the editor back to the bottom bar.
        app.buttons["Done editing"].tap()
        XCTAssertTrue(app.buttons["Capture"].waitForExistence(timeout: 3) ||
                      app.buttons["Save"].exists)
    }
}
