import Foundation
import XCTest
import TestStepHUDProtocol

public extension XCUIApplication {
    /// Launches the application and attempts to connect its HUD receiver.
    ///
    /// Existing launch arguments and environment values are preserved. Only
    /// TestStepHUD's namespaced environment keys are added. While the returned
    /// session is active, supported `XCUIElement` and `XCUICoordinate`
    /// interactions visualize their geometry before invoking the original
    /// XCUITest implementation. Only one HUD session may be active in a
    /// UI-test process at a time. HUD setup is best-effort: if it cannot be
    /// completed, the application still launches and the returned session
    /// becomes a no-op. Inspect `startupError` when HUD availability matters
    /// to diagnostics.
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
    ) -> TestStepHUDSession {
        do {
            try XCUIElementTapInterceptor.ensureNoActiveSession()
        } catch {
            return TestStepHUDSession(
                application: self,
                defaultTimeout: timeout,
                tapHighlightDelay: tapHighlightDelay,
                startupError: TestStepHUDSessionError.from(error)
            )
        }

        let transport: TestTransport
        let port: UInt16
        do {
            transport = try TestTransport()
            port = try transport.start(timeout: timeout)
        } catch {
            clearTestStepHUDLaunchEnvironment()
            launch()
            return TestStepHUDSession(
                application: self,
                defaultTimeout: timeout,
                tapHighlightDelay: tapHighlightDelay,
                startupError: TestStepHUDSessionError.from(error)
            )
        }

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
                tapHighlightDelay: tapHighlightDelay,
                startupError: nil
            )
            try XCUIElementTapInterceptor.activate(session: session)
            return session
        } catch {
            transport.cancel()
            return TestStepHUDSession(
                application: self,
                defaultTimeout: timeout,
                tapHighlightDelay: tapHighlightDelay,
                startupError: TestStepHUDSessionError.from(error)
            )
        }
    }

    private func clearTestStepHUDLaunchEnvironment() {
        launchEnvironment.removeValue(
            forKey: TestStepHUDProtocolConstants.portEnvironmentKey
        )
        launchEnvironment.removeValue(
            forKey: TestStepHUDProtocolConstants.tokenEnvironmentKey
        )
        launchEnvironment.removeValue(
            forKey: TestStepHUDProtocolConstants.versionEnvironmentKey
        )
    }
}
