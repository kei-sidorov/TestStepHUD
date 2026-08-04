import UIKit
import TestStepHUDProtocol

final class FailureCardView: UIView {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let locationLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        isHidden = true
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = UIColor(
            red: 0.70,
            green: 0.08,
            blue: 0.10,
            alpha: 0.97
        )
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.28
        layer.shadowRadius = 20
        layer.shadowOffset = CGSize(width: 0, height: 10)

        iconView.image = UIImage(
            systemName: "xmark.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(
                pointSize: 48,
                weight: .bold
            )
        )
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconView.isAccessibilityElement = false
        iconView.setContentHuggingPriority(.required, for: .vertical)

        titleLabel.numberOfLines = 0
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.font = UIFontMetrics(forTextStyle: .title2).scaledFont(
            for: .systemFont(ofSize: 23, weight: .bold),
            maximumPointSize: 42
        )
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.isAccessibilityElement = false

        messageLabel.numberOfLines = 8
        messageLabel.textColor = .white
        messageLabel.textAlignment = .natural
        messageLabel.lineBreakMode = .byTruncatingTail
        messageLabel.font = UIFontMetrics(forTextStyle: .body).scaledFont(
            for: .systemFont(ofSize: 17, weight: .semibold),
            maximumPointSize: 34
        )
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.isAccessibilityElement = false

        locationLabel.numberOfLines = 1
        locationLabel.textColor = UIColor.white.withAlphaComponent(0.82)
        locationLabel.textAlignment = .center
        locationLabel.lineBreakMode = .byTruncatingMiddle
        locationLabel.font = .monospacedSystemFont(
            ofSize: 13,
            weight: .medium
        )
        locationLabel.isAccessibilityElement = false

        let contentStack = UIStackView(arrangedSubviews: [
            iconView,
            titleLabel,
            messageLabel,
            locationLabel
        ])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 14
        contentStack.setCustomSpacing(10, after: titleLabel)
        contentStack.isAccessibilityElement = false
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            iconView.heightAnchor.constraint(equalToConstant: 52),
            contentStack.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: 22
            ),
            contentStack.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -22
            ),
            contentStack.topAnchor.constraint(
                equalTo: topAnchor,
                constant: 22
            ),
            contentStack.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -22
            )
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(with failure: HUDTestFailure) {
        titleLabel.text = failure.title
        messageLabel.text = failure.message
        locationLabel.text = failure.location
        locationLabel.isHidden = failure.location == nil
    }

    func reset() {
        titleLabel.text = nil
        messageLabel.text = nil
        locationLabel.text = nil
        locationLabel.isHidden = true
    }

    func presentAnimated() {
        layer.removeAllAnimations()
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.94, y: 0.94)

        UIView.animate(
            withDuration: 0.28,
            delay: 0,
            usingSpringWithDamping: 0.82,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            self.alpha = 1
            self.transform = .identity
        }
    }
}
