import Foundation
import XCTest
import TestStepHUDProtocol

public final class TestStepHUDSession: @unchecked Sendable {
    private let transport: TestTransport
    private let application: XCUIApplication
    private let defaultTimeout: TimeInterval
    private let tapHighlightDelay: TimeInterval

    init(
        transport: TestTransport,
        application: XCUIApplication,
        defaultTimeout: TimeInterval,
        tapHighlightDelay: TimeInterval
    ) {
        self.transport = transport
        self.application = application
        self.defaultTimeout = defaultTimeout
        self.tapHighlightDelay = min(max(tapHighlightDelay, 0), 5)
    }

    deinit {
        XCUIElementTapInterceptor.deactivate(session: self)
        transport.cancel()
    }

    @MainActor
    public func show(
        _ text: String,
        timeout: TimeInterval? = nil
    ) throws {
        let id = UUID()
        try transport.send(
            .show(id: id, text: text),
            timeout: timeout ?? defaultTimeout
        )
    }

    @MainActor
    public func hide(timeout: TimeInterval? = nil) throws {
        let id = UUID()
        try transport.send(
            .hide(id: id),
            timeout: timeout ?? defaultTimeout
        )
    }

    @MainActor
    @discardableResult
    public func step<T>(
        _ title: String,
        timeout: TimeInterval? = nil,
        action: () throws -> T
    ) throws -> T {
        try show(title, timeout: timeout)
        return try XCTContext.runActivity(named: title) { _ in
            try action()
        }
    }

    public func cancel() {
        XCUIElementTapInterceptor.deactivate(session: self)
        transport.cancel()
    }

    @MainActor
    func performInterceptedTap(
        on element: XCUIElement,
        originalTap: () -> Void
    ) {
        var presentationError: Error?
        var didPresentHighlight = false

        if let rect = normalizedRect(for: element) {
            do {
                let id = UUID()
                try transport.send(
                    .highlight(id: id, rect: rect),
                    timeout: defaultTimeout
                )
                didPresentHighlight = true
                Thread.sleep(forTimeInterval: tapHighlightDelay)
            } catch {
                presentationError = error
            }
        }

        originalTap()

        if didPresentHighlight {
            let id = UUID()
            try? transport.send(
                .clearHighlight(id: id),
                timeout: defaultTimeout
            )
        }

        if let presentationError {
            XCTFail(
                "TestStepHUD could not highlight tap: " +
                    presentationError.localizedDescription
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
        var presentationError: Error?
        var didPresent = false

        if let visual {
            do {
                try transport.send(
                    .interaction(id: UUID(), visual: visual),
                    timeout: defaultTimeout
                )
                didPresent = true
                Thread.sleep(forTimeInterval: tapHighlightDelay)
            } catch {
                presentationError = error
            }
        }

        originalAction()

        if didPresent {
            try? transport.send(
                .clearInteraction(id: UUID()),
                timeout: defaultTimeout
            )
        }

        if let presentationError {
            XCTFail(
                "TestStepHUD could not visualize \(name): " +
                    presentationError.localizedDescription
            )
        }
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
