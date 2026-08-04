import XCTest
@testable import TestStepHUDTestSupport

final class TestStepHUDPresentationTests: XCTestCase {
    func testFastProfileAvoidsSuccessfulRunDelays() {
        let presentation = TestStepHUDPresentation.fast

        XCTAssertEqual(presentation.testCaseDuration, 0)
        XCTAssertEqual(presentation.interactionDelay, 0)
        XCTAssertEqual(presentation.failureDuration, 3)
    }

    func testVisualProfileUsesRecordingDefaults() {
        let presentation = TestStepHUDPresentation.visual()

        XCTAssertEqual(presentation.testCaseDuration, 4)
        XCTAssertEqual(presentation.interactionDelay, 0.5)
        XCTAssertEqual(presentation.failureDuration, 3)
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
            "TESTSTEPHUD_INTERACTION_DELAY": "0.8",
            "TESTSTEPHUD_FAILURE_DURATION": "4.5"
        ])

        XCTAssertEqual(presentation.testCaseDuration, 6.5)
        XCTAssertEqual(presentation.interactionDelay, 0.8)
        XCTAssertEqual(presentation.failureDuration, 4.5)
    }

    func testNonVisualModeIgnoresDelayOverrides() {
        let presentation = TestStepHUDPresentation.fromEnvironment([
            "TESTSTEPHUD_MODE": "fast",
            "TESTSTEPHUD_CASE_DURATION": "6",
            "TESTSTEPHUD_INTERACTION_DELAY": "1"
        ])

        XCTAssertEqual(presentation, .fast)
    }

    func testFastEnvironmentCanOverrideFailureDuration() {
        let presentation = TestStepHUDPresentation.fromEnvironment([
            "TESTSTEPHUD_FAILURE_DURATION": "1.5"
        ])

        XCTAssertEqual(presentation.testCaseDuration, 0)
        XCTAssertEqual(presentation.interactionDelay, 0)
        XCTAssertEqual(presentation.failureDuration, 1.5)
    }

    func testDurationsAreClamped() {
        let presentation = TestStepHUDPresentation(
            testCaseDuration: 100,
            interactionDelay: -1,
            failureDuration: 100
        )

        XCTAssertEqual(presentation.testCaseDuration, 60)
        XCTAssertEqual(presentation.interactionDelay, 0)
        XCTAssertEqual(presentation.failureDuration, 60)
    }

    func testNonFiniteDurationsUseSafeValues() {
        let presentation = TestStepHUDPresentation(
            testCaseDuration: .nan,
            interactionDelay: .infinity,
            failureDuration: .nan
        )

        XCTAssertEqual(presentation.testCaseDuration, 0)
        XCTAssertEqual(presentation.interactionDelay, 5)
        XCTAssertEqual(presentation.failureDuration, 0)
    }

    func testInvalidVisualEnvironmentUsesDefaults() {
        let presentation = TestStepHUDPresentation.fromEnvironment([
            "TESTSTEPHUD_MODE": "visual",
            "TESTSTEPHUD_CASE_DURATION": "nan",
            "TESTSTEPHUD_INTERACTION_DELAY": "infinity",
            "TESTSTEPHUD_FAILURE_DURATION": "nan"
        ])

        XCTAssertEqual(presentation.testCaseDuration, 4)
        XCTAssertEqual(presentation.interactionDelay, 0.5)
        XCTAssertEqual(presentation.failureDuration, 3)
    }
}
