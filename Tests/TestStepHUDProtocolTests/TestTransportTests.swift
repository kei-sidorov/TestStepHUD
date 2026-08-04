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

    func testCancelAfterHidingHUDSendsHideBeforeDisconnecting() throws {
        let transport = try TestTransport()
        let port = try transport.start(timeout: 2)
        defer {
            transport.cancel()
        }

        let peer = try connect(to: port)
        defer {
            peer.cancel()
        }

        let helloSent = expectation(description: "hello sent")
        peer.send(
            content: try HUDFrameEncoder.encode(
                .hello(
                    token: transport.token,
                    protocolVersion: TestStepHUDProtocolConstants.version
                )
            ),
            completion: .contentProcessed { error in
                XCTAssertNil(error)
                helloSent.fulfill()
            }
        )
        wait(for: [helloSent], timeout: 2)
        try transport.waitForHandshake(timeout: 2)

        let hideReceived = expectation(description: "hide command received")
        let cancellationState = CancellationState()
        let receiver = WireMessageReceiver()
        receiver.receiveNextMessage(on: peer) { result in
            do {
                let message = try result.get()
                XCTAssertEqual(message.kind, .hide)
                XCTAssertFalse(cancellationState.didReturn)
                hideReceived.fulfill()

                let acknowledgement = HUDWireMessage.acknowledgement(
                    id: try message.commandID(),
                    success: true
                )
                peer.send(
                    content: try HUDFrameEncoder.encode(acknowledgement),
                    completion: .contentProcessed { _ in }
                )
            } catch {
                XCTFail("Expected a hide command: \(error)")
            }
        }

        transport.cancelAfterHidingHUD(timeout: 2)
        cancellationState.markReturned()
        wait(for: [hideReceived], timeout: 2)
        withExtendedLifetime(receiver) {}
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

private final class CancellationState: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var didReturn: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func markReturned() {
        lock.lock()
        value = true
        lock.unlock()
    }
}

private final class WireMessageReceiver {
    private var frameDecoder = HUDFrameDecoder()

    func receiveNextMessage(
        on connection: NWConnection,
        completion: @escaping (Result<HUDWireMessage, Error>) -> Void
    ) {
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: TestStepHUDProtocolConstants.maximumFrameSize + 4
        ) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            do {
                if let data, !data.isEmpty {
                    let payloads = try self.frameDecoder.append(data)
                    if let payload = payloads.first {
                        completion(.success(try HUDMessageCoding.decode(payload)))
                        return
                    }
                }

                if let error {
                    completion(.failure(error))
                } else if isComplete {
                    completion(
                        .failure(
                            TestStepHUDProtocolError.cancelled
                        )
                    )
                } else {
                    self.receiveNextMessage(
                        on: connection,
                        completion: completion
                    )
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
}
