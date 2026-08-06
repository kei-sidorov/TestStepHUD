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
    /// XCUITest implementation. A successful `waitForExistence(timeout:)`
    /// visualizes the element after the original implementation returns, and
    /// recorded XCTest issues present a centered failure card. Only one HUD
    /// session may be active in a UI-test process at a time. HUD setup is
    /// best-effort: if it cannot be completed, the application still launches
    /// and the returned session becomes a no-op. Inspect `startupError` when
    /// HUD availability matters to diagnostics.
    ///
    /// - Parameters:
    ///   - timeout: Maximum duration for launch handshakes and HUD commands.
    ///   - presentation: Deliberate pauses used to make recordings readable.
    ///     The environment-based default is fast unless
    ///     `TESTSTEPHUD_MODE=visual` is set in the UI-test process.
    @MainActor
    func launchWithTestStepHUD(
        timeout: TimeInterval = 5,
        presentation: TestStepHUDPresentation = .fromEnvironment()
    ) -> TestStepHUDSession {
        do {
            try XCUIElementTapInterceptor.ensureNoActiveSession()
        } catch {
            return TestStepHUDSession(
                application: self,
                defaultTimeout: timeout,
                presentation: presentation,
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
                presentation: presentation,
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
                presentation: presentation,
                startupError: nil
            )
            try XCUIElementTapInterceptor.activate(session: session)
            session.activateFailureObservation()
            return session
        } catch {
            transport.cancel()
            return TestStepHUDSession(
                application: self,
                defaultTimeout: timeout,
                presentation: presentation,
                startupError: TestStepHUDSessionError.from(error)
            )
        }
    }

    /// Source-compatible overload for the historical interaction delay.
    /// Test-case introductions remain disabled when this overload is used.
    @MainActor
    func launchWithTestStepHUD(
        timeout: TimeInterval = 5,
        tapHighlightDelay: TimeInterval
    ) -> TestStepHUDSession {
        launchWithTestStepHUD(
            timeout: timeout,
            presentation: .init(
                testCaseDuration: 0,
                interactionDelay: tapHighlightDelay
            )
        )
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
