import Foundation
import TestStepHUDProtocol

@MainActor
final class HUDRuntime {
    static let shared = HUDRuntime()

    private var transport: AppTransport?
    private var windowController: HUDWindowController?

    private init() {}

    func install(
        launchConfiguration: AppLaunchConfiguration,
        configuration: TestStepHUD.Configuration
    ) {
        guard transport == nil else { return }

        let windowController = HUDWindowController(configuration: configuration)
        let transport = AppTransport(configuration: launchConfiguration)

        transport.commandHandler = { [weak self] message, completion in
            Task { @MainActor [weak self] in
                guard let self else {
                    completion(.failure(TestStepHUDProtocolError.cancelled))
                    return
                }
                self.handle(
                    message,
                    windowController: windowController,
                    completion: completion
                )
            }
        }

        transport.terminationHandler = { [weak windowController] in
            Task { @MainActor [weak windowController] in
                windowController?.hide()
            }
        }

        self.windowController = windowController
        self.transport = transport
        transport.start()
    }

    private func handle(
        _ message: HUDWireMessage,
        windowController: HUDWindowController,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        do {
            switch message.kind {
            case .show:
                _ = try message.commandID()
                let text = try message.showText()
                windowController.show(text, completion: completion)
            case .showTestCase:
                _ = try message.commandID()
                let testCase = try message.testCaseValue()
                windowController.showTestCase(
                    testCase,
                    completion: completion
                )
            case .showFailure:
                _ = try message.commandID()
                let failure = try message.failureValue()
                windowController.showFailure(
                    failure,
                    completion: completion
                )
            case .hide:
                _ = try message.commandID()
                windowController.hide()
                completion(.success(()))
            case .ping:
                _ = try message.commandID()
                completion(.success(()))
            case .highlight:
                _ = try message.commandID()
                let rect = try message.highlightRect()
                windowController.highlight(rect, completion: completion)
            case .clearHighlight:
                _ = try message.commandID()
                windowController.clearHighlight()
                completion(.success(()))
            case .interaction:
                _ = try message.commandID()
                let interaction = try message.interactionVisual()
                windowController.showInteraction(
                    interaction,
                    completion: completion
                )
            case .clearInteraction:
                _ = try message.commandID()
                windowController.clearInteraction()
                completion(.success(()))
            case .hello, .acknowledgement:
                throw TestStepHUDProtocolError.unexpectedMessage(
                    message.kind.rawValue
                )
            }
        } catch {
            completion(.failure(error))
        }
    }
}
