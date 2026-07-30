import Foundation
import UIKit
import TestStepHUDProtocol

/// Installs the app-side receiver that displays XCUITest steps.
///
/// Calling `install()` during a normal app launch is a strict no-op. The
/// receiver starts only when `launchWithTestStepHUD()` has supplied a valid
/// loopback port, session token, and protocol version.
public enum TestStepHUD {
    @MainActor
    public static func install(configuration: Configuration = .default) {
        guard let launchConfiguration = AppLaunchConfiguration(
            environment: ProcessInfo.processInfo.environment
        ) else {
            return
        }

        HUDRuntime.shared.install(
            launchConfiguration: launchConfiguration,
            configuration: configuration
        )
    }
}

extension TestStepHUD {
    public struct Color: Equatable, Sendable {
        public var red: CGFloat
        public var green: CGFloat
        public var blue: CGFloat

        public init(red: CGFloat, green: CGFloat, blue: CGFloat) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        public init(rgb: UInt32) {
            red = CGFloat((rgb >> 16) & 0xff) / 255
            green = CGFloat((rgb >> 8) & 0xff) / 255
            blue = CGFloat(rgb & 0xff) / 255
        }

        fileprivate var uiColor: UIColor {
            UIColor(red: red, green: green, blue: blue, alpha: 1)
        }

        public static let ink = Color(rgb: 0x151B2B)
        public static let white = Color(rgb: 0xFFFFFF)
        public static let highlight = Color(rgb: 0xFFD166)
    }

    public enum Position: String, CaseIterable, Sendable {
        case top
        case center
        case bottom
    }

    public enum TextAlignment: String, CaseIterable, Sendable {
        case leading
        case center
        case trailing

        fileprivate var uiTextAlignment: NSTextAlignment {
            switch self {
            case .leading:
                return .natural
            case .center:
                return .center
            case .trailing:
                return .right
            }
        }
    }

    public struct Configuration: Equatable, Sendable {
        public var backgroundColor: Color
        public var backgroundOpacity: CGFloat
        public var position: Position
        public var fontSize: CGFloat
        public var textAlignment: TextAlignment
        public var highlightColor: Color
        public var highlightOpacity: CGFloat

        /// Moves the step card near each highlighted tap target.
        ///
        /// After five seconds without a new target, the card returns to its
        /// configured `position`.
        public var movesHUDToHighlightedElement: Bool

        /// Pulses the HUD card when a new step is shown.
        public var pulsesHUDOnStepChange: Bool

        public init(
            backgroundColor: Color = .ink,
            backgroundOpacity: CGFloat = 0.9,
            position: Position = .top,
            fontSize: CGFloat = 17,
            textAlignment: TextAlignment = .center,
            highlightColor: Color = .highlight,
            highlightOpacity: CGFloat = 0.3,
            movesHUDToHighlightedElement: Bool = false,
            pulsesHUDOnStepChange: Bool = true
        ) {
            self.backgroundColor = backgroundColor
            self.backgroundOpacity = min(max(backgroundOpacity, 0), 1)
            self.position = position
            self.fontSize = min(max(fontSize, 11), 42)
            self.textAlignment = textAlignment
            self.highlightColor = highlightColor
            self.highlightOpacity = min(max(highlightOpacity, 0), 1)
            self.movesHUDToHighlightedElement = movesHUDToHighlightedElement
            self.pulsesHUDOnStepChange = pulsesHUDOnStepChange
        }

        public static let `default` = Configuration()
    }
}

extension TestStepHUD.Configuration {
    var cardColor: UIColor {
        backgroundColor.uiColor.withAlphaComponent(backgroundOpacity)
    }

    var labelAlignment: NSTextAlignment {
        textAlignment.uiTextAlignment
    }

    var highlightStrokeColor: UIColor {
        highlightColor.uiColor
    }

    var highlightFillColor: UIColor {
        highlightColor.uiColor.withAlphaComponent(highlightOpacity)
    }
}
