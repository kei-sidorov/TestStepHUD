import Foundation
import XCTest
import TestStepHUDProtocol

public final class TestStepHUDSession: @unchecked Sendable {
    private let transport: TestTransport?
    private let application: XCUIApplication
    private let defaultTimeout: TimeInterval
    private let presentation: TestStepHUDPresentation
    private let cancellationLock = NSLock()
    private let observationLock = NSLock()
    private var isCancelled = false
    private var failureObserver: TestStepHUDFailureObserver?

    /// The setup error when HUD startup was unavailable. A session with a
    /// startup error safely ignores HUD commands while the UI test continues.
    public let startupError: TestStepHUDSessionError?

    /// Whether the HUD connected and installed interaction interception.
    public var isAvailable: Bool {
        startupError == nil
    }

    init(
        transport: TestTransport,
        application: XCUIApplication,
        defaultTimeout: TimeInterval,
        presentation: TestStepHUDPresentation,
        startupError: TestStepHUDSessionError?
    ) {
        self.transport = transport
        self.application = application
        self.defaultTimeout = defaultTimeout
        self.presentation = presentation
        self.startupError = startupError
    }

    init(
        application: XCUIApplication,
        defaultTimeout: TimeInterval,
        presentation: TestStepHUDPresentation,
        startupError: TestStepHUDSessionError
    ) {
        transport = nil
        self.application = application
        self.defaultTimeout = defaultTimeout
        self.presentation = presentation
        self.startupError = startupError
    }

    deinit {
        cancel()
    }

    @MainActor
    public func show(
        _ text: String,
        timeout: TimeInterval? = nil
    ) {
        guard !hasCancelled, let transport else { return }
        let id = UUID()
        try? transport.send(
            .show(id: id, text: text),
            timeout: timeout ?? defaultTimeout
        )
    }

    @MainActor
    public func hide(timeout: TimeInterval? = nil) {
        guard !hasCancelled, let transport else { return }
        let id = UUID()
        try? transport.send(
            .hide(id: id),
            timeout: timeout ?? defaultTimeout
        )
    }

    /// Presents a centered test-case card, keeps it readable for the
    /// configured visual duration, and hides it before the test continues.
    /// Fast mode makes this method a strict no-op.
    @MainActor
    public func testCase(
        _ title: String,
        steps: [String],
        timeout: TimeInterval? = nil
    ) {
        guard
            presentation.testCaseDuration > 0,
            !hasCancelled,
            let transport
        else {
            return
        }

        do {
            try transport.send(
                .showTestCase(
                    id: UUID(),
                    title: title,
                    steps: steps
                ),
                timeout: timeout ?? defaultTimeout
            )
        } catch {
            return
        }

        Thread.sleep(forTimeInterval: presentation.testCaseDuration)
        hide(timeout: timeout)
    }

    /// Presents a named test step without wrapping subsequent test code.
    ///
    /// Use this overload when adding a HUD to an existing test should not
    /// indent the action and assertions inside a closure.
    @MainActor
    public func step(
        _ title: String,
        timeout: TimeInterval? = nil
    ) {
        show(title, timeout: timeout)
    }

    /// Presents a named test step and runs its action as an XCTest activity.
    @MainActor
    @discardableResult
    public func step<T>(
        _ title: String,
        timeout: TimeInterval? = nil,
        action: () throws -> T
    ) rethrows -> T {
        step(title, timeout: timeout)
        return try XCTContext.runActivity(named: title) { _ in
            try action()
        }
    }

    /// Ends the HUD session and hides any displayed app-side HUD first.
    ///
    /// Call this before handing control to system UI when the HUD session is
    /// finished. The original XCUITest behavior remains available after the
    /// session has been cancelled.
    public func cancel() {
        guard beginCancellation() else { return }

        deactivateFailureObservation()
        XCUIElementTapInterceptor.deactivate(session: self)
        transport?.cancelAfterHidingHUD(timeout: defaultTimeout)
    }

    func activateFailureObservation() {
        observationLock.lock()
        defer { observationLock.unlock() }
        guard failureObserver == nil else { return }

        let observer = TestStepHUDFailureObserver(session: self)
        failureObserver = observer
        XCTestObservationCenter.shared.addTestObserver(observer)
    }

    func presentFailure(_ failure: HUDTestFailure) {
        guard !hasCancelled, let transport else { return }

        do {
            try transport.send(
                .showFailure(id: UUID(), failure: failure),
                timeout: defaultTimeout
            )
        } catch {
            return
        }

        guard presentation.failureDuration > 0 else { return }
        Thread.sleep(forTimeInterval: presentation.failureDuration)
    }

    private func deactivateFailureObservation() {
        observationLock.lock()
        let observer = failureObserver
        failureObserver = nil
        observationLock.unlock()

        if let observer {
            XCTestObservationCenter.shared.removeTestObserver(observer)
        }
    }

    private var hasCancelled: Bool {
        cancellationLock.lock()
        defer { cancellationLock.unlock() }
        return isCancelled
    }

    private func beginCancellation() -> Bool {
        cancellationLock.lock()
        defer { cancellationLock.unlock() }

        guard !isCancelled else { return false }
        isCancelled = true
        return true
    }

    @MainActor
    func performInterceptedTap(
        on element: XCUIElement,
        originalTap: () -> Void
    ) {
        var didPresentHighlight = false

        if let transport, let rect = normalizedRect(for: element) {
            do {
                let id = UUID()
                try transport.send(
                    .highlight(id: id, rect: rect),
                    timeout: defaultTimeout
                )
                didPresentHighlight = true
                pauseForAutomaticVisualIfNeeded()
            } catch {}
        }

        originalTap()

        if didPresentHighlight {
            let id = UUID()
            try? transport?.send(
                .clearHighlight(id: id),
                timeout: defaultTimeout
            )
        }
    }

    @MainActor
    func performInterceptedDoubleTap(
        on element: XCUIElement,
        originalAction: () -> Void
    ) {
        let visual = normalizedRect(for: element).map {
            HUDInteraction(kind: .doubleTap, rect: $0)
        }
        performInterceptedInteraction(
            visual,
            name: "double tap",
            originalAction: originalAction
        )
    }

    @MainActor
    func performInterceptedWaitForExistence(
        on element: XCUIElement,
        timeout: TimeInterval,
        originalWait: (TimeInterval) -> Bool
    ) -> Bool {
        let didExist = originalWait(timeout)
        guard
            didExist,
            let transport,
            let rect = normalizedRect(for: element, requireHittable: false)
        else {
            return didExist
        }

        do {
            try transport.send(
                .highlight(id: UUID(), rect: rect, style: .existence),
                timeout: defaultTimeout
            )
            pauseForAutomaticVisualIfNeeded()
        } catch {}

        return didExist
    }

    @MainActor
    func performInterceptedTyping(
        on element: XCUIElement,
        originalAction: () -> Void
    ) {
        let visual = normalizedRect(for: element).map {
            HUDInteraction(kind: .typing, rect: $0)
        }
        performInterceptedInteraction(
            visual,
            name: "typing",
            originalAction: originalAction
        )
    }

    @MainActor
    func performInterceptedSwipe(
        on element: XCUIElement,
        direction: HUDSwipeDirection,
        originalAction: () -> Void
    ) {
        let visual = normalizedRect(
            for: element,
            requireHittable: false
        ).map {
            HUDInteraction(
                kind: .swipe,
                rect: $0,
                direction: direction
            )
        }
        performInterceptedInteraction(
            visual,
            name: "swipe",
            originalAction: originalAction
        )
    }

    @MainActor
    func performInterceptedLongPress(
        on element: XCUIElement,
        duration: TimeInterval,
        originalAction: () -> Void
    ) {
        let visual = normalizedRect(for: element).map {
            HUDInteraction(
                kind: .longPress,
                rect: $0,
                duration: max(duration, 0)
            )
        }
        performInterceptedInteraction(
            visual,
            name: "long press",
            originalAction: originalAction
        )
    }

    @MainActor
    func performInterceptedDrag(
        from source: XCUIElement,
        to destination: XCUIElement,
        duration: TimeInterval,
        originalAction: () -> Void
    ) {
        let sourceRect = normalizedRect(for: source)
        let destinationRect = normalizedRect(
            for: destination,
            requireHittable: false
        )
        let visual: HUDInteraction?
        if let sourceRect, let destinationRect {
            visual = HUDInteraction(
                kind: .drag,
                start: sourceRect.center,
                end: destinationRect.center,
                duration: max(duration, 0)
            )
        } else {
            visual = nil
        }
        performInterceptedInteraction(
            visual,
            name: "drag",
            originalAction: originalAction
        )
    }

    @MainActor
    func performInterceptedCoordinateTap(
        on coordinate: XCUICoordinate,
        isDoubleTap: Bool,
        originalAction: () -> Void
    ) {
        let visual = normalizedPoint(for: coordinate).map {
            HUDInteraction(
                kind: isDoubleTap ? .doubleTap : .coordinateTap,
                start: $0
            )
        }
        performInterceptedInteraction(
            visual,
            name: isDoubleTap ? "coordinate double tap" : "coordinate tap",
            originalAction: originalAction
        )
    }

    @MainActor
    func performInterceptedCoordinateLongPress(
        on coordinate: XCUICoordinate,
        duration: TimeInterval,
        originalAction: () -> Void
    ) {
        let visual = normalizedPoint(for: coordinate).map {
            HUDInteraction(
                kind: .longPress,
                start: $0,
                duration: max(duration, 0)
            )
        }
        performInterceptedInteraction(
            visual,
            name: "coordinate long press",
            originalAction: originalAction
        )
    }

    @MainActor
    func performInterceptedCoordinateDrag(
        from source: XCUICoordinate,
        to destination: XCUICoordinate,
        duration: TimeInterval,
        originalAction: () -> Void
    ) {
        let start = normalizedPoint(for: source)
        let end = normalizedPoint(for: destination)
        let visual: HUDInteraction?
        if let start, let end {
            visual = HUDInteraction(
                kind: .drag,
                start: start,
                end: end,
                duration: max(duration, 0)
            )
        } else {
            visual = nil
        }
        performInterceptedInteraction(
            visual,
            name: "coordinate drag",
            originalAction: originalAction
        )
    }

    @MainActor
    private func performInterceptedInteraction(
        _ visual: HUDInteraction?,
        name: String,
        originalAction: () -> Void
    ) {
        var didPresent = false

        if let transport, let visual {
            do {
                try transport.send(
                    .interaction(id: UUID(), visual: visual),
                    timeout: defaultTimeout
                )
                didPresent = true
                pauseForAutomaticVisualIfNeeded()
            } catch {}
        }

        originalAction()

        if didPresent {
            try? transport?.send(
                .clearInteraction(id: UUID()),
                timeout: defaultTimeout
            )
        }
    }

    private func pauseForAutomaticVisualIfNeeded() {
        guard presentation.interactionDelay > 0 else { return }
        Thread.sleep(forTimeInterval: presentation.interactionDelay)
    }

    @MainActor
    private func normalizedRect(
        for element: XCUIElement,
        requireHittable: Bool = true
    ) -> HUDNormalizedRect? {
        guard element.exists else { return nil }
        if requireHittable, !element.isHittable {
            return nil
        }

        let applicationFrame = application.frame.standardized
        let elementFrame = element.frame.standardized
        guard
            applicationFrame.width > 0,
            applicationFrame.height > 0,
            !elementFrame.isEmpty,
            !elementFrame.isNull
        else {
            return nil
        }

        let visibleFrame = elementFrame.intersection(applicationFrame)
        guard !visibleFrame.isEmpty, !visibleFrame.isNull else {
            return nil
        }

        return HUDNormalizedRect(
            x: (visibleFrame.minX - applicationFrame.minX) /
                applicationFrame.width,
            y: (visibleFrame.minY - applicationFrame.minY) /
                applicationFrame.height,
            width: visibleFrame.width / applicationFrame.width,
            height: visibleFrame.height / applicationFrame.height
        )
    }

    @MainActor
    private func normalizedPoint(
        for coordinate: XCUICoordinate
    ) -> HUDNormalizedPoint? {
        guard coordinate.referencedElement.exists else { return nil }

        let applicationFrame = application.frame.standardized
        guard
            applicationFrame.width > 0,
            applicationFrame.height > 0
        else {
            return nil
        }

        let screenPoint = coordinate.screenPoint
        guard applicationFrame.contains(screenPoint) else { return nil }

        return HUDNormalizedPoint(
            x: (screenPoint.x - applicationFrame.minX) /
                applicationFrame.width,
            y: (screenPoint.y - applicationFrame.minY) /
                applicationFrame.height
        )
    }
}

private extension HUDNormalizedRect {
    var center: HUDNormalizedPoint {
        HUDNormalizedPoint(
            x: x + width / 2,
            y: y + height / 2
        )
    }
}
