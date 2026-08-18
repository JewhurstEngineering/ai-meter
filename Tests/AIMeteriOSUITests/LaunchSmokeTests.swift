import XCTest

final class LaunchSmokeTests: XCTestCase {
    func testLaunchShowsRootTabs() {
        let app = XCUIApplication()
        app.launch()

        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 8), "Root tab bar should appear on launch")
        XCTAssertTrue(tabs.buttons["Overview"].exists)
        XCTAssertTrue(tabs.buttons["Accounts"].exists)
        XCTAssertTrue(tabs.buttons["Settings"].exists)
    }
}
