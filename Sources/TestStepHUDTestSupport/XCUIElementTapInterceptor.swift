import Foundation
import ObjectiveC.runtime
import XCTest
import TestStepHUDProtocol

enum XCUIElementTapInterceptor {
    private struct MethodExchange {
        let targetClass: AnyClass
        let original: Selector
        let intercepted: Selector
        let isRequired: Bool

        init(
            targetClass: AnyClass,
            original: Selector,
            intercepted: Selector,
            isRequired: Bool = false
        ) {
            self.targetClass = targetClass
            self.original = original
            self.intercepted = intercepted
            self.isRequired = isRequired
        }
    }

    private final class WeakSessionBox {
        weak var value: TestStepHUDSession?
    }

    private static let lock = NSLock()
    private static let activeSessionBox = WeakSessionBox()
    private static var isInstalled = false

    static func ensureNoActiveSession() throws {
        lock.lock()
        defer { lock.unlock() }

        guard activeSessionBox.value == nil else {
            throw TestStepHUDSessionError.sessionAlreadyActive
        }
    }

    static func activate(session: TestStepHUDSession) throws {
        lock.lock()
        defer { lock.unlock() }

        if
            let activeSession = activeSessionBox.value,
            activeSession !== session
        {
            throw TestStepHUDSessionError.sessionAlreadyActive
        }

        if !isInstalled {
            var resolvedMethods: [(original: Method, intercepted: Method)] = []
            resolvedMethods.reserveCapacity(methodExchanges.count)

            for exchange in methodExchanges {
                let originalMethod = class_getInstanceMethod(
                    exchange.targetClass,
                    exchange.original
                )
                let interceptedMethod = class_getInstanceMethod(
                    exchange.targetClass,
                    exchange.intercepted
                )
                guard
                    let originalMethod,
                    let interceptedMethod,
                    let originalEncoding = method_getTypeEncoding(
                        originalMethod
                    ),
                    let interceptedEncoding = method_getTypeEncoding(
                        interceptedMethod
                    ),
                    String(cString: originalEncoding) ==
                        String(cString: interceptedEncoding)
                else {
                    guard exchange.isRequired else {
                        continue
                    }
                    throw TestStepHUDSessionError
                        .interactionInterceptionUnavailable(
                            NSStringFromSelector(exchange.original)
                        )
                }

                resolvedMethods.append(
                    (original: originalMethod, intercepted: interceptedMethod)
                )
            }

            for methods in resolvedMethods {
                method_exchangeImplementations(
                    methods.original,
                    methods.intercepted
                )
            }
            isInstalled = true
        }

        activeSessionBox.value = session
    }

    static func deactivate(session: TestStepHUDSession) {
        lock.lock()
        defer { lock.unlock() }

        if activeSessionBox.value === session {
            activeSessionBox.value = nil
        }
    }

    fileprivate static func activeSession() -> TestStepHUDSession? {
        lock.lock()
        defer { lock.unlock() }
        return activeSessionBox.value
    }

    private static let methodExchanges: [MethodExchange] = [
        MethodExchange(
            targetClass: XCUIElement.self,
            original: NSSelectorFromString("tap"),
            intercepted: #selector(XCUIElement.testStepHUD_callOriginalTap),
            isRequired: true
        ),
        MethodExchange(
            targetClass: XCUIElement.self,
            original: NSSelectorFromString("doubleTap"),
            intercepted: #selector(
                XCUIElement.testStepHUD_callOriginalDoubleTap
            )
        ),
        MethodExchange(
            targetClass: XCUIElement.self,
            original: NSSelectorFromString("waitForExistenceWithTimeout:"),
            intercepted: #selector(
                XCUIElement.testStepHUD_callOriginalWaitForExistence
            )
        ),
        MethodExchange(
            targetClass: XCUIElement.self,
            original: NSSelectorFromString("typeText:"),
            intercepted: #selector(
                XCUIElement.testStepHUD_callOriginalTypeText
            )
        ),
        MethodExchange(
            targetClass: XCUIElement.self,
            original: NSSelectorFromString("pressForDuration:"),
            intercepted: #selector(
                XCUIElement.testStepHUD_callOriginalPress
            )
        ),
        MethodExchange(
            targetClass: XCUIElement.self,
            original: NSSelectorFromString(
                "pressForDuration:thenDragToElement:"
            ),
            intercepted: #selector(
                XCUIElement.testStepHUD_callOriginalDrag
            )
        ),
        MethodExchange(
            targetClass: XCUIElement.self,
            original: NSSelectorFromString("swipeUp"),
            intercepted: #selector(
                XCUIElement.testStepHUD_callOriginalSwipeUp
            )
        ),
        MethodExchange(
            targetClass: XCUIElement.self,
            original: NSSelectorFromString("swipeDown"),
            intercepted: #selector(
                XCUIElement.testStepHUD_callOriginalSwipeDown
            )
        ),
        MethodExchange(
            targetClass: XCUIElement.self,
            original: NSSelectorFromString("swipeLeft"),
            intercepted: #selector(
                XCUIElement.testStepHUD_callOriginalSwipeLeft
            )
        ),
        MethodExchange(
            targetClass: XCUIElement.self,
            original: NSSelectorFromString("swipeRight"),
            intercepted: #selector(
                XCUIElement.testStepHUD_callOriginalSwipeRight
            )
        ),
        MethodExchange(
            targetClass: XCUICoordinate.self,
            original: NSSelectorFromString("tap"),
            intercepted: #selector(
                XCUICoordinate.testStepHUD_callOriginalTap
            )
        ),
        MethodExchange(
            targetClass: XCUICoordinate.self,
            original: NSSelectorFromString("doubleTap"),
            intercepted: #selector(
                XCUICoordinate.testStepHUD_callOriginalDoubleTap
            )
        ),
        MethodExchange(
            targetClass: XCUICoordinate.self,
            original: NSSelectorFromString("pressForDuration:"),
            intercepted: #selector(
                XCUICoordinate.testStepHUD_callOriginalPress
            )
        ),
        MethodExchange(
            targetClass: XCUICoordinate.self,
            original: NSSelectorFromString(
                "pressForDuration:thenDragToCoordinate:"
            ),
            intercepted: #selector(
                XCUICoordinate.testStepHUD_callOriginalDrag
            )
        )
    ]
}

private extension XCUIElement {
    @MainActor
    @objc(testStepHUD_callOriginalTap)
    dynamic func testStepHUD_callOriginalTap() {
        guard let session = XCUIElementTapInterceptor.activeSession() else {
            testStepHUD_callOriginalTap()
            return
        }

        session.performInterceptedTap(on: self) {
            self.testStepHUD_callOriginalTap()
        }
    }

    @MainActor
    @objc(testStepHUD_callOriginalDoubleTap)
    dynamic func testStepHUD_callOriginalDoubleTap() {
        guard let session = XCUIElementTapInterceptor.activeSession() else {
            testStepHUD_callOriginalDoubleTap()
            return
        }

        session.performInterceptedDoubleTap(on: self) {
            self.testStepHUD_callOriginalDoubleTap()
        }
    }

    @MainActor
    @objc(testStepHUD_callOriginalWaitForExistenceWithTimeout:)
    dynamic func testStepHUD_callOriginalWaitForExistence(
        timeout: TimeInterval
    ) -> Bool {
        guard let session = XCUIElementTapInterceptor.activeSession() else {
            return testStepHUD_callOriginalWaitForExistence(timeout: timeout)
        }

        return session.performInterceptedWaitForExistence(
            on: self,
            timeout: timeout
        ) {
            self.testStepHUD_callOriginalWaitForExistence(timeout: $0)
        }
    }

    @MainActor
    @objc(testStepHUD_callOriginalTypeText:)
    dynamic func testStepHUD_callOriginalTypeText(_ text: String) {
        guard let session = XCUIElementTapInterceptor.activeSession() else {
            testStepHUD_callOriginalTypeText(text)
            return
        }

        session.performInterceptedTyping(on: self) {
            self.testStepHUD_callOriginalTypeText(text)
        }
    }

    @MainActor
    @objc(testStepHUD_callOriginalPressForDuration:)
    dynamic func testStepHUD_callOriginalPress(
        forDuration duration: TimeInterval
    ) {
        guard let session = XCUIElementTapInterceptor.activeSession() else {
            testStepHUD_callOriginalPress(forDuration: duration)
            return
        }

        session.performInterceptedLongPress(
            on: self,
            duration: duration
        ) {
            self.testStepHUD_callOriginalPress(forDuration: duration)
        }
    }

    @MainActor
    @objc(testStepHUD_callOriginalPressForDuration:thenDragToElement:)
    dynamic func testStepHUD_callOriginalDrag(
        forDuration duration: TimeInterval,
        thenDragTo otherElement: XCUIElement
    ) {
        guard let session = XCUIElementTapInterceptor.activeSession() else {
            testStepHUD_callOriginalDrag(
                forDuration: duration,
                thenDragTo: otherElement
            )
            return
        }

        session.performInterceptedDrag(
            from: self,
            to: otherElement,
            duration: duration
        ) {
            self.testStepHUD_callOriginalDrag(
                forDuration: duration,
                thenDragTo: otherElement
            )
        }
    }

    @MainActor
    @objc(testStepHUD_callOriginalSwipeUp)
    dynamic func testStepHUD_callOriginalSwipeUp() {
        performInterceptedSwipe(direction: .up) {
            self.testStepHUD_callOriginalSwipeUp()
        }
    }

    @MainActor
    @objc(testStepHUD_callOriginalSwipeDown)
    dynamic func testStepHUD_callOriginalSwipeDown() {
        performInterceptedSwipe(direction: .down) {
            self.testStepHUD_callOriginalSwipeDown()
        }
    }

    @MainActor
    @objc(testStepHUD_callOriginalSwipeLeft)
    dynamic func testStepHUD_callOriginalSwipeLeft() {
        performInterceptedSwipe(direction: .left) {
            self.testStepHUD_callOriginalSwipeLeft()
        }
    }

    @MainActor
    @objc(testStepHUD_callOriginalSwipeRight)
    dynamic func testStepHUD_callOriginalSwipeRight() {
        performInterceptedSwipe(direction: .right) {
            self.testStepHUD_callOriginalSwipeRight()
        }
    }

    @MainActor
    private func performInterceptedSwipe(
        direction: HUDSwipeDirection,
        originalAction: () -> Void
    ) {
        guard let session = XCUIElementTapInterceptor.activeSession() else {
            originalAction()
            return
        }
        session.performInterceptedSwipe(
            on: self,
            direction: direction,
            originalAction: originalAction
        )
    }
}

private extension XCUICoordinate {
    @MainActor
    @objc(testStepHUD_coordinateCallOriginalTap)
    dynamic func testStepHUD_callOriginalTap() {
        guard let session = XCUIElementTapInterceptor.activeSession() else {
            testStepHUD_callOriginalTap()
            return
        }

        session.performInterceptedCoordinateTap(
            on: self,
            isDoubleTap: false
        ) {
            self.testStepHUD_callOriginalTap()
        }
    }

    @MainActor
    @objc(testStepHUD_coordinateCallOriginalDoubleTap)
    dynamic func testStepHUD_callOriginalDoubleTap() {
        guard let session = XCUIElementTapInterceptor.activeSession() else {
            testStepHUD_callOriginalDoubleTap()
            return
        }

        session.performInterceptedCoordinateTap(
            on: self,
            isDoubleTap: true
        ) {
            self.testStepHUD_callOriginalDoubleTap()
        }
    }

    @MainActor
    @objc(testStepHUD_coordinateCallOriginalPressForDuration:)
    dynamic func testStepHUD_callOriginalPress(
        forDuration duration: TimeInterval
    ) {
        guard let session = XCUIElementTapInterceptor.activeSession() else {
            testStepHUD_callOriginalPress(forDuration: duration)
            return
        }

        session.performInterceptedCoordinateLongPress(
            on: self,
            duration: duration
        ) {
            self.testStepHUD_callOriginalPress(forDuration: duration)
        }
    }

    @MainActor
    @objc(testStepHUD_coordinateCallOriginalPressForDuration:thenDragToCoordinate:)
    dynamic func testStepHUD_callOriginalDrag(
        forDuration duration: TimeInterval,
        thenDragTo otherCoordinate: XCUICoordinate
    ) {
        guard let session = XCUIElementTapInterceptor.activeSession() else {
            testStepHUD_callOriginalDrag(
                forDuration: duration,
                thenDragTo: otherCoordinate
            )
            return
        }

        session.performInterceptedCoordinateDrag(
            from: self,
            to: otherCoordinate,
            duration: duration
        ) {
            self.testStepHUD_callOriginalDrag(
                forDuration: duration,
                thenDragTo: otherCoordinate
            )
        }
    }
}
