import Foundation
import Network
import Security
import TestStepHUDProtocol

final class TestTransport: @unchecked Sendable {
    private final class ConnectionContext {
        let connection: NWConnection
        var frameDecoder = HUDFrameDecoder()

        init(connection: NWConnection) {
            self.connection = connection
        }
    }

    let token: String

    private let listener: NWListener
    private let queue = DispatchQueue(
        label: "com.teststephud.test-transport",
        qos: .userInitiated
    )
    private let stateLock = NSLock()
    private let listenerReadySemaphore = DispatchSemaphore(value: 0)
    private let handshakeSemaphore = DispatchSemaphore(value: 0)
    private let acknowledgementRouter = HUDAcknowledgementRouter()

    private var connection: NWConnection?
    private var connectionContexts: [
        ObjectIdentifier: ConnectionContext
    ] = [:]
    private var resolvedPort: NWEndpoint.Port?
    private var listenerStartResult: Result<Void, Error>?
    private var handshakeResult: Result<Void, Error>?
    private var authenticated = false

    init() throws {
        token = try Self.makeSecureToken()

        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(
            host: NWEndpoint.Host("127.0.0.1"),
            port: .any
        )
        listener = try NWListener(using: parameters)
    }

    func start(timeout: TimeInterval) throws -> UInt16 {
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }

            switch state {
            case .ready:
                guard let port = self.listener.port else {
                    self.completeListenerStart(
                        .failure(TestStepHUDSessionError.transportUnavailable)
                    )
                    return
                }
                self.stateLock.lock()
                self.resolvedPort = port
                self.stateLock.unlock()
                self.completeListenerStart(.success(()))
            case let .failed(error):
                self.completeListenerStart(
                    .failure(
                        TestStepHUDSessionError.listenerFailed(
                            error.localizedDescription
                        )
                    )
                )
                self.completeHandshake(
                    .failure(
                        TestStepHUDSessionError.listenerFailed(
                            error.localizedDescription
                        )
                    )
                )
            case .cancelled:
                self.completeHandshake(
                    .failure(TestStepHUDSessionError.appDisconnected("Cancelled."))
                )
            default:
                break
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.start(queue: queue)

        guard listenerReadySemaphore.wait(timeout: .now() + timeout) == .success else {
            cancel()
            throw TestStepHUDSessionError.listenerStartTimedOut(timeout)
        }

        stateLock.lock()
        let result = listenerStartResult
        let port = resolvedPort
        stateLock.unlock()

        try result?.get()
        guard let port else {
            throw TestStepHUDSessionError.transportUnavailable
        }
        return port.rawValue
    }

    func waitForHandshake(timeout: TimeInterval) throws {
        guard handshakeSemaphore.wait(timeout: .now() + timeout) == .success else {
            cancel()
            throw TestStepHUDSessionError.appHandshakeTimedOut(timeout)
        }

        stateLock.lock()
        let result = handshakeResult
        stateLock.unlock()
        try result?.get()
    }

    func send(_ message: HUDWireMessage, timeout: TimeInterval) throws {
        let id = try message.commandID()
        let frame = try HUDFrameEncoder.encode(message)

        stateLock.lock()
        let isAuthenticated = authenticated
        stateLock.unlock()
        guard isAuthenticated else {
            throw TestStepHUDSessionError.transportUnavailable
        }

        let activeConnection = queue.sync { connection }
        guard let activeConnection else {
            throw TestStepHUDSessionError.transportUnavailable
        }
        let waiter = try acknowledgementRouter.register(id: id)

        activeConnection.send(
            content: frame,
            completion: .contentProcessed { [weak self] error in
                if let error {
                    self?.acknowledgementRouter.fail(id: id, error: error)
                }
            }
        )

        do {
            _ = try waiter.wait(id: id, timeout: timeout)
        } catch {
            acknowledgementRouter.fail(id: id, error: error)
            throw error
        }
    }

    func cancel() {
        queue.async { [weak self] in
            guard let self else { return }

            for context in connectionContexts.values {
                context.connection.stateUpdateHandler = nil
                context.connection.cancel()
            }
            connectionContexts.removeAll()
            connection = nil
            stateLock.lock()
            authenticated = false
            stateLock.unlock()
            listener.cancel()
        }
        acknowledgementRouter.cancelAll()
    }

    private func accept(_ newConnection: NWConnection) {
        guard connection == nil else {
            newConnection.cancel()
            return
        }

        let identifier = ObjectIdentifier(newConnection)
        connectionContexts[identifier] = ConnectionContext(
            connection: newConnection
        )
        newConnection.stateUpdateHandler = {
            [weak self, weak newConnection] state in
            guard let self, let newConnection else { return }

            switch state {
            case .ready:
                self.receiveNextChunk(on: newConnection)
            case let .failed(error):
                self.finish(
                    newConnection,
                    error: TestStepHUDSessionError.appDisconnected(
                        error.localizedDescription
                    )
                )
            case .cancelled:
                self.finish(
                    newConnection,
                    error: TestStepHUDSessionError.appDisconnected(
                        "Cancelled."
                    )
                )
            default:
                break
            }
        }
        newConnection.start(queue: queue)
    }

    private func receiveNextChunk(on connection: NWConnection) {
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: TestStepHUDProtocolConstants.maximumFrameSize + 4
        ) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            let identifier = ObjectIdentifier(connection)
            guard self.connectionContexts[identifier] != nil else {
                return
            }

            if let data, !data.isEmpty {
                self.process(data, from: connection)
            }

            guard self.connectionContexts[identifier] != nil else {
                return
            }

            if error == nil, !isComplete {
                self.receiveNextChunk(on: connection)
            } else {
                let transportError = error.map {
                    TestStepHUDSessionError.appDisconnected(
                        $0.localizedDescription
                    )
                } ?? TestStepHUDSessionError.appDisconnected(
                    "The connection closed."
                )
                self.finish(connection, error: transportError)
            }
        }
    }

    private func process(_ data: Data, from connection: NWConnection) {
        let identifier = ObjectIdentifier(connection)
        guard let context = connectionContexts[identifier] else {
            return
        }

        do {
            let payloads = try context.frameDecoder.append(data)
            for payload in payloads {
                guard connectionContexts[identifier] != nil else {
                    return
                }
                try process(
                    HUDMessageCoding.decode(payload),
                    from: connection
                )
            }
        } catch {
            finish(connection, error: error)
        }
    }

    private func process(
        _ message: HUDWireMessage,
        from sourceConnection: NWConnection
    ) throws {
        if connection === sourceConnection {
            let acknowledgement = try message.acknowledgementValue()
            _ = acknowledgementRouter.resolve(acknowledgement)
            return
        }

        let identifier = ObjectIdentifier(sourceConnection)
        guard connectionContexts[identifier] != nil else {
            return
        }

        try HUDHandshakeValidator.validate(
            message,
            expectedToken: token
        )

        guard connection == nil else {
            finish(
                sourceConnection,
                error: TestStepHUDSessionError.transportUnavailable
            )
            return
        }

        connection = sourceConnection
        stateLock.lock()
        authenticated = true
        stateLock.unlock()

        let otherContexts = connectionContexts.filter {
            $0.key != identifier
        }
        for (otherIdentifier, context) in otherContexts {
            connectionContexts.removeValue(forKey: otherIdentifier)
            context.connection.stateUpdateHandler = nil
            context.connection.cancel()
        }

        completeHandshake(.success(()))
        listener.cancel()
    }

    private func finish(
        _ finishedConnection: NWConnection,
        error: Error
    ) {
        let identifier = ObjectIdentifier(finishedConnection)
        guard connectionContexts.removeValue(forKey: identifier) != nil else {
            return
        }

        finishedConnection.stateUpdateHandler = nil
        finishedConnection.cancel()

        guard connection === finishedConnection else {
            return
        }

        connection = nil
        stateLock.lock()
        authenticated = false
        stateLock.unlock()
        completeHandshake(.failure(error))
        acknowledgementRouter.cancelAll()
    }

    private func completeListenerStart(_ result: Result<Void, Error>) {
        stateLock.lock()
        guard listenerStartResult == nil else {
            stateLock.unlock()
            return
        }
        listenerStartResult = result
        stateLock.unlock()
        listenerReadySemaphore.signal()
    }

    private func completeHandshake(_ result: Result<Void, Error>) {
        stateLock.lock()
        guard handshakeResult == nil else {
            stateLock.unlock()
            return
        }
        handshakeResult = result
        stateLock.unlock()
        handshakeSemaphore.signal()
    }

    private static func makeSecureToken() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw TestStepHUDSessionError.randomTokenGenerationFailed
        }
        return Data(bytes).base64EncodedString()
    }
}
