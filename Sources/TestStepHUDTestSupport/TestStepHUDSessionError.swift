import Foundation

public enum TestStepHUDSessionError: Error, LocalizedError {
    case listenerFailed(String)
    case listenerStartTimedOut(TimeInterval)
    case appHandshakeTimedOut(TimeInterval)
    case appDisconnected(String)
    case transportUnavailable
    case randomTokenGenerationFailed
    case sessionAlreadyActive
    case tapInterceptionUnavailable
    case interactionInterceptionUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case let .listenerFailed(message):
            return "TestStepHUD could not start its loopback listener: \(message)"
        case let .listenerStartTimedOut(timeout):
            return "TestStepHUD did not obtain a loopback port within \(timeout) seconds."
        case let .appHandshakeTimedOut(timeout):
            return """
            The app did not connect to TestStepHUD within \(timeout) seconds. \
            Confirm that the app target links TestStepHUD and calls TestStepHUD.install().
            """
        case let .appDisconnected(message):
            return "The TestStepHUD app connection closed: \(message)"
        case .transportUnavailable:
            return "The TestStepHUD connection is not ready."
        case .randomTokenGenerationFailed:
            return "TestStepHUD could not create a secure session token."
        case .sessionAlreadyActive:
            return """
            TestStepHUD supports one active HUD session per UI-test process. \
            Cancel or release the existing session before launching another.
            """
        case .tapInterceptionUnavailable:
            return "TestStepHUD could not intercept XCUIElement.tap()."
        case let .interactionInterceptionUnavailable(selector):
            return "TestStepHUD could not intercept XCTest selector '\(selector)'."
        }
    }
}
