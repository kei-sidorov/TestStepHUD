import UIKit

final class ViewController: UIViewController {
    private let card = UIView()
    private let statusLabel = UILabel()
    private let continueButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        buildInterface()
    }

    private func buildInterface() {
        view.backgroundColor = UIColor(
            red: 0.96,
            green: 0.97,
            blue: 0.99,
            alpha: 1
        )

        let eyebrow = makeLabel(
            text: "TESTSTEPHUD DEMO",
            font: .systemFont(ofSize: 13, weight: .bold),
            color: UIColor(red: 0.31, green: 0.36, blue: 0.48, alpha: 1)
        )
        eyebrow.accessibilityIdentifier = "demoEyebrow"

        let title = makeLabel(
            text: "A checkout flow you can read.",
            font: .systemFont(ofSize: 34, weight: .bold),
            color: UIColor(red: 0.08, green: 0.11, blue: 0.18, alpha: 1)
        )
        title.numberOfLines = 0
        title.accessibilityIdentifier = "demoTitle"

        let subtitle = makeLabel(
            text: "The UI test explains what it is finding, tapping, and verifying.",
            font: .systemFont(ofSize: 18, weight: .regular),
            color: UIColor(red: 0.34, green: 0.38, blue: 0.47, alpha: 1)
        )
        subtitle.numberOfLines = 0

        let noteField = UITextField()
        noteField.translatesAutoresizingMaskIntoConstraints = false
        noteField.borderStyle = .roundedRect
        noteField.placeholder = "Type a note"
        noteField.font = .systemFont(ofSize: 16)
        noteField.returnKeyType = .done
        noteField.accessibilityIdentifier = "noteField"
        noteField.addTarget(
            self,
            action: #selector(didSubmitNote),
            for: .editingDidEndOnExit
        )

        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .white
        card.layer.cornerRadius = 24
        card.layer.cornerCurve = .continuous
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.08
        card.layer.shadowRadius = 24
        card.layer.shadowOffset = CGSize(width: 0, height: 10)

        let itemLabel = makeLabel(
            text: "Design systems field guide",
            font: .systemFont(ofSize: 18, weight: .semibold),
            color: UIColor(red: 0.08, green: 0.11, blue: 0.18, alpha: 1)
        )
        itemLabel.accessibilityIdentifier = "itemLabel"
        let priceLabel = makeLabel(
            text: "$24",
            font: .monospacedDigitSystemFont(ofSize: 24, weight: .bold),
            color: UIColor(red: 0.14, green: 0.32, blue: 0.72, alpha: 1)
        )
        priceLabel.textAlignment = .right
        priceLabel.accessibilityIdentifier = "priceLabel"

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Ready to continue"
        statusLabel.font = .systemFont(ofSize: 16, weight: .medium)
        statusLabel.textColor = UIColor(
            red: 0.34,
            green: 0.38,
            blue: 0.47,
            alpha: 1
        )
        statusLabel.accessibilityIdentifier = "checkoutStatus"

        var buttonConfiguration = UIButton.Configuration.filled()
        buttonConfiguration.title = "Continue"
        buttonConfiguration.baseBackgroundColor = UIColor(
            red: 0.14,
            green: 0.32,
            blue: 0.72,
            alpha: 1
        )
        buttonConfiguration.baseForegroundColor = .white
        buttonConfiguration.cornerStyle = .large
        buttonConfiguration.contentInsets = NSDirectionalEdgeInsets(
            top: 15,
            leading: 24,
            bottom: 15,
            trailing: 24
        )
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        continueButton.configuration = buttonConfiguration
        continueButton.accessibilityIdentifier = "continueButton"
        continueButton.addTarget(
            self,
            action: #selector(didTapContinue),
            for: .touchUpInside
        )

        let headingStack = UIStackView(arrangedSubviews: [
            eyebrow,
            title,
            subtitle,
            noteField
        ])
        headingStack.translatesAutoresizingMaskIntoConstraints = false
        headingStack.axis = .vertical
        headingStack.spacing = 12

        [itemLabel, priceLabel, statusLabel, continueButton].forEach {
            card.addSubview($0)
        }
        view.addSubview(headingStack)
        view.addSubview(card)

        NSLayoutConstraint.activate([
            headingStack.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: 24
            ),
            headingStack.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -24
            ),
            headingStack.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 92
            ),

            card.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: 24
            ),
            card.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -24
            ),
            card.topAnchor.constraint(
                greaterThanOrEqualTo: headingStack.bottomAnchor,
                constant: 32
            ),
            card.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -24
            ),

            itemLabel.leadingAnchor.constraint(
                equalTo: card.leadingAnchor,
                constant: 22
            ),
            itemLabel.topAnchor.constraint(
                equalTo: card.topAnchor,
                constant: 24
            ),
            priceLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: itemLabel.trailingAnchor,
                constant: 12
            ),
            priceLabel.trailingAnchor.constraint(
                equalTo: card.trailingAnchor,
                constant: -22
            ),
            priceLabel.firstBaselineAnchor.constraint(
                equalTo: itemLabel.firstBaselineAnchor
            ),
            statusLabel.leadingAnchor.constraint(
                equalTo: card.leadingAnchor,
                constant: 22
            ),
            statusLabel.trailingAnchor.constraint(
                equalTo: card.trailingAnchor,
                constant: -22
            ),
            statusLabel.topAnchor.constraint(
                equalTo: itemLabel.bottomAnchor,
                constant: 30
            ),
            continueButton.leadingAnchor.constraint(
                equalTo: card.leadingAnchor,
                constant: 22
            ),
            continueButton.trailingAnchor.constraint(
                equalTo: card.trailingAnchor,
                constant: -22
            ),
            continueButton.topAnchor.constraint(
                equalTo: statusLabel.bottomAnchor,
                constant: 20
            ),
            continueButton.bottomAnchor.constraint(
                equalTo: card.bottomAnchor,
                constant: -22
            )
        ])
    }

    private func makeLabel(
        text: String,
        font: UIFont,
        color: UIColor
    ) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = font
        label.textColor = color
        return label
    }

    @objc
    private func didTapContinue() {
        statusLabel.text = "Order confirmed"
        statusLabel.textColor = UIColor(
            red: 0.08,
            green: 0.54,
            blue: 0.30,
            alpha: 1
        )
        continueButton.configuration?.title = "Done"
        continueButton.isEnabled = false
    }

    @objc
    private func didSubmitNote(_ textField: UITextField) {
        textField.resignFirstResponder()
    }
}
