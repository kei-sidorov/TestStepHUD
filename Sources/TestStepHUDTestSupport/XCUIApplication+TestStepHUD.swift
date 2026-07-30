import Foundation
import XCTest
import TestStepHUDProtocol

public extension XCUIApplication {
    /// Launches the application and waits until its HUD receiver authenticates.
    ///
    /// Existing launch arguments and environment values are preserved. Only
    /// TestStepHUD's namespaced environment keys are added. While the returned
    /// session is active, supported `XCUIElement` and `XCUICoordinate`
    /// interactions visualize their geometry before invoking the original
    /// XCUITest implementation. Only one HUD session may be active in a
    /// UI-test process at a time.
    ///
    /// - Parameters:
    ///   - timeout: Maximum duration for launch handshakes and HUD commands.
    ///   - tapHighlightDelay: Lead-in time for every automatic interaction
    ///     visual. The historical name is retained for source compatibility.
    ///     Values are clamped to `0...5` seconds.
    @MainActor
    func launchWithTestStepHUD(
        timeout: TimeInterval = 5,
        tapHighlightDelay: TimeInterval = 0.5
    ) throws -> TestStepHUDSession {
        try XCUIElementTapInterceptor.ensureNoActiveSession()

        let transport = try TestTransport()
        let port = try transport.start(timeout: timeout)

        launchEnvironment[TestStepHUDProtocolConstants.portEnvironmentKey] =
            String(port)
        launchEnvironment[TestStepHUDProtocolConstants.tokenEnvironmentKey] =
            transport.token
        launchEnvironment[TestStepHUDProtocolConstants.versionEnvironmentKey] =
            String(TestStepHUDProtocolConstants.version)

        launch()

        do {
            try transport.waitForHandshake(timeout: timeout)
            let session = TestStepHUDSession(
                transport: transport,
                application: self,
                defaultTimeout: timeout,
                tapHighlightDelay: tapHighlightDelay
            )
            try XCUIElementTapInterceptor.activate(session: session)
            return session
        } catch {
            transport.cancel()
            throw error
        }
    }
}
