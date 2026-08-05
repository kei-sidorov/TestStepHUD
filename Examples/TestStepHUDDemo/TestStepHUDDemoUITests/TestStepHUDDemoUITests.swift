import XCTest
import TestStepHUDTestSupport

final class TestStepHUDDemoUITests: XCTestCase {
    @MainActor
    func testRecordedCheckoutFlowShowsReadableSteps() {
        continueAfterFailure = demonstratesFailureCard

        let app = XCUIApplication()
        let hud = app.launchWithTestStepHUD(
            timeout: 10,
            presentation: .visual(
                testCaseDuration: 3.5,
                interactionDelay: 0.65,
                failureDuration: 4
            )
        )

        addTeardownBlock {
            hud.cancel()
        }
        requireAvailableHUD(hud)

        hud.testCase(
            "Checkout finishes with the expected status",
            steps: [
                "Add a delivery note",
                "Confirm the order",
                "Verify the final status"
            ]
        )

        let noteField = app.textFields["noteField"]
        let confirmButton = app.buttons["continueButton"]
        let checkoutStatus = app.staticTexts["checkoutStatus"]

        XCTAssertTrue(noteField.waitForExistence(timeout: 5))
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        XCTAssertTrue(checkoutStatus.waitForExistence(timeout: 5))

        hud.step("1 of 3 · Add a delivery note") {
            noteField.tap()
            noteField.typeText("Leave at reception")
            noteField.typeText(XCUIKeyboardKey.return.rawValue)
            keepStepReadableAndAttachScreenshot(
                named: "01-delivery-note"
            )
        }

        hud.step("2 of 3 · Confirm the order") {
            confirmButton.tap()
            keepStepReadableAndAttachScreenshot(
                named: "02-confirm-order"
            )
        }

        hud.step("3 of 3 · Verify the final status")
        let expectedStatus = demonstratesFailureCard
            ? "Payment complete"
            : "Order confirmed"
        XCTAssertEqual(
            checkoutStatus.label,
            expectedStatus,
            "Checkout should show the final payment status."
        )
        guard !demonstratesFailureCard else { return }
        keepStepReadableAndAttachScreenshot(named: "03-final-status")

        hud.hide()
    }

    @MainActor
    func testRecordedCommonInteractionsAreVisualized() {
        continueAfterFailure = false

        let app = XCUIApplication()
        let hud = app.launchWithTestStepHUD(
            timeout: 10,
            presentation: .visual(testCaseDuration: 0)
        )
        addTeardownBlock {
            hud.cancel()
        }
        requireAvailableHUD(hud)

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
    private func requireAvailableHUD(_ hud: TestStepHUDSession) {
        XCTAssertTrue(
            hud.isAvailable,
            hud.startupError?.localizedDescription ??
                "The TestStepHUD session is unavailable."
        )
    }

    private var demonstratesFailureCard: Bool {
        #if TESTSTEPHUD_DEMO_FAILURE
        true
        #else
        false
        #endif
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
