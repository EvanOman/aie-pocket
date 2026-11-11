import XCTest

/// Uses two talks actually received from the paired companion. Before running,
/// select More Checks, Less Noise (1357875) and Notion Software Factory Debate
/// (notion), with no other selections, and let the watch receive them.
final class TalkNavigationTests: XCTestCase {
    @MainActor
    func testSwipeBetweenReceivedTalks() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()

        let anyPosition = app.staticTexts.matching(NSPredicate(format: "label IN %@", ["1/2", "2/2"])).firstMatch
        XCTAssertTrue(anyPosition.waitForExistence(timeout: 15), app.debugDescription)
        // Initial focus follows the current/next talk, so it can be the second
        // page while the conference is running. Normalize before the round trip.
        if app.staticTexts["2/2"].exists { app.swipeRight() }
        let firstPosition = app.staticTexts["1/2"]
        expectVisible(firstPosition, in: app)
        let firstTitle = app.staticTexts["More Checks, Less Noise: Layered Security for AI-Assisted Development"]
        XCTAssertTrue(firstTitle.isHittable, app.debugDescription)
        capture("01-first-card", app: app)

        app.swipeLeft()
        let secondPosition = app.staticTexts["2/2"]
        expectVisible(secondPosition, in: app)
        XCTAssertTrue(app.staticTexts["Notion Software Factory Debate"].isHittable, app.debugDescription)
        XCTAssertFalse(firstPosition.isHittable)
        capture("02-after-swipe-left", app: app)

        app.swipeRight()
        expectVisible(firstPosition, in: app)
        XCTAssertTrue(firstTitle.isHittable, app.debugDescription)
        XCTAssertFalse(secondPosition.isHittable)
        capture("03-after-swipe-right", app: app)
    }

    @MainActor
    private func expectVisible(_ element: XCUIElement, in app: XCUIApplication) {
        let visible = NSPredicate { _, _ in element.exists && element.isHittable }
        let expectation = XCTNSPredicateExpectation(predicate: visible, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed, app.debugDescription)
    }

    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
