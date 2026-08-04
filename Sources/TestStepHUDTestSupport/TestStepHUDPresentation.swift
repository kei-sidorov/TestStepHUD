import Foundation

/// Deliberate UI-test pauses used only to make visual recordings readable.
public struct TestStepHUDPresentation: Equatable, Sendable {
    public let testCaseDuration: TimeInterval
    public let interactionDelay: TimeInterval

    public init(
        testCaseDuration: TimeInterval,
        interactionDelay: TimeInterval
    ) {
        self.testCaseDuration = Self.clamp(
            testCaseDuration,
            to: 0...60
        )
        self.interactionDelay = Self.clamp(
            interactionDelay,
            to: 0...5
        )
    }

    /// No test-case card and no deliberate delay before interactions.
    public static let fast = TestStepHUDPresentation(
        testCaseDuration: 0,
        interactionDelay: 0
    )

    /// Recording-friendly defaults with readable test-case and interaction
    /// lead-in pauses.
    public static func visual(
        testCaseDuration: TimeInterval = 4,
        interactionDelay: TimeInterval = 0.5
    ) -> Self {
        Self(
            testCaseDuration: testCaseDuration,
            interactionDelay: interactionDelay
        )
    }

    /// Reads the presentation profile from the UI-test process environment.
    /// Only `TESTSTEPHUD_MODE=visual` enables deliberate pauses.
    public static func fromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Self {
        guard environment["TESTSTEPHUD_MODE"]?.lowercased() == "visual" else {
            return .fast
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
            interactionDelay: interactionDelay
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
