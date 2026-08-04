import UIKit
import TestStepHUDProtocol

final class TestCaseCardView: UIView {
    private let configuration: TestStepHUD.Configuration
    private let titleLabel = UILabel()
    private let stepsStack = UIStackView()

    init(configuration: TestStepHUD.Configuration) {
        self.configuration = configuration
        super.init(frame: .zero)

        isHidden = true
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = configuration.cardColor
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.22
        layer.shadowRadius = 18
        layer.shadowOffset = CGSize(width: 0, height: 8)

        titleLabel.numberOfLines = 0
        titleLabel.textColor = .white
        titleLabel.textAlignment = .natural
        titleLabel.font = UIFontMetrics(forTextStyle: .title2).scaledFont(
            for: .systemFont(
                ofSize: min(configuration.fontSize + 6, 42),
                weight: .bold
            ),
            maximumPointSize: 42
        )
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.isAccessibilityElement = false

        stepsStack.axis = .vertical
        stepsStack.alignment = .fill
        stepsStack.spacing = 10
        stepsStack.isAccessibilityElement = false

        let contentStack = UIStackView(arrangedSubviews: [
            titleLabel,
            stepsStack
        ])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 18
        contentStack.isAccessibilityElement = false
        addSubview(contentStack)

        NSLayoutConstraint.activate([
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
                constant: 20
            ),
            contentStack.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -20
            )
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(with testCase: HUDTestCase) {
        reset()
        titleLabel.text = testCase.title

        for step in testCase.steps {
            let bulletLabel = UILabel()
            bulletLabel.text = "•"
            bulletLabel.textColor = configuration.highlightStrokeColor
            bulletLabel.font = .systemFont(
                ofSize: configuration.fontSize,
                weight: .bold
            )
            bulletLabel.setContentHuggingPriority(
                .required,
                for: .horizontal
            )
            bulletLabel.isAccessibilityElement = false

            let stepLabel = UILabel()
            stepLabel.numberOfLines = 0
            stepLabel.text = step
            stepLabel.textColor = .white
            stepLabel.font = UIFontMetrics(forTextStyle: .body).scaledFont(
                for: .systemFont(
                    ofSize: configuration.fontSize,
                    weight: .regular
                ),
                maximumPointSize: 42
            )
            stepLabel.adjustsFontForContentSizeCategory = true
            stepLabel.isAccessibilityElement = false

            let row = UIStackView(arrangedSubviews: [
                bulletLabel,
                stepLabel
            ])
            row.axis = .horizontal
            row.alignment = .firstBaseline
            row.spacing = 10
            row.isAccessibilityElement = false
            stepsStack.addArrangedSubview(row)
        }
    }

    func reset() {
        titleLabel.text = nil
        for row in stepsStack.arrangedSubviews {
            stepsStack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
    }
}
