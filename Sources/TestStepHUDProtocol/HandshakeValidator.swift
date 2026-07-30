import Foundation

public enum HUDHandshakeValidator {
    public static func validate(
        _ message: HUDWireMessage,
        expectedToken: String,
        supportedVersion: Int = TestStepHUDProtocolConstants.version
    ) throws {
        guard message.kind == .hello else {
            throw TestStepHUDProtocolError.unexpectedMessage(message.kind.rawValue)
        }
        guard let token = message.token, token == expectedToken else {
            throw TestStepHUDProtocolError.invalidToken
        }
        guard let version = message.protocolVersion else {
            throw TestStepHUDProtocolError.missingField("protocolVersion")
        }
        guard version == supportedVersion else {
            throw TestStepHUDProtocolError.unsupportedVersion(
                received: version,
                supported: supportedVersion
            )
        }
    }
}
