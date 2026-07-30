import XCTest
@testable import TestStepHUDProtocol

final class HandshakeValidatorTests: XCTestCase {
    func testAcceptsExpectedTokenAndVersion() {
        XCTAssertNoThrow(
            try HUDHandshakeValidator.validate(
                .hello(
                    token: "expected-token",
                    protocolVersion: TestStepHUDProtocolConstants.version
                ),
                expectedToken: "expected-token"
            )
        )
    }

    func testRejectsInvalidToken() {
        XCTAssertThrowsError(
            try HUDHandshakeValidator.validate(
                .hello(
                    token: "wrong-token",
                    protocolVersion: TestStepHUDProtocolConstants.version
                ),
                expectedToken: "expected-token"
            )
        ) { error in
            XCTAssertEqual(
                error as? TestStepHUDProtocolError,
                .invalidToken
            )
        }
    }

    func testRejectsProtocolVersionMismatch() {
        XCTAssertThrowsError(
            try HUDHandshakeValidator.validate(
                .hello(token: "token", protocolVersion: 99),
                expectedToken: "token"
            )
        ) { error in
            XCTAssertEqual(
                error as? TestStepHUDProtocolError,
                .unsupportedVersion(
                    received: 99,
                    supported: TestStepHUDProtocolConstants.version
                )
            )
        }
    }

    func testRejectsNonHelloMessage() {
        let message = HUDWireMessage.ping(id: UUID())

        XCTAssertThrowsError(
            try HUDHandshakeValidator.validate(
                message,
                expectedToken: "token"
            )
        )
    }
}
