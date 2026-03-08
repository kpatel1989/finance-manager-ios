import XCTest

final class Finance_ManagerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsPrimaryTabs() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Dashboard"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Accounts"].exists)
        XCTAssertTrue(app.tabBars.buttons["Planner"].exists)
        XCTAssertTrue(app.tabBars.buttons["Tools"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
    }
}
