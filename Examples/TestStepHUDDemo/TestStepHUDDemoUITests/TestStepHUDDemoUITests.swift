import XCTest
import TestStepHUDTestSupport

final class TestStepHUDDemoUITests: XCTestCase {
    @MainActor
    func testRecordedCheckoutFlowShowsReadableSteps() {
        continueAfterFailure = false

        let app = XCUIApplication()
        let hud = app.launchWithTestStepHUD(timeout: 10)

        addTeardownBlock {
            hud.cancel()
        }

        hud.step("1 of 3 · Find the Continue button")
        XCTAssertTrue(
            app.buttons["continueButton"].waitForExistence(timeout: 5)
        )
        keepStepReadableAndAttachScreenshot(
            named: "01-find-continue"
        )

        hud.step("2 of 3 · Tap Continue")
        app.buttons["continueButton"].tap()
        keepStepReadableAndAttachScreenshot(
            named: "02-tap-continue"
        )

        hud.step("3 of 3 · Verify order confirmation")
        XCTAssertTrue(
            app.staticTexts["Order confirmed"].waitForExistence(timeout: 5)
        )
        waitAndAttachScreenshot(
            named: "03-follow-position",
            delay: 0.5
        )
        waitAndAttachScreenshot(
            named: "04-idle-return-home",
            delay: 3.4
        )

        hud.hide()
    }

    @MainActor
    func testRecordedCommonInteractionsAreVisualized() {
        continueAfterFailure = false

        let app = XCUIApplication()
        let hud = app.launchWithTestStepHUD(timeout: 10)
        addTeardownBlock {
            hud.cancel()
        }

        let title = app.staticTexts["demoTitle"]
        let item = app.staticTexts["itemLabel"]
        let noteField = app.textFields["noteField"]

        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        XCTAssertTrue(noteField.waitForExistence(timeout: 5))

        hud.step("1 of 6 · Type in the note field") {
            noteField.tap()
            noteField.typeText("Sample note")
            noteField.typeText(XCUIKeyboardKey.return.rawValue)
            waitAndAttachScreenshot(
                named: "interactions-01-typing",
                delay: 0.7
            )
        }

        hud.step("2 of 6 · Swipe up on a compact element") {
            app.staticTexts["priceLabel"].swipeUp()
            waitAndAttachScreenshot(
                named: "interactions-02-swipe",
                delay: 0.7
            )
        }

        hud.step("3 of 6 · Long press the title") {
            title.press(forDuration: 0.8)
            waitAndAttachScreenshot(
                named: "interactions-03-long-press",
                delay: 0.7
            )
        }

        hud.step("4 of 6 · Drag the item to the title") {
            item.press(forDuration: 0.4, thenDragTo: title)
            waitAndAttachScreenshot(
                named: "interactions-04-drag",
                delay: 0.7
            )
        }

        hud.step("5 of 6 · Tap a screen coordinate") {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.55)).tap()
            waitAndAttachScreenshot(
                named: "interactions-05-coordinate-tap",
                delay: 0.7
            )
        }

        hud.step("6 of 6 · Double tap the title") {
            title.doubleTap()
            waitAndAttachScreenshot(
                named: "interactions-06-double-tap",
                delay: 0.7
            )
        }

        hud.hide()
    }

    @MainActor
    func testRejectsSecondActiveHUDSession() {
        continueAfterFailure = false

        let firstApplication = XCUIApplication()
        let firstSession = firstApplication.launchWithTestStepHUD(
            timeout: 10
        )
        addTeardownBlock {
            firstSession.cancel()
        }

        let secondApplication = XCUIApplication()
        let secondSession = secondApplication.launchWithTestStepHUD(timeout: 10)
        XCTAssertFalse(secondSession.isAvailable)
        guard case .sessionAlreadyActive = secondSession.startupError else {
            XCTFail("Expected the second HUD session to be unavailable.")
            return
        }

        firstSession.cancel()
    }

    @MainActor
    private func keepStepReadableAndAttachScreenshot(named name: String) {
        waitAndAttachScreenshot(named: name, delay: 1.25)
    }

    @MainActor
    private func waitAndAttachScreenshot(
        named name: String,
        delay: TimeInterval
    ) {
        Thread.sleep(forTimeInterval: delay)
        let attachment = XCTAttachment(
            screenshot: XCUIScreen.main.screenshot()
        )
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
