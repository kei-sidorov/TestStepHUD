import Foundation
import Network
import TestStepHUDProtocol

final class AppTransport: @unchecked Sendable {
    typealias CommandHandler = (
        HUDWireMessage,
        @escaping @Sendable (Result<Void, Error>) -> Void
    ) -> Void

    var commandHandler: CommandHandler?
    var terminationHandler: (@Sendable () -> Void)?

    private let connection: NWConnection
    private let queue = DispatchQueue(
        label: "com.teststephud.app-transport",
        qos: .userInitiated
    )
    private let token: String
    private let protocolVersion: Int
    private var frameDecoder = HUDFrameDecoder()
    private var didSendHello = false
    private var didTerminate = false

    init(configuration: AppLaunchConfiguration) {
        let host = NWEndpoint.Host("127.0.0.1")
        connection = NWConnection(
            host: host,
            port: configuration.port,
            using: .tcp
        )
        token = configuration.token
        protocolVersion = TestStepHUDProtocolConstants.version
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }

            switch state {
            case .ready:
                self.sendHelloIfNeeded()
            case .failed, .cancelled:
                self.connection.stateUpdateHandler = nil
                self.terminateIfNeeded()
            default:
                break
            }
        }

        receiveNextChunk()
        connection.start(queue: queue)
    }

    func cancel() {
        connection.cancel()
    }

    private func sendHelloIfNeeded() {
        guard !didSendHello else { return }
        didSendHello = true

        let hello = HUDWireMessage.hello(
            token: token,
            protocolVersion: protocolVersion
        )
        send(hello)
    }

    private func receiveNextChunk() {
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: TestStepHUDProtocolConstants.maximumFrameSize + 4
        ) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let data, !data.isEmpty {
                self.process(data)
            }

            if error == nil, !isComplete {
                self.receiveNextChunk()
            } else {
                self.connection.cancel()
            }
        }
    }

    private func process(_ data: Data) {
        do {
            let payloads = try frameDecoder.append(data)
            for payload in payloads {
                let message = try HUDMessageCoding.decode(payload)
                process(message)
            }
        } catch {
            connection.cancel()
        }
    }

    private func process(_ message: HUDWireMessage) {
        guard [
            .show,
            .hide,
            .ping,
            .highlight,
            .clearHighlight,
            .interaction,
            .clearInteraction
        ].contains(message.kind) else {
            connection.cancel()
            return
        }

        guard let commandHandler else {
            acknowledge(
                message,
                result: .failure(
                    TestStepHUDProtocolError.remoteFailure(
                        "The app-side command handler is unavailable."
                    )
                )
            )
            return
        }

        commandHandler(message) { [weak self] result in
            self?.queue.async {
                self?.acknowledge(message, result: result)
            }
        }
    }

    private func acknowledge(
        _ message: HUDWireMessage,
        result: Result<Void, Error>
    ) {
        guard let id = message.id else {
            connection.cancel()
            return
        }

        let acknowledgement: HUDWireMessage
        switch result {
        case .success:
            acknowledgement = .acknowledgement(id: id, success: true)
        case let .failure(error):
            acknowledgement = .acknowledgement(
                id: id,
                success: false,
                error: error.localizedDescription
            )
        }
        send(acknowledgement)
    }

    private func send(_ message: HUDWireMessage) {
        do {
            let data = try HUDFrameEncoder.encode(message)
            connection.send(
                content: data,
                completion: .contentProcessed { [weak self] error in
                    if error != nil {
                        self?.connection.cancel()
                    }
                }
            )
        } catch {
            connection.cancel()
        }
    }

    private func terminateIfNeeded() {
        guard !didTerminate else { return }
        didTerminate = true
        commandHandler = nil
        terminationHandler?()
    }
}
