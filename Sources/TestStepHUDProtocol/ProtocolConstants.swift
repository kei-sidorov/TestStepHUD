import Foundation

public enum TestStepHUDProtocolConstants {
    public static let version = 6
    public static let maximumFrameSize = 64 * 1024

    public static let portEnvironmentKey = "TESTSTEPHUD_PORT"
    public static let tokenEnvironmentKey = "TESTSTEPHUD_TOKEN"
    public static let versionEnvironmentKey = "TESTSTEPHUD_PROTOCOL_VERSION"
}

public enum TestStepHUDProtocolError: Error, Equatable, LocalizedError {
    case emptyFrame
    case frameTooLarge(actual: Int, maximum: Int)
    case malformedPayload
    case invalidNormalizedRect
    case invalidInteraction
    case missingField(String)
    case unexpectedMessage(String)
    case invalidToken
    case unsupportedVersion(received: Int, supported: Int)
    case duplicateCommand(UUID)
    case timeout(UUID)
    case cancelled
    case remoteFailure(String)

    public var errorDescription: String? {
        switch self {
        case .emptyFrame:
            return "Received an empty TestStepHUD frame."
        case let .frameTooLarge(actual, maximum):
            return "TestStepHUD frame size \(actual) exceeds the \(maximum)-byte limit."
        case .malformedPayload:
            return "The TestStepHUD payload is not valid protocol JSON."
        case .invalidNormalizedRect:
            return "The TestStepHUD highlight rectangle is invalid."
        case .invalidInteraction:
            return "The TestStepHUD interaction visual is invalid."
        case let .missingField(field):
            return "The TestStepHUD message is missing required field '\(field)'."
        case let .unexpectedMessage(kind):
            return "Unexpected TestStepHUD message '\(kind)'."
        case .invalidToken:
            return "The app returned an invalid TestStepHUD session token."
        case let .unsupportedVersion(received, supported):
            return "Unsupported TestStepHUD protocol version \(received); supported version is \(supported)."
        case let .duplicateCommand(id):
            return "A TestStepHUD command with id \(id) is already pending."
        case let .timeout(id):
            return "Timed out waiting for TestStepHUD acknowledgement \(id)."
        case .cancelled:
            return "The TestStepHUD session was cancelled."
        case let .remoteFailure(message):
            return "The app rejected a TestStepHUD command: \(message)"
        }
    }
}
