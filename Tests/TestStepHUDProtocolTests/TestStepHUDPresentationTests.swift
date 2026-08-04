import XCTest
@testable import TestStepHUDTestSupport

final class TestStepHUDPresentationTests: XCTestCase {
    func testFastProfileDisablesBothDelays() {
        let presentation = TestStepHUDPresentation.fast

        XCTAssertEqual(presentation.testCaseDuration, 0)
        XCTAssertEqual(presentation.interactionDelay, 0)
    }

    func testVisualProfileUsesRecordingDefaults() {
        let presentation = TestStepHUDPresentation.visual()

        XCTAssertEqual(presentation.testCaseDuration, 4)
        XCTAssertEqual(presentation.interactionDelay, 0.5)
    }

    func testMissingEnvironmentUsesFastProfile() {
        XCTAssertEqual(
            TestStepHUDPresentation.fromEnvironment([:]),
            .fast
        )
    }

    func testVisualEnvironmentUsesOverrides() {
        let presentation = TestStepHUDPresentation.fromEnvironment([
            "TESTSTEPHUD_MODE": "visual",
            "TESTSTEPHUD_CASE_DURATION": "6.5",
            "TESTSTEPHUD_INTERACTION_DELAY": "0.8"
        ])

        XCTAssertEqual(presentation.testCaseDuration, 6.5)
        XCTAssertEqual(presentation.interactionDelay, 0.8)
    }

    func testNonVisualModeIgnoresDelayOverrides() {
        let presentation = TestStepHUDPresentation.fromEnvironment([
            "TESTSTEPHUD_MODE": "fast",
            "TESTSTEPHUD_CASE_DURATION": "6",
            "TESTSTEPHUD_INTERACTION_DELAY": "1"
        ])

        XCTAssertEqual(presentation, .fast)
    }

    func testDurationsAreClamped() {
        let presentation = TestStepHUDPresentation(
            testCaseDuration: 100,
            interactionDelay: -1
        )

        XCTAssertEqual(presentation.testCaseDuration, 60)
        XCTAssertEqual(presentation.interactionDelay, 0)
    }

    func testNonFiniteDurationsUseSafeValues() {
        let presentation = TestStepHUDPresentation(
            testCaseDuration: .nan,
            interactionDelay: .infinity
        )

        XCTAssertEqual(presentation.testCaseDuration, 0)
        XCTAssertEqual(presentation.interactionDelay, 5)
    }

    func testInvalidVisualEnvironmentUsesDefaults() {
        let presentation = TestStepHUDPresentation.fromEnvironment([
            "TESTSTEPHUD_MODE": "visual",
            "TESTSTEPHUD_CASE_DURATION": "nan",
            "TESTSTEPHUD_INTERACTION_DELAY": "infinity"
        ])

        XCTAssertEqual(presentation.testCaseDuration, 4)
        XCTAssertEqual(presentation.interactionDelay, 0.5)
    }
}
