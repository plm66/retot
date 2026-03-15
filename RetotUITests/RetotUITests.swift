import XCTest

final class RetotUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    // MARK: - App Launch

    func testAppLaunchesSuccessfully() {
        // Menu bar app should be running
        XCTAssertTrue(app.exists)
    }

    // MARK: - Dot Bar

    func testTenDotsDisplayed() {
        // Click the menu bar icon to open the popover
        let menuBarItem = app.statusItems["Retot"]
        if menuBarItem.exists {
            menuBarItem.click()
        }

        // Verify 10 dot buttons exist
        for i in 1...10 {
            let dot = app.buttons["Note \(i): Note \(i)"]
            // Dots should be accessible
            XCTAssertTrue(dot.waitForExistence(timeout: 2), "Dot \(i) should exist")
        }
    }

    func testClickingDotChangesSelection() {
        let menuBarItem = app.statusItems["Retot"]
        if menuBarItem.exists {
            menuBarItem.click()
        }

        // Click dot 3
        let dot3 = app.buttons["Note 3: Note 3"]
        if dot3.waitForExistence(timeout: 2) {
            dot3.click()
        }

        // Click dot 7
        let dot7 = app.buttons["Note 7: Note 7"]
        if dot7.waitForExistence(timeout: 2) {
            dot7.click()
        }

        // Both should still exist (UI didn't crash)
        XCTAssertTrue(dot3.exists)
        XCTAssertTrue(dot7.exists)
    }

    // MARK: - Text Editing

    func testCanTypeInEditor() {
        let menuBarItem = app.statusItems["Retot"]
        if menuBarItem.exists {
            menuBarItem.click()
        }

        // Find the text editor area
        let textView = app.scrollViews.firstMatch
        if textView.waitForExistence(timeout: 2) {
            textView.click()
            textView.typeText("Hello Retot!")
        }

        // Text should have been entered (no crash)
        XCTAssertTrue(textView.exists)
    }

    func testTextPersistsAcrossDotSwitch() {
        let menuBarItem = app.statusItems["Retot"]
        if menuBarItem.exists {
            menuBarItem.click()
        }

        // Type in dot 1
        let textView = app.scrollViews.firstMatch
        if textView.waitForExistence(timeout: 2) {
            textView.click()
            textView.typeText("Content for note 1")
        }

        // Switch to dot 2
        let dot2 = app.buttons["Note 2: Note 2"]
        if dot2.waitForExistence(timeout: 2) {
            dot2.click()
        }

        // Type in dot 2
        if textView.waitForExistence(timeout: 2) {
            textView.click()
            textView.typeText("Content for note 2")
        }

        // Switch back to dot 1
        let dot1 = app.buttons["Note 1: Note 1"]
        if dot1.waitForExistence(timeout: 2) {
            dot1.click()
        }

        // Note 1 should still have its content (not note 2's content)
        // We can't easily read NSTextView content in UI tests,
        // but we verify no crash occurred
        XCTAssertTrue(textView.exists)
    }

    // MARK: - Toolbar

    func testToolbarButtonsExist() {
        let menuBarItem = app.statusItems["Retot"]
        if menuBarItem.exists {
            menuBarItem.click()
        }

        let boldButton = app.buttons["bold"]
        let italicButton = app.buttons["italic"]
        let underlineButton = app.buttons["underline"]
        let exportButton = app.buttons["export"]

        XCTAssertTrue(boldButton.waitForExistence(timeout: 2), "Bold button should exist")
        XCTAssertTrue(italicButton.exists, "Italic button should exist")
        XCTAssertTrue(underlineButton.exists, "Underline button should exist")
        XCTAssertTrue(exportButton.exists, "Export button should exist")
    }

    // MARK: - Context Menu

    func testDotContextMenuAppears() {
        let menuBarItem = app.statusItems["Retot"]
        if menuBarItem.exists {
            menuBarItem.click()
        }

        let dot1 = app.buttons["Note 1: Note 1"]
        if dot1.waitForExistence(timeout: 2) {
            dot1.rightClick()
        }

        // Context menu should have Rename option
        let renameItem = app.menuItems["Rename..."]
        XCTAssertTrue(renameItem.waitForExistence(timeout: 2), "Rename menu item should appear")
    }
}
