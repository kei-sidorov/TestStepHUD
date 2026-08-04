import XCTest
import TestStepHUDProtocol
@testable import TestStepHUDTestSupport

final class TestStepHUDFailureObserverTests: XCTestCase {
    func testAssertionIssueBecomesFailurePayload() {
        let issue = XCTIssue(
            type: .assertionFailure,
            compactDescription: "XCTAssertTrue failed - Continue is missing",
            detailedDescription: nil,
            sourceCodeContext: XCTSourceCodeContext(
                location: XCTSourceCodeLocation(
                    filePath: "/private/project/CheckoutUITests.swift",
                    lineNumber: 42
                )
            ),
            associatedError: nil,
            attachments: []
        )

        XCTAssertEqual(
            HUDTestFailure(issue: issue),
            HUDTestFailure(
                title: "Assertion failed",
                message: "XCTAssertTrue failed - Continue is missing",
                location: "CheckoutUITests.swift:42"
            )
        )
    }

    func testIssueMessageIsTrimmedAndBounded() {
        let issue = XCTIssue(
            type: .system,
            compactDescription: "  \(String(repeating: "x", count: 2_100))  ",
            detailedDescription: nil,
            sourceCodeContext: XCTSourceCodeContext(),
            associatedError: nil,
            attachments: []
        )

        let failure = HUDTestFailure(issue: issue)

        XCTAssertEqual(failure.title, "XCTest error")
        XCTAssertEqual(failure.message.count, 2_000)
        XCTAssertNil(failure.location)
    }
}
