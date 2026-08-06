import UIKit
import TestStepHUDProtocol

@MainActor
final class HUDWindowController {
    typealias ShowCompletion = @Sendable (Result<Void, Error>) -> Void

    private let configuration: TestStepHUD.Configuration
    private var window: PassthroughHUDWindow?
    private var rootViewController: HUDViewController?
    private var pendingShow: (text: String, completion: ShowCompletion)?
    private var pendingTestCase: (
        testCase: HUDTestCase,
        completion: ShowCompletion
    )?
    private var pendingFailure: (
        failure: HUDTestFailure,
        completion: ShowCompletion
    )?
    private var pendingHighlight: (
        rect: HUDNormalizedRect,
        style: HUDHighlightStyle,
        completion: ShowCompletion
    )?
    private var pendingInteraction: (
        visual: HUDInteraction,
        completion: ShowCompletion
    )?
    private var currentText: String?
    private var currentFailure: HUDTestFailure?
    private var sceneActivationObserver: NSObjectProtocol?

    init(configuration: TestStepHUD.Configuration) {
        self.configuration = configuration
        sceneActivationObserver = NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.activatePendingShowIfPossible()
            }
        }
    }

    deinit {
        if let sceneActivationObserver {
            NotificationCenter.default.removeObserver(sceneActivationObserver)
        }
    }

    func show(
        _ text: String,
        completion: @escaping ShowCompletion
    ) {
        currentText = text
        currentFailure = nil
        pendingFailure?.completion(
            .failure(HUDPresentationError.supersededBeforePresentation)
        )
        pendingFailure = nil
        guard let scene = foregroundScene() else {
            pendingShow?.completion(
                .failure(HUDPresentationError.supersededBeforePresentation)
            )
            pendingShow = (text, completion)
            return
        }

        present(text, in: scene)
        completion(.success(()))
    }

    func showTestCase(
        _ testCase: HUDTestCase,
        completion: @escaping ShowCompletion
    ) {
        currentText = nil
        currentFailure = nil
        pendingShow?.completion(
            .failure(HUDPresentationError.supersededBeforePresentation)
        )
        pendingShow = nil
        pendingFailure?.completion(
            .failure(HUDPresentationError.supersededBeforePresentation)
        )
        pendingFailure = nil
        guard let scene = foregroundScene() else {
            pendingTestCase?.completion(
                .failure(HUDPresentationError.supersededBeforePresentation)
            )
            pendingTestCase = (testCase, completion)
            return
        }

        present(testCase, in: scene)
        completion(.success(()))
    }

    func showFailure(
        _ failure: HUDTestFailure,
        completion: @escaping ShowCompletion
    ) {
        currentText = nil
        currentFailure = failure

        pendingShow?.completion(
            .failure(HUDPresentationError.supersededBeforePresentation)
        )
        pendingShow = nil
        pendingTestCase?.completion(
            .failure(HUDPresentationError.supersededBeforePresentation)
        )
        pendingTestCase = nil
        pendingHighlight?.completion(
            .failure(HUDPresentationError.supersededBeforePresentation)
        )
        pendingHighlight = nil
        pendingInteraction?.completion(
            .failure(HUDPresentationError.supersededBeforePresentation)
        )
        pendingInteraction = nil
        pendingFailure?.completion(
            .failure(HUDPresentationError.supersededBeforePresentation)
        )
        pendingFailure = nil

        guard let scene = foregroundScene() else {
            pendingFailure = (failure, completion)
            return
        }

        present(failure, in: scene)
        completion(.success(()))
    }

    func hide() {
        pendingShow?.completion(
            .failure(HUDPresentationError.hiddenBeforePresentation)
        )
        pendingShow = nil
        pendingTestCase?.completion(
            .failure(HUDPresentationError.hiddenBeforePresentation)
        )
        pendingTestCase = nil
        pendingFailure?.completion(
            .failure(HUDPresentationError.hiddenBeforePresentation)
        )
        pendingFailure = nil
        currentText = nil
        currentFailure = nil
        clearHighlight()
        clearInteraction()
        rootViewController?.hideStep()
        rootViewController?.hideTestCase()
        rootViewController?.hideFailure()
        window?.isHidden = true
    }

    func highlight(
        _ rect: HUDNormalizedRect,
        style: HUDHighlightStyle,
        completion: @escaping ShowCompletion
    ) {
        guard let scene = foregroundScene() else {
            pendingHighlight?.completion(
                .failure(HUDPresentationError.supersededBeforePresentation)
            )
            pendingHighlight = (rect, style, completion)
            return
        }

        presentHighlight(rect, style: style, in: scene)
        completion(.success(()))
    }

    func clearHighlight() {
        pendingHighlight?.completion(
            .failure(HUDPresentationError.hiddenBeforePresentation)
        )
        pendingHighlight = nil
        guard let rootViewController else {
            window?.isHidden = true
            return
        }

        rootViewController.clearHighlight { [weak self] in
            guard let self, !hasPersistentContent else { return }
            window?.isHidden = true
        }
    }

    func showInteraction(
        _ interaction: HUDInteraction,
        completion: @escaping ShowCompletion
    ) {
        guard let scene = foregroundScene() else {
            pendingInteraction?.completion(
                .failure(HUDPresentationError.supersededBeforePresentation)
            )
            pendingInteraction = (interaction, completion)
            return
        }

        presentInteraction(interaction, in: scene)
        completion(.success(()))
    }

    func clearInteraction() {
        pendingInteraction?.completion(
            .failure(HUDPresentationError.hiddenBeforePresentation)
        )
        pendingInteraction = nil
        guard let rootViewController else {
            window?.isHidden = true
            return
        }

        rootViewController.clearInteraction { [weak self] in
            guard let self, !hasPersistentContent else { return }
            window?.isHidden = true
        }
    }

    private func activatePendingShowIfPossible() {
        guard let scene = foregroundScene() else { return }

        if let pendingShow {
            self.pendingShow = nil
            present(pendingShow.text, in: scene)
            pendingShow.completion(.success(()))
        }

        if let pendingTestCase {
            self.pendingTestCase = nil
            present(pendingTestCase.testCase, in: scene)
            pendingTestCase.completion(.success(()))
        }

        if let pendingFailure {
            self.pendingFailure = nil
            present(pendingFailure.failure, in: scene)
            pendingFailure.completion(.success(()))
        }

        if let pendingHighlight {
            self.pendingHighlight = nil
            presentHighlight(
                pendingHighlight.rect,
                style: pendingHighlight.style,
                in: scene
            )
            pendingHighlight.completion(.success(()))
        }

        if let pendingInteraction {
            self.pendingInteraction = nil
            presentInteraction(pendingInteraction.visual, in: scene)
            pendingInteraction.completion(.success(()))
        }
    }

    private func present(_ text: String, in scene: UIWindowScene) {
        let viewController = ensureWindow(in: scene)
        viewController.show(text)
        window?.isHidden = false

        // The show ACK is emitted only after this synchronous main-thread layout.
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()
    }

    private func present(_ testCase: HUDTestCase, in scene: UIWindowScene) {
        let viewController = ensureWindow(in: scene)
        viewController.showTestCase(testCase)
        window?.isHidden = false

        // The show ACK is emitted only after this synchronous main-thread layout.
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()
    }

    private func present(_ failure: HUDTestFailure, in scene: UIWindowScene) {
        let viewController = ensureWindow(in: scene)
        viewController.showFailure(failure)
        window?.isHidden = false

        // The failure ACK is emitted only after synchronous main-thread layout.
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()
    }

    private func presentHighlight(
        _ rect: HUDNormalizedRect,
        style: HUDHighlightStyle,
        in scene: UIWindowScene
    ) {
        let viewController = ensureWindow(in: scene)
        viewController.showHighlight(rect, style: style) { [weak self] in
            self?.clearHighlight()
        }
        window?.isHidden = false
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()
    }

    private func presentInteraction(
        _ interaction: HUDInteraction,
        in scene: UIWindowScene
    ) {
        let viewController = ensureWindow(in: scene)
        viewController.showInteraction(interaction)
        window?.isHidden = false
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()
    }

    private func ensureWindow(in scene: UIWindowScene) -> HUDViewController {
        if window?.windowScene !== scene {
            let viewController = HUDViewController(configuration: configuration)
            let window = PassthroughHUDWindow(windowScene: scene)
            window.backgroundColor = .clear
            window.windowLevel = .alert - 1
            window.rootViewController = viewController
            window.isAccessibilityElement = false
            window.accessibilityElementsHidden = true

            self.rootViewController = viewController
            self.window = window
            viewController.loadViewIfNeeded()

            if let currentFailure {
                viewController.showFailure(currentFailure)
            } else if let currentText {
                viewController.show(currentText)
            }
        }

        return rootViewController!
    }

    private var hasPersistentContent: Bool {
        currentText != nil || currentFailure != nil
    }

    private func foregroundScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }

        return scenes.first(where: { scene in
            scene.windows.contains(where: \.isKeyWindow)
        }) ?? scenes.first
    }
}

private enum HUDPresentationError: Error, LocalizedError {
    case supersededBeforePresentation
    case hiddenBeforePresentation

    var errorDescription: String? {
        switch self {
        case .supersededBeforePresentation:
            return "A newer HUD step arrived before the scene became active."
        case .hiddenBeforePresentation:
            return "The HUD was hidden before the scene became active."
        }
    }
}

private final class PassthroughHUDWindow: UIWindow {
    override var canBecomeKey: Bool {
        false
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        nil
    }
}

private final class HUDViewController: UIViewController {
    private static let followIdleInterval: TimeInterval = 5

    private let configuration: TestStepHUD.Configuration
    private let cardView = UIView()
    private let cardSurfaceView = UIView()
    private let label = UILabel()
    private lazy var testCaseView = TestCaseCardView(
        configuration: configuration
    )
    private let failureView = FailureCardView()
    private let highlightView = UIView()
    private lazy var interactionOverlayView = InteractionOverlayView(
        accentColor: configuration.highlightStrokeColor,
        fillColor: configuration.highlightFillColor
    )
    private var normalizedHighlightRect: HUDNormalizedRect?
    private var followedHighlightRect: HUDNormalizedRect?
    private var followReturnWorkItem: DispatchWorkItem?
    private var highlightAnimationGeneration = 0

    init(configuration: TestStepHUD.Configuration) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let rootView = UIView()
        rootView.backgroundColor = .clear
        rootView.isUserInteractionEnabled = false
        rootView.isAccessibilityElement = false
        rootView.accessibilityElementsHidden = true
        view = rootView

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.isAccessibilityElement = false
        cardView.isHidden = true

        cardSurfaceView.translatesAutoresizingMaskIntoConstraints = false
        cardSurfaceView.backgroundColor = configuration.cardColor
        cardSurfaceView.layer.cornerRadius = 14
        cardSurfaceView.layer.cornerCurve = .continuous
        cardSurfaceView.layer.shadowColor = UIColor.black.cgColor
        cardSurfaceView.layer.shadowOpacity = 0.18
        cardSurfaceView.layer.shadowRadius = 12
        cardSurfaceView.layer.shadowOffset = CGSize(width: 0, height: 5)
        cardSurfaceView.isAccessibilityElement = false

        highlightView.backgroundColor = configuration.highlightFillColor
        highlightView.layer.shadowColor =
            configuration.highlightStrokeColor.cgColor
        highlightView.layer.shadowOpacity = 0.35
        highlightView.layer.shadowRadius = 8
        highlightView.layer.shadowOffset = .zero
        highlightView.isUserInteractionEnabled = false
        highlightView.isAccessibilityElement = false
        highlightView.isHidden = true

        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = UIFontMetrics(forTextStyle: .headline).scaledFont(
            for: .systemFont(
                ofSize: configuration.fontSize,
                weight: .semibold
            ),
            maximumPointSize: 42
        )
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textAlignment = configuration.labelAlignment
        label.lineBreakMode = .byWordWrapping
        label.isAccessibilityElement = false

        interactionOverlayView.translatesAutoresizingMaskIntoConstraints = false
        interactionOverlayView.isAccessibilityElement = false
        testCaseView.translatesAutoresizingMaskIntoConstraints = false
        failureView.translatesAutoresizingMaskIntoConstraints = false

        rootView.addSubview(interactionOverlayView)
        rootView.addSubview(highlightView)
        rootView.addSubview(cardView)
        rootView.addSubview(testCaseView)
        rootView.addSubview(failureView)
        cardView.addSubview(cardSurfaceView)
        cardSurfaceView.addSubview(label)

        let safeArea = rootView.safeAreaLayoutGuide
        let widthConstraint = cardView.widthAnchor.constraint(
            lessThanOrEqualTo: safeArea.widthAnchor,
            multiplier: 0.9
        )
        widthConstraint.priority = .required

        var constraints = [
            interactionOverlayView.leadingAnchor.constraint(
                equalTo: rootView.leadingAnchor
            ),
            interactionOverlayView.trailingAnchor.constraint(
                equalTo: rootView.trailingAnchor
            ),
            interactionOverlayView.topAnchor.constraint(
                equalTo: rootView.topAnchor
            ),
            interactionOverlayView.bottomAnchor.constraint(
                equalTo: rootView.bottomAnchor
            ),
            testCaseView.centerXAnchor.constraint(
                equalTo: safeArea.centerXAnchor
            ),
            testCaseView.centerYAnchor.constraint(
                equalTo: safeArea.centerYAnchor
            ),
            testCaseView.widthAnchor.constraint(
                equalTo: safeArea.widthAnchor,
                multiplier: 0.88
            ),
            failureView.centerXAnchor.constraint(
                equalTo: safeArea.centerXAnchor
            ),
            failureView.centerYAnchor.constraint(
                equalTo: safeArea.centerYAnchor
            ),
            failureView.widthAnchor.constraint(
                equalTo: safeArea.widthAnchor,
                multiplier: 0.88
            ),
            cardView.centerXAnchor.constraint(equalTo: safeArea.centerXAnchor),
            widthConstraint,
            cardSurfaceView.leadingAnchor.constraint(
                equalTo: cardView.leadingAnchor
            ),
            cardSurfaceView.trailingAnchor.constraint(
                equalTo: cardView.trailingAnchor
            ),
            cardSurfaceView.topAnchor.constraint(
                equalTo: cardView.topAnchor
            ),
            cardSurfaceView.bottomAnchor.constraint(
                equalTo: cardView.bottomAnchor
            ),
            label.leadingAnchor.constraint(
                equalTo: cardSurfaceView.leadingAnchor,
                constant: 18
            ),
            label.trailingAnchor.constraint(
                equalTo: cardSurfaceView.trailingAnchor,
                constant: -18
            ),
            label.topAnchor.constraint(
                equalTo: cardSurfaceView.topAnchor,
                constant: 12
            ),
            label.bottomAnchor.constraint(
                equalTo: cardSurfaceView.bottomAnchor,
                constant: -12
            )
        ]

        switch configuration.position {
        case .top:
            constraints.append(
                cardView.topAnchor.constraint(
                    equalTo: safeArea.topAnchor,
                    constant: 12
                )
            )
        case .center:
            constraints.append(
                cardView.centerYAnchor.constraint(
                    equalTo: safeArea.centerYAnchor
                )
            )
        case .bottom:
            constraints.append(
                cardView.bottomAnchor.constraint(
                    equalTo: safeArea.bottomAnchor,
                    constant: -12
                )
            )
        }

        NSLayoutConstraint.activate(constraints)
    }

    func show(_ text: String) {
        hideFailure()
        label.text = text
        cardView.isHidden = false
        view.setNeedsLayout()
        view.layoutIfNeeded()
        updateFollowPosition(animated: false)
        pulseHUDIfNeeded()
    }

    func hideStep() {
        followReturnWorkItem?.cancel()
        followReturnWorkItem = nil
        followedHighlightRect = nil
        cardView.layer.removeAllAnimations()
        cardView.transform = .identity
        cardSurfaceView.layer.removeAllAnimations()
        cardSurfaceView.alpha = 1
        cardSurfaceView.transform = .identity
        cardView.isHidden = true
        label.text = nil
    }

    func showTestCase(_ testCase: HUDTestCase) {
        hideStep()
        hideFailure()
        testCaseView.configure(with: testCase)
        testCaseView.isHidden = false
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    func hideTestCase() {
        testCaseView.isHidden = true
        testCaseView.reset()
    }

    func showFailure(_ failure: HUDTestFailure) {
        hideStep()
        hideTestCase()
        resetHighlight()
        interactionOverlayView.reset()
        failureView.configure(with: failure)
        failureView.isHidden = false
        view.setNeedsLayout()
        view.layoutIfNeeded()
        failureView.presentAnimated()
    }

    func hideFailure() {
        failureView.layer.removeAllAnimations()
        failureView.alpha = 1
        failureView.transform = .identity
        failureView.isHidden = true
        failureView.reset()
    }

    func showHighlight(
        _ rect: HUDNormalizedRect,
        style: HUDHighlightStyle,
        completion: @escaping () -> Void
    ) {
        view.layoutIfNeeded()
        normalizedHighlightRect = rect
        layoutHighlight()

        highlightAnimationGeneration += 1
        let generation = highlightAnimationGeneration
        applyHighlightStyle(style)
        highlightView.layer.removeAllAnimations()
        highlightView.isHidden = false
        highlightView.alpha = 1

        UIView.animateKeyframes(
            withDuration: 0.44,
            delay: 0,
            options: [
                .allowUserInteraction,
                .beginFromCurrentState,
                .calculationModeLinear
            ]
        ) {
            UIView.addKeyframe(
                withRelativeStartTime: 0,
                relativeDuration: 0.25
            ) {
                self.highlightView.alpha = 0.3
            }
            UIView.addKeyframe(
                withRelativeStartTime: 0.25,
                relativeDuration: 0.25
            ) {
                self.highlightView.alpha = 1
            }
            UIView.addKeyframe(
                withRelativeStartTime: 0.5,
                relativeDuration: 0.25
            ) {
                self.highlightView.alpha = 0.3
            }
            UIView.addKeyframe(
                withRelativeStartTime: 0.75,
                relativeDuration: 0.25
            ) {
                self.highlightView.alpha = 1
            }
        } completion: { [weak self] _ in
            guard
                let self,
                style == .existence,
                highlightAnimationGeneration == generation
            else {
                return
            }
            completion()
        }

        guard configuration.movesHUDToHighlightedElement else { return }
        follow(rect)
    }

    private func applyHighlightStyle(_ style: HUDHighlightStyle) {
        switch style {
        case .interaction:
            highlightView.backgroundColor = configuration.highlightFillColor
            highlightView.layer.shadowColor =
                configuration.highlightStrokeColor.cgColor
        case .existence:
            highlightView.backgroundColor =
                configuration.existenceHighlightFillColor
            highlightView.layer.shadowColor =
                configuration.existenceHighlightStrokeColor.cgColor
        }
    }

    func clearHighlight(completion: @escaping () -> Void) {
        normalizedHighlightRect = nil

        guard !highlightView.isHidden else {
            completion()
            return
        }

        highlightAnimationGeneration += 1
        let generation = highlightAnimationGeneration
        let visibleAlpha = CGFloat(
            highlightView.layer.presentation()?.opacity ?? 1
        )
        highlightView.layer.removeAllAnimations()
        highlightView.alpha = visibleAlpha

        UIView.animate(
            withDuration: 0.14,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseOut]
        ) {
            self.highlightView.alpha = 0
        } completion: { [weak self] _ in
            guard
                let self,
                highlightAnimationGeneration == generation
            else {
                return
            }
            highlightView.isHidden = true
            highlightView.alpha = 1
            completion()
        }
    }

    private func resetHighlight() {
        normalizedHighlightRect = nil
        highlightAnimationGeneration += 1
        highlightView.layer.removeAllAnimations()
        highlightView.isHidden = true
        highlightView.alpha = 1
    }

    func showInteraction(_ interaction: HUDInteraction) {
        view.layoutIfNeeded()
        interactionOverlayView.show(interaction)

        guard configuration.movesHUDToHighlightedElement else { return }
        if let rect = interaction.rect {
            follow(rect)
        } else if let start = interaction.start {
            follow(start)
        }
    }

    func clearInteraction(completion: @escaping () -> Void) {
        interactionOverlayView.clear(completion: completion)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutHighlight()
        updateFollowPosition(animated: false)
    }

    private func layoutHighlight() {
        guard let normalizedHighlightRect else { return }

        let bounds = view.bounds
        let rawFrame = CGRect(
            x: bounds.minX +
                bounds.width * CGFloat(normalizedHighlightRect.x),
            y: bounds.minY +
                bounds.height * CGFloat(normalizedHighlightRect.y),
            width: bounds.width * CGFloat(normalizedHighlightRect.width),
            height: bounds.height * CGFloat(normalizedHighlightRect.height)
        )
        let expandedFrame = rawFrame.insetBy(dx: -6, dy: -6)
        let visibleBounds = bounds.insetBy(dx: 2, dy: 2)
        let frame = expandedFrame.intersection(visibleBounds)

        guard !frame.isEmpty, !frame.isNull else {
            highlightView.isHidden = true
            return
        }

        highlightView.frame = frame.integral
        highlightView.layer.cornerRadius = min(16, frame.height / 3)
        highlightView.layer.cornerCurve = .continuous
    }

    private func scheduleReturnHome() {
        followReturnWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.returnHome()
        }
        followReturnWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.followIdleInterval,
            execute: workItem
        )
    }

    private func follow(_ rect: HUDNormalizedRect) {
        followedHighlightRect = rect
        updateFollowPosition(animated: true)
        scheduleReturnHome()
    }

    private func follow(_ point: HUDNormalizedPoint) {
        let size = 0.002
        let x = min(max(point.x - size / 2, 0), 1 - size)
        let y = min(max(point.y - size / 2, 0), 1 - size)
        follow(
            HUDNormalizedRect(
                x: x,
                y: y,
                width: size,
                height: size
            )
        )
    }

    private func returnHome() {
        followReturnWorkItem = nil
        followedHighlightRect = nil

        UIView.animate(
            withDuration: 0.28,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseInOut]
        ) {
            self.cardView.transform = .identity
        }
    }

    private func updateFollowPosition(animated: Bool) {
        guard
            configuration.movesHUDToHighlightedElement,
            let followedHighlightRect,
            !cardView.isHidden,
            cardView.bounds.width > 0,
            cardView.bounds.height > 0
        else {
            return
        }

        let targetFrame = frame(for: followedHighlightRect)
        let safeFrame = view.safeAreaLayoutGuide.layoutFrame
        guard
            !targetFrame.isEmpty,
            !safeFrame.isEmpty
        else {
            return
        }

        let halfWidth = cardView.bounds.width / 2
        let halfHeight = cardView.bounds.height / 2
        let horizontalInset: CGFloat = 8
        let gap: CGFloat = 16
        let minimumX = safeFrame.minX + halfWidth + horizontalInset
        let maximumX = safeFrame.maxX - halfWidth - horizontalInset
        let targetX: CGFloat
        if minimumX <= maximumX {
            targetX = min(max(targetFrame.midX, minimumX), maximumX)
        } else {
            targetX = safeFrame.midX
        }

        let minimumY = safeFrame.minY + halfHeight
        let maximumY = safeFrame.maxY - halfHeight
        let aboveY = targetFrame.minY - gap - halfHeight
        let belowY = targetFrame.maxY + gap + halfHeight
        let canFitAbove = aboveY >= minimumY
        let canFitBelow = belowY <= maximumY

        let targetY: CGFloat
        if targetFrame.midY >= safeFrame.midY, canFitAbove {
            targetY = aboveY
        } else if canFitBelow {
            targetY = belowY
        } else if canFitAbove {
            targetY = aboveY
        } else {
            let preferredY = targetFrame.midY >= safeFrame.midY
                ? aboveY
                : belowY
            targetY = min(max(preferredY, minimumY), maximumY)
        }

        let transform = CGAffineTransform(
            translationX: targetX - cardView.center.x,
            y: targetY - cardView.center.y
        )
        let changes = {
            self.cardView.transform = transform
        }

        guard animated else {
            changes()
            return
        }

        UIView.animate(
            withDuration: 0.32,
            delay: 0,
            usingSpringWithDamping: 0.86,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            changes()
        }
    }

    private func frame(for rect: HUDNormalizedRect) -> CGRect {
        let bounds = view.bounds
        return CGRect(
            x: bounds.minX + bounds.width * CGFloat(rect.x),
            y: bounds.minY + bounds.height * CGFloat(rect.y),
            width: bounds.width * CGFloat(rect.width),
            height: bounds.height * CGFloat(rect.height)
        )
    }

    private func pulseHUDIfNeeded() {
        guard configuration.pulsesHUDOnStepChange else { return }

        cardSurfaceView.layer.removeAllAnimations()
        cardSurfaceView.alpha = 1
        cardSurfaceView.transform = .identity

        UIView.animateKeyframes(
            withDuration: 0.54,
            delay: 0,
            options: [
                .allowUserInteraction,
                .beginFromCurrentState,
                .calculationModeCubic
            ]
        ) {
            UIView.addKeyframe(
                withRelativeStartTime: 0,
                relativeDuration: 0.25
            ) {
                self.cardSurfaceView.alpha = 0.88
                self.cardSurfaceView.transform = CGAffineTransform(
                    scaleX: 1.035,
                    y: 1.035
                )
            }
            UIView.addKeyframe(
                withRelativeStartTime: 0.25,
                relativeDuration: 0.25
            ) {
                self.cardSurfaceView.alpha = 1
                self.cardSurfaceView.transform = .identity
            }
            UIView.addKeyframe(
                withRelativeStartTime: 0.5,
                relativeDuration: 0.25
            ) {
                self.cardSurfaceView.alpha = 0.94
                self.cardSurfaceView.transform = CGAffineTransform(
                    scaleX: 1.018,
                    y: 1.018
                )
            }
            UIView.addKeyframe(
                withRelativeStartTime: 0.75,
                relativeDuration: 0.25
            ) {
                self.cardSurfaceView.alpha = 1
                self.cardSurfaceView.transform = .identity
            }
        }
    }
}

private final class InteractionOverlayView: UIView {
    private let accentColor: UIColor
    private let fillColor: UIColor
    private let primaryLayer = CAShapeLayer()
    private let secondaryLayer = CAShapeLayer()
    private let badgeLabel = UILabel()
    private var interaction: HUDInteraction?
    private var renderedBounds = CGRect.null
    private var animationGeneration = 0

    init(accentColor: UIColor, fillColor: UIColor) {
        self.accentColor = accentColor
        self.fillColor = fillColor
        super.init(frame: .zero)

        isUserInteractionEnabled = false
        isHidden = true

        [primaryLayer, secondaryLayer].forEach {
            $0.lineCap = .round
            $0.lineJoin = .round
            layer.addSublayer($0)
        }

        badgeLabel.backgroundColor = UIColor(
            red: 0.08,
            green: 0.11,
            blue: 0.18,
            alpha: 0.92
        )
        badgeLabel.textColor = .white
        badgeLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 10
        badgeLabel.layer.cornerCurve = .continuous
        badgeLabel.layer.masksToBounds = true
        badgeLabel.isAccessibilityElement = false
        badgeLabel.isHidden = true
        addSubview(badgeLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard
            interaction != nil,
            bounds != renderedBounds
        else {
            return
        }
        render(animated: false)
    }

    func show(_ interaction: HUDInteraction) {
        animationGeneration += 1
        self.interaction = interaction
        layer.removeAllAnimations()
        alpha = 1
        isHidden = false
        setNeedsLayout()
        layoutIfNeeded()
        render(animated: true)
    }

    func clear(completion: @escaping () -> Void) {
        guard !isHidden else {
            completion()
            return
        }

        animationGeneration += 1
        let generation = animationGeneration
        UIView.animate(
            withDuration: 0.14,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseOut]
        ) {
            self.alpha = 0
        } completion: { [weak self] _ in
            guard
                let self,
                animationGeneration == generation
            else {
                return
            }
            resetLayers()
            interaction = nil
            isHidden = true
            alpha = 1
            completion()
        }
    }

    func reset() {
        animationGeneration += 1
        layer.removeAllAnimations()
        resetLayers()
        interaction = nil
        renderedBounds = .null
        isHidden = true
        alpha = 1
    }

    private func render(animated: Bool) {
        guard let interaction else { return }
        renderedBounds = bounds
        resetLayers()

        switch interaction.kind {
        case .swipe:
            guard
                let normalizedRect = interaction.rect,
                let direction = interaction.direction
            else {
                return
            }
            renderSwipe(
                in: frame(for: normalizedRect),
                direction: direction,
                animated: animated
            )
        case .typing:
            guard let normalizedRect = interaction.rect else { return }
            renderTyping(
                in: frame(for: normalizedRect),
                animated: animated
            )
        case .longPress:
            guard let center = center(for: interaction) else { return }
            renderLongPress(
                at: center,
                duration: interaction.duration ?? 0,
                animated: animated
            )
        case .drag:
            guard
                let start = interaction.start.map(point(for:)),
                let end = interaction.end.map(point(for:))
            else {
                return
            }
            renderArrow(from: start, to: end, animated: animated)
        case .coordinateTap:
            guard let start = interaction.start else { return }
            renderTap(at: point(for: start), animated: animated)
        case .doubleTap:
            renderDoubleTap(interaction, animated: animated)
        }
    }

    private func resetLayers() {
        [primaryLayer, secondaryLayer].forEach {
            $0.removeAllAnimations()
            $0.path = nil
            $0.fillColor = UIColor.clear.cgColor
            $0.strokeColor = UIColor.clear.cgColor
            $0.lineWidth = 0
            $0.opacity = 1
            $0.strokeStart = 0
            $0.strokeEnd = 1
            $0.shadowOpacity = 0
        }
        badgeLabel.isHidden = true
        badgeLabel.text = nil
    }

    private func renderSwipe(
        in rect: CGRect,
        direction: HUDSwipeDirection,
        animated: Bool
    ) {
        let horizontalInset = min(
            max(8, rect.width * 0.22),
            rect.width * 0.4
        )
        let verticalInset = min(
            max(8, rect.height * 0.22),
            rect.height * 0.4
        )
        let start: CGPoint
        let end: CGPoint

        switch direction {
        case .up:
            start = CGPoint(x: rect.midX, y: rect.maxY - verticalInset)
            end = CGPoint(x: rect.midX, y: rect.minY + verticalInset)
        case .down:
            start = CGPoint(x: rect.midX, y: rect.minY + verticalInset)
            end = CGPoint(x: rect.midX, y: rect.maxY - verticalInset)
        case .left:
            start = CGPoint(x: rect.maxX - horizontalInset, y: rect.midY)
            end = CGPoint(x: rect.minX + horizontalInset, y: rect.midY)
        case .right:
            start = CGPoint(x: rect.minX + horizontalInset, y: rect.midY)
            end = CGPoint(x: rect.maxX - horizontalInset, y: rect.midY)
        }

        renderArrow(from: start, to: end, animated: animated)
    }

    private func renderArrow(
        from start: CGPoint,
        to end: CGPoint,
        animated: Bool
    ) {
        let path = UIBezierPath()
        path.move(to: start)
        path.addLine(to: end)

        let angle = atan2(end.y - start.y, end.x - start.x)
        let distance = hypot(end.x - start.x, end.y - start.y)
        let arrowLength = min(30, max(16, distance * 0.16))
        let spread = CGFloat.pi / 6
        for wingAngle in [angle + .pi - spread, angle + .pi + spread] {
            path.move(to: end)
            path.addLine(
                to: CGPoint(
                    x: end.x + cos(wingAngle) * arrowLength,
                    y: end.y + sin(wingAngle) * arrowLength
                )
            )
        }

        primaryLayer.path = path.cgPath
        primaryLayer.strokeColor = accentColor.cgColor
        primaryLayer.fillColor = UIColor.clear.cgColor
        primaryLayer.lineWidth = 7
        primaryLayer.shadowColor = accentColor.cgColor
        primaryLayer.shadowOpacity = 0.55
        primaryLayer.shadowRadius = 8
        primaryLayer.shadowOffset = .zero

        secondaryLayer.path = UIBezierPath(
            ovalIn: CGRect(
                x: start.x - 8,
                y: start.y - 8,
                width: 16,
                height: 16
            )
        ).cgPath
        secondaryLayer.fillColor = accentColor.cgColor

        guard animated else { return }
        let draw = CABasicAnimation(keyPath: "strokeEnd")
        draw.fromValue = 0
        draw.toValue = 1
        draw.duration = 0.36
        draw.timingFunction = CAMediaTimingFunction(name: .easeOut)
        primaryLayer.add(draw, forKey: "draw")
        addOpacityPulse(to: secondaryLayer, duration: 0.44)
    }

    private func renderTyping(in rect: CGRect, animated: Bool) {
        let highlightedRect = rect.insetBy(dx: -6, dy: -6)
            .intersection(bounds.insetBy(dx: 2, dy: 2))
        primaryLayer.path = UIBezierPath(
            roundedRect: highlightedRect,
            cornerRadius: min(14, highlightedRect.height / 3)
        ).cgPath
        primaryLayer.fillColor = fillColor.cgColor
        primaryLayer.strokeColor = accentColor.cgColor
        primaryLayer.lineWidth = 3

        badgeLabel.text = "Typing…"
        badgeLabel.isHidden = false
        let fittingSize = badgeLabel.sizeThatFits(
            CGSize(width: 180, height: 36)
        )
        let badgeSize = CGSize(
            width: fittingSize.width + 22,
            height: 28
        )
        let minimumX: CGFloat = 8
        let maximumX = bounds.maxX - badgeSize.width - 8
        let x = min(
            max(highlightedRect.midX - badgeSize.width / 2, minimumX),
            maximumX
        )
        let proposedAbove = highlightedRect.minY - badgeSize.height - 8
        let y = proposedAbove >= bounds.minY + 8
            ? proposedAbove
            : highlightedRect.maxY + 8
        badgeLabel.frame = CGRect(origin: CGPoint(x: x, y: y), size: badgeSize)

        guard animated else { return }
        addOpacityPulse(to: primaryLayer, duration: 0.5)
    }

    private func renderLongPress(
        at center: CGPoint,
        duration: TimeInterval,
        animated: Bool
    ) {
        let radius: CGFloat = 42
        let circle = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        primaryLayer.path = UIBezierPath(ovalIn: circle).cgPath
        primaryLayer.fillColor = accentColor.withAlphaComponent(0.12).cgColor
        primaryLayer.strokeColor = accentColor.cgColor
        primaryLayer.lineWidth = 6

        secondaryLayer.path = UIBezierPath(
            ovalIn: CGRect(
                x: center.x - 8,
                y: center.y - 8,
                width: 16,
                height: 16
            )
        ).cgPath
        secondaryLayer.fillColor = accentColor.cgColor

        guard animated else { return }
        let progress = CABasicAnimation(keyPath: "strokeEnd")
        progress.fromValue = 0
        progress.toValue = 1
        progress.duration = max(0.5, duration + 0.35)
        progress.timingFunction = CAMediaTimingFunction(name: .linear)
        primaryLayer.add(progress, forKey: "progress")
        addOpacityPulse(to: secondaryLayer, duration: 0.5)
    }

    private func renderTap(at point: CGPoint, animated: Bool) {
        primaryLayer.path = UIBezierPath(
            ovalIn: CGRect(
                x: point.x - 30,
                y: point.y - 30,
                width: 60,
                height: 60
            )
        ).cgPath
        primaryLayer.fillColor = fillColor.cgColor
        primaryLayer.strokeColor = accentColor.cgColor
        primaryLayer.lineWidth = 4

        secondaryLayer.path = UIBezierPath(
            ovalIn: CGRect(
                x: point.x - 8,
                y: point.y - 8,
                width: 16,
                height: 16
            )
        ).cgPath
        secondaryLayer.fillColor = accentColor.cgColor

        guard animated else { return }
        addOpacityPulse(to: primaryLayer, duration: 0.42)
        addOpacityPulse(to: secondaryLayer, duration: 0.32)
    }

    private func renderDoubleTap(
        _ interaction: HUDInteraction,
        animated: Bool
    ) {
        if let rect = interaction.rect {
            let frame = frame(for: rect).insetBy(dx: -6, dy: -6)
            primaryLayer.path = UIBezierPath(
                roundedRect: frame,
                cornerRadius: min(16, frame.height / 3)
            ).cgPath
            primaryLayer.fillColor = fillColor.cgColor
            primaryLayer.strokeColor = accentColor.cgColor
            primaryLayer.lineWidth = 4

            secondaryLayer.path = UIBezierPath(
                roundedRect: frame.insetBy(dx: -7, dy: -7),
                cornerRadius: min(20, frame.height / 3 + 4)
            ).cgPath
            secondaryLayer.strokeColor =
                accentColor.withAlphaComponent(0.7).cgColor
            secondaryLayer.lineWidth = 2
        } else if let start = interaction.start {
            let center = point(for: start)
            primaryLayer.path = UIBezierPath(
                ovalIn: CGRect(
                    x: center.x - 28,
                    y: center.y - 28,
                    width: 56,
                    height: 56
                )
            ).cgPath
            primaryLayer.fillColor = fillColor.cgColor
            primaryLayer.strokeColor = accentColor.cgColor
            primaryLayer.lineWidth = 4
        }

        guard animated else { return }
        addDoublePulse(to: primaryLayer)
        addDoublePulse(to: secondaryLayer)
    }

    private func addOpacityPulse(
        to layer: CALayer,
        duration: TimeInterval
    ) {
        let pulse = CAKeyframeAnimation(keyPath: "opacity")
        pulse.values = [1, 0.25, 1, 0.45, 1]
        pulse.keyTimes = [0, 0.2, 0.45, 0.7, 1]
        pulse.duration = duration
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(pulse, forKey: "pulse")
    }

    private func addDoublePulse(to layer: CALayer) {
        let pulse = CAKeyframeAnimation(keyPath: "opacity")
        pulse.values = [1, 0.18, 1, 0.18, 1]
        pulse.keyTimes = [0, 0.2, 0.4, 0.65, 1]
        pulse.duration = 0.44
        pulse.timingFunction = CAMediaTimingFunction(name: .linear)
        layer.add(pulse, forKey: "doublePulse")
    }

    private func center(for interaction: HUDInteraction) -> CGPoint? {
        if let rect = interaction.rect {
            let frame = frame(for: rect)
            return CGPoint(x: frame.midX, y: frame.midY)
        }
        return interaction.start.map(point(for:))
    }

    private func frame(for rect: HUDNormalizedRect) -> CGRect {
        CGRect(
            x: bounds.minX + bounds.width * CGFloat(rect.x),
            y: bounds.minY + bounds.height * CGFloat(rect.y),
            width: bounds.width * CGFloat(rect.width),
            height: bounds.height * CGFloat(rect.height)
        )
    }

    private func point(for point: HUDNormalizedPoint) -> CGPoint {
        CGPoint(
            x: bounds.minX + bounds.width * CGFloat(point.x),
            y: bounds.minY + bounds.height * CGFloat(point.y)
        )
    }
}
