import Network
import XCTest
import TestStepHUDProtocol
@testable import TestStepHUDTestSupport

final class TestTransportTests: XCTestCase {
    func testUnauthenticatedPeerDoesNotBlockAuthenticatedPeer() throws {
        let transport = try TestTransport()
        let port = try transport.start(timeout: 2)
        defer {
            transport.cancel()
        }

        let unauthenticatedPeer = try connect(to: port)
        defer {
            unauthenticatedPeer.cancel()
        }

        let authenticatedPeer = try connect(to: port)
        defer {
            authenticatedPeer.cancel()
        }

        let hello = HUDWireMessage.hello(
            token: transport.token,
            protocolVersion: TestStepHUDProtocolConstants.version
        )
        let sendCompleted = expectation(description: "hello sent")
        authenticatedPeer.send(
            content: try HUDFrameEncoder.encode(hello),
            completion: .contentProcessed { error in
                XCTAssertNil(error)
                sendCompleted.fulfill()
            }
        )

        wait(for: [sendCompleted], timeout: 2)
        XCTAssertNoThrow(
            try transport.waitForHandshake(timeout: 2)
        )
    }

    func testOversizedCommandDoesNotReserveItsIdentifier() throws {
        let transport = try TestTransport()
        defer {
            transport.cancel()
        }

        let id = UUID()
        let oversizedMessage = HUDWireMessage.show(
            id: id,
            text: String(
                repeating: "x",
                count: TestStepHUDProtocolConstants.maximumFrameSize
            )
        )

        XCTAssertThrowsError(
            try transport.send(oversizedMessage, timeout: 0.1)
        ) { error in
            guard
                case .frameTooLarge =
                    error as? TestStepHUDProtocolError
            else {
                XCTFail("Expected frameTooLarge, received \(error).")
                return
            }
        }

        XCTAssertThrowsError(
            try transport.send(
                .show(id: id, text: "Small command"),
                timeout: 0.1
            )
        ) { error in
            guard
                case .transportUnavailable =
                    error as? TestStepHUDSessionError
            else {
                XCTFail(
                    "Expected transportUnavailable, received \(error)."
                )
                return
            }
        }
    }

    private func connect(to rawPort: UInt16) throws -> NWConnection {
        let port = try XCTUnwrap(NWEndpoint.Port(rawValue: rawPort))
        let connection = NWConnection(
            host: NWEndpoint.Host("127.0.0.1"),
            port: port,
            using: .tcp
        )
        let ready = expectation(description: "connection ready")
        let queue = DispatchQueue(
            label: "com.teststephud.transport-tests.\(UUID().uuidString)"
        )

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                ready.fulfill()
            case let .failed(error):
                XCTFail("Connection failed: \(error)")
            default:
                break
            }
        }
        connection.start(queue: queue)
        wait(for: [ready], timeout: 2)
        return connection
    }
}
