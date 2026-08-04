import Foundation
import XCTest
import TestStepHUDProtocol

final class TestStepHUDFailureObserver: NSObject, XCTestObservation {
    private weak var session: TestStepHUDSession?

    init(session: TestStepHUDSession) {
        self.session = session
    }

    func testCase(_ testCase: XCTestCase, didRecord issue: XCTIssue) {
        session?.presentFailure(HUDTestFailure(issue: issue))
    }
}

extension HUDTestFailure {
    init(issue: XCTIssue) {
        self.init(
            title: Self.title(for: issue),
            message: Self.message(for: issue),
            location: Self.location(for: issue)
        )
    }

    private static func title(for issue: XCTIssue) -> String {
        switch issue.type {
        case .assertionFailure:
            return "Assertion failed"
        case .thrownError:
            return "Test threw an error"
        case .uncaughtException:
            return "Uncaught exception"
        case .performanceRegression:
            return "Performance regression"
        case .system:
            return "XCTest error"
        case .unmatchedExpectedFailure:
            return "Expected failure did not occur"
        @unknown default:
            return "Test failed"
        }
    }

    private static func message(for issue: XCTIssue) -> String {
        let description = issue.compactDescription.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let fallback = "XCTest recorded a failure without a description."
        return String((description.isEmpty ? fallback : description).prefix(2_000))
    }

    private static func location(for issue: XCTIssue) -> String? {
        guard let location = issue.sourceCodeContext.location else {
            return nil
        }

        let fileName = location.fileURL.lastPathComponent
        guard !fileName.isEmpty else { return nil }
        guard location.lineNumber > 0 else { return fileName }
        return "\(fileName):\(location.lineNumber)"
    }
}
