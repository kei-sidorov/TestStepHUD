import Foundation

/// UI-test pauses used only to make visual recordings readable.
public struct TestStepHUDPresentation: Equatable, Sendable {
    public let testCaseDuration: TimeInterval
    /// Pause used to keep automatic interaction and existence visuals readable.
    public let interactionDelay: TimeInterval
    /// Minimum time a recorded XCTest failure remains visible.
    public let failureDuration: TimeInterval

    public init(
        testCaseDuration: TimeInterval,
        interactionDelay: TimeInterval,
        failureDuration: TimeInterval = 3
    ) {
        self.testCaseDuration = Self.clamp(
            testCaseDuration,
            to: 0...60
        )
        self.interactionDelay = Self.clamp(
            interactionDelay,
            to: 0...5
        )
        self.failureDuration = Self.clamp(
            failureDuration,
            to: 0...60
        )
    }

    /// No successful-run pauses. Failures remain readable for three seconds.
    public static let fast = TestStepHUDPresentation(
        testCaseDuration: 0,
        interactionDelay: 0,
        failureDuration: 3
    )

    /// Recording-friendly defaults with readable test-case, interaction, and
    /// failure presentation timing.
    public static func visual(
        testCaseDuration: TimeInterval = 4,
        interactionDelay: TimeInterval = 0.5,
        failureDuration: TimeInterval = 3
    ) -> Self {
        Self(
            testCaseDuration: testCaseDuration,
            interactionDelay: interactionDelay,
            failureDuration: failureDuration
        )
    }

    /// Reads the presentation profile from the UI-test process environment.
    /// `TESTSTEPHUD_MODE=visual` enables successful-run pauses; failure timing
    /// is configurable in both modes.
    public static func fromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Self {
        let failureDuration = environmentValue(
            "TESTSTEPHUD_FAILURE_DURATION",
            in: environment,
            default: 3
        )
        guard environment["TESTSTEPHUD_MODE"]?.lowercased() == "visual" else {
            return Self(
                testCaseDuration: 0,
                interactionDelay: 0,
                failureDuration: failureDuration
            )
        }

        let testCaseDuration = environmentValue(
            "TESTSTEPHUD_CASE_DURATION",
            in: environment,
            default: 4
        )
        let interactionDelay = environmentValue(
            "TESTSTEPHUD_INTERACTION_DELAY",
            in: environment,
            default: 0.5
        )
        return .visual(
            testCaseDuration: testCaseDuration,
            interactionDelay: interactionDelay,
            failureDuration: failureDuration
        )
    }

    private static func clamp(
        _ value: TimeInterval,
        to range: ClosedRange<TimeInterval>
    ) -> TimeInterval {
        guard !value.isNaN else { return range.lowerBound }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    private static func environmentValue(
        _ key: String,
        in environment: [String: String],
        default defaultValue: TimeInterval
    ) -> TimeInterval {
        guard
            let rawValue = environment[key],
            let value = TimeInterval(rawValue),
            value.isFinite
        else {
            return defaultValue
        }
        return value
    }
}
