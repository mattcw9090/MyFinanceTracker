import XCTest

final class MyFinanceTrackerUITests: XCTestCase {
    
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        // Perform any cleanup after tests
    }
    
    func testTabBarItemsExist() throws {
        // Check if the tab bar items are visible
        let netIncomeTab = app.buttons["Net Income"]
        let cashFlowTab = app.buttons["Cash Flow"]
        let settingsTab = app.buttons["Settings"]
        
        XCTAssertTrue(netIncomeTab.exists, "The 'Net Income' tab should exist.")
        XCTAssertTrue(cashFlowTab.exists, "The 'Cash Flow' tab should exist.")
        XCTAssertTrue(settingsTab.exists, "The 'Settings' tab should exist.")
    }

    func testSwitchingTabsAndElements() throws {
        let netIncomeTab = app.buttons["Net Income"]
        let cashFlowTab = app.buttons["Cash Flow"]
        let settingsTab = app.buttons["Settings"]

        // Test: "Net Income" tab by default should be selected first when app is launched
        XCTAssertTrue(app.staticTexts["Net Income:"].exists, "Net Income view should display 'Net Income:' label.")

        // Test: Select "Cash Flow" tab
        cashFlowTab.tap()
        XCTAssertTrue(app.navigationBars["Cash Flow"].exists, "Cash Flow view should display a navigation bar titled 'Cash Flow'.")

        // Test: Select "Settings" tab
        settingsTab.tap()
        XCTAssertTrue(app.navigationBars["Settings"].exists, "Settings view should display a navigation bar titled 'Settings'.")

        // Test: Switch back to the Net Income tab and re-verify the net income text
        netIncomeTab.tap()
        XCTAssertTrue(app.staticTexts["Net Income:"].exists, "Should be able to switch back and still see 'Net Income:' in the Net Income view.")
    }
}
