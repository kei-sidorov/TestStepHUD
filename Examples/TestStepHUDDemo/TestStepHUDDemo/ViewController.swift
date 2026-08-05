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
            red: 0.95,
            green: 0.96,
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
            text: "Checkout, explained.",
            font: .systemFont(ofSize: 34, weight: .bold),
            color: UIColor(red: 0.07, green: 0.09, blue: 0.16, alpha: 1)
        )
        title.numberOfLines = 0
        title.accessibilityIdentifier = "demoTitle"

        let subtitle = makeLabel(
            text: "Watch the test describe the scenario, follow each action, and explain a failure.",
            font: .systemFont(ofSize: 18, weight: .regular),
            color: UIColor(red: 0.34, green: 0.38, blue: 0.47, alpha: 1)
        )
        subtitle.numberOfLines = 0

        let orderEyebrow = makeLabel(
            text: "ORDER #2408",
            font: .systemFont(ofSize: 12, weight: .bold),
            color: UIColor(red: 0.39, green: 0.42, blue: 0.52, alpha: 1)
        )

        let iconBackground = UIView()
        iconBackground.translatesAutoresizingMaskIntoConstraints = false
        iconBackground.backgroundColor = UIColor(
            red: 1,
            green: 0.94,
            blue: 0.76,
            alpha: 1
        )
        iconBackground.layer.cornerRadius = 15
        iconBackground.layer.cornerCurve = .continuous

        let itemIcon = UIImageView(
            image: UIImage(systemName: "shippingbox.fill")
        )
        itemIcon.translatesAutoresizingMaskIntoConstraints = false
        itemIcon.tintColor = UIColor(
            red: 0.78,
            green: 0.45,
            blue: 0.05,
            alpha: 1
        )
        itemIcon.contentMode = .scaleAspectFit
        iconBackground.addSubview(itemIcon)

        let itemLabel = makeLabel(
            text: "Developer launch kit",
            font: .systemFont(ofSize: 18, weight: .semibold),
            color: UIColor(red: 0.07, green: 0.09, blue: 0.16, alpha: 1)
        )
        itemLabel.accessibilityIdentifier = "itemLabel"
        let itemDetail = makeLabel(
            text: "Priority delivery · Today",
            font: .systemFont(ofSize: 14, weight: .regular),
            color: UIColor(red: 0.39, green: 0.42, blue: 0.52, alpha: 1)
        )
        let itemTextStack = UIStackView(arrangedSubviews: [
            itemLabel,
            itemDetail
        ])
        itemTextStack.axis = .vertical
        itemTextStack.spacing = 4

        let priceLabel = makeLabel(
            text: "$48",
            font: .monospacedDigitSystemFont(ofSize: 22, weight: .bold),
            color: UIColor(red: 0.22, green: 0.27, blue: 0.72, alpha: 1)
        )
        priceLabel.textAlignment = .right
        priceLabel.accessibilityIdentifier = "priceLabel"
        priceLabel.setContentHuggingPriority(.required, for: .horizontal)

        let itemStack = UIStackView(arrangedSubviews: [
            iconBackground,
            itemTextStack,
            priceLabel
        ])
        itemStack.axis = .horizontal
        itemStack.alignment = .center
        itemStack.spacing = 12

        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = UIColor(
            red: 0.90,
            green: 0.91,
            blue: 0.94,
            alpha: 1
        )

        let noteCaption = makeLabel(
            text: "DELIVERY NOTE",
            font: .systemFont(ofSize: 12, weight: .bold),
            color: UIColor(red: 0.39, green: 0.42, blue: 0.52, alpha: 1)
        )

        let noteField = UITextField()
        noteField.translatesAutoresizingMaskIntoConstraints = false
        noteField.borderStyle = .none
        noteField.backgroundColor = UIColor(
            red: 0.95,
            green: 0.96,
            blue: 0.98,
            alpha: 1
        )
        noteField.textColor = UIColor(
            red: 0.07,
            green: 0.09,
            blue: 0.16,
            alpha: 1
        )
        noteField.attributedPlaceholder = NSAttributedString(
            string: "Add delivery instructions",
            attributes: [
                .foregroundColor: UIColor(
                    red: 0.47,
                    green: 0.50,
                    blue: 0.59,
                    alpha: 1
                )
            ]
        )
        noteField.font = .systemFont(ofSize: 16)
        noteField.layer.cornerRadius = 14
        noteField.layer.cornerCurve = .continuous
        noteField.leftView = UIView(
            frame: CGRect(x: 0, y: 0, width: 16, height: 1)
        )
        noteField.leftViewMode = .always
        noteField.rightView = UIView(
            frame: CGRect(x: 0, y: 0, width: 16, height: 1)
        )
        noteField.rightViewMode = .always
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

        let statusCaption = makeLabel(
            text: "STATUS",
            font: .systemFont(ofSize: 12, weight: .bold),
            color: UIColor(red: 0.39, green: 0.42, blue: 0.52, alpha: 1)
        )
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Awaiting confirmation"
        statusLabel.font = .systemFont(ofSize: 16, weight: .medium)
        statusLabel.textColor = UIColor(
            red: 0.29,
            green: 0.32,
            blue: 0.41,
            alpha: 1
        )
        statusLabel.accessibilityIdentifier = "checkoutStatus"

        let statusStack = UIStackView(arrangedSubviews: [
            statusCaption,
            statusLabel
        ])
        statusStack.axis = .vertical
        statusStack.spacing = 5

        var buttonConfiguration = UIButton.Configuration.filled()
        buttonConfiguration.title = "Confirm order"
        buttonConfiguration.image = UIImage(systemName: "arrow.right")
        buttonConfiguration.imagePlacement = .trailing
        buttonConfiguration.imagePadding = 8
        buttonConfiguration.baseBackgroundColor = UIColor(
            red: 0.22,
            green: 0.27,
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
            subtitle
        ])
        headingStack.translatesAutoresizingMaskIntoConstraints = false
        headingStack.axis = .vertical
        headingStack.spacing = 12

        let contentStack = UIStackView(arrangedSubviews: [
            orderEyebrow,
            itemStack,
            divider,
            noteCaption,
            noteField,
            statusStack,
            continueButton
        ])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 14
        contentStack.setCustomSpacing(18, after: itemStack)
        contentStack.setCustomSpacing(18, after: divider)
        contentStack.setCustomSpacing(8, after: noteCaption)
        contentStack.setCustomSpacing(20, after: noteField)
        contentStack.setCustomSpacing(18, after: statusStack)

        card.addSubview(contentStack)
        view.addSubview(headingStack)
        view.addSubview(card)

        NSLayoutConstraint.activate([
            iconBackground.widthAnchor.constraint(equalToConstant: 52),
            iconBackground.heightAnchor.constraint(equalToConstant: 52),
            itemIcon.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            itemIcon.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            itemIcon.widthAnchor.constraint(equalToConstant: 27),
            itemIcon.heightAnchor.constraint(equalToConstant: 27),
            divider.heightAnchor.constraint(equalToConstant: 1),
            noteField.heightAnchor.constraint(equalToConstant: 50),
            continueButton.heightAnchor.constraint(equalToConstant: 54),

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
                constant: 42
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
                constant: 28
            ),
            card.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -24
            ),

            contentStack.leadingAnchor.constraint(
                equalTo: card.leadingAnchor,
                constant: 22
            ),
            contentStack.trailingAnchor.constraint(
                equalTo: card.trailingAnchor,
                constant: -22
            ),
            contentStack.topAnchor.constraint(
                equalTo: card.topAnchor,
                constant: 24
            ),
            contentStack.bottomAnchor.constraint(
                equalTo: card.bottomAnchor,
                constant: -24
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
        continueButton.configuration?.title = "Confirmed"
        continueButton.configuration?.image = UIImage(
            systemName: "checkmark"
        )
        continueButton.isEnabled = false
    }

    @objc
    private func didSubmitNote(_ textField: UITextField) {
        textField.resignFirstResponder()
    }
}
