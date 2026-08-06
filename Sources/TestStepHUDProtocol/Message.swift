import Foundation

public enum HUDMessageKind: String, Codable, Sendable {
    case hello
    case show
    case showTestCase
    case showFailure
    case hide
    case ping
    case highlight
    case clearHighlight
    case interaction
    case clearInteraction
    case acknowledgement
}

public struct HUDNormalizedRect: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var isValid: Bool {
        let values = [x, y, width, height]
        guard values.allSatisfy(\.isFinite) else { return false }
        guard x >= 0, y >= 0, width > 0, height > 0 else { return false }

        let tolerance = 0.000_001
        return x + width <= 1 + tolerance &&
            y + height <= 1 + tolerance
    }
}

public struct HUDNormalizedPoint: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public var isValid: Bool {
        x.isFinite && y.isFinite &&
            x >= 0 && x <= 1 &&
            y >= 0 && y <= 1
    }
}

public enum HUDHighlightStyle: String, Codable, Sendable {
    case interaction
    case existence
}

public enum HUDSwipeDirection: String, Codable, Sendable {
    case up
    case down
    case left
    case right
}

public enum HUDInteractionKind: String, Codable, Sendable {
    case swipe
    case typing
    case longPress
    case drag
    case coordinateTap
    case doubleTap
}

public struct HUDInteraction: Codable, Equatable, Sendable {
    public let kind: HUDInteractionKind
    public let rect: HUDNormalizedRect?
    public let start: HUDNormalizedPoint?
    public let end: HUDNormalizedPoint?
    public let direction: HUDSwipeDirection?
    public let duration: Double?

    public init(
        kind: HUDInteractionKind,
        rect: HUDNormalizedRect? = nil,
        start: HUDNormalizedPoint? = nil,
        end: HUDNormalizedPoint? = nil,
        direction: HUDSwipeDirection? = nil,
        duration: Double? = nil
    ) {
        self.kind = kind
        self.rect = rect
        self.start = start
        self.end = end
        self.direction = direction
        self.duration = duration
    }

    public var isValid: Bool {
        let validRect = rect?.isValid == true
        let validStart = start?.isValid == true
        let validEnd = end?.isValid == true
        let validDuration = duration.map {
            $0.isFinite && $0 >= 0
        } ?? false

        switch kind {
        case .swipe:
            return validRect && direction != nil
        case .typing:
            return validRect
        case .longPress:
            return (validRect || validStart) && validDuration
        case .drag:
            return validStart && validEnd && validDuration
        case .coordinateTap:
            return validStart
        case .doubleTap:
            return validRect || validStart
        }
    }
}

public struct HUDTestCase: Codable, Equatable, Sendable {
    public let title: String
    public let steps: [String]

    public init(title: String, steps: [String]) {
        self.title = title
        self.steps = steps
    }
}

public struct HUDTestFailure: Codable, Equatable, Sendable {
    public let title: String
    public let message: String
    public let location: String?

    public init(
        title: String,
        message: String,
        location: String? = nil
    ) {
        self.title = title
        self.message = message
        self.location = location
    }
}

public struct HUDWireMessage: Codable, Equatable, Sendable {
    public let kind: HUDMessageKind
    public let id: UUID?
    public let token: String?
    public let protocolVersion: Int?
    public let text: String?
    public let testCase: HUDTestCase?
    public let failure: HUDTestFailure?
    public let rect: HUDNormalizedRect?
    public let highlightStyle: HUDHighlightStyle?
    public let interaction: HUDInteraction?
    public let success: Bool?
    public let error: String?

    public init(
        kind: HUDMessageKind,
        id: UUID? = nil,
        token: String? = nil,
        protocolVersion: Int? = nil,
        text: String? = nil,
        testCase: HUDTestCase? = nil,
        failure: HUDTestFailure? = nil,
        rect: HUDNormalizedRect? = nil,
        highlightStyle: HUDHighlightStyle? = nil,
        interaction: HUDInteraction? = nil,
        success: Bool? = nil,
        error: String? = nil
    ) {
        self.kind = kind
        self.id = id
        self.token = token
        self.protocolVersion = protocolVersion
        self.text = text
        self.testCase = testCase
        self.failure = failure
        self.rect = rect
        self.highlightStyle = highlightStyle
        self.interaction = interaction
        self.success = success
        self.error = error
    }

    public static func hello(token: String, protocolVersion: Int) -> Self {
        Self(kind: .hello, token: token, protocolVersion: protocolVersion)
    }

    public static func show(id: UUID, text: String) -> Self {
        Self(kind: .show, id: id, text: text)
    }

    public static func showTestCase(
        id: UUID,
        title: String,
        steps: [String]
    ) -> Self {
        Self(
            kind: .showTestCase,
            id: id,
            testCase: HUDTestCase(title: title, steps: steps)
        )
    }

    public static func showFailure(
        id: UUID,
        failure: HUDTestFailure
    ) -> Self {
        Self(kind: .showFailure, id: id, failure: failure)
    }

    public static func hide(id: UUID) -> Self {
        Self(kind: .hide, id: id)
    }

    public static func ping(id: UUID) -> Self {
        Self(kind: .ping, id: id)
    }

    public static func highlight(
        id: UUID,
        rect: HUDNormalizedRect,
        style: HUDHighlightStyle = .interaction
    ) -> Self {
        Self(
            kind: .highlight,
            id: id,
            rect: rect,
            highlightStyle: style
        )
    }

    public static func clearHighlight(id: UUID) -> Self {
        Self(kind: .clearHighlight, id: id)
    }

    public static func interaction(
        id: UUID,
        visual: HUDInteraction
    ) -> Self {
        Self(kind: .interaction, id: id, interaction: visual)
    }

    public static func clearInteraction(id: UUID) -> Self {
        Self(kind: .clearInteraction, id: id)
    }

    public static func acknowledgement(
        id: UUID,
        success: Bool,
        error: String? = nil
    ) -> Self {
        Self(kind: .acknowledgement, id: id, success: success, error: error)
    }

    public func commandID() throws -> UUID {
        guard let id else {
            throw TestStepHUDProtocolError.missingField("id")
        }
        return id
    }

    public func showText() throws -> String {
        guard kind == .show else {
            throw TestStepHUDProtocolError.unexpectedMessage(kind.rawValue)
        }
        guard let text else {
            throw TestStepHUDProtocolError.missingField("text")
        }
        return text
    }

    public func testCaseValue() throws -> HUDTestCase {
        guard kind == .showTestCase else {
            throw TestStepHUDProtocolError.unexpectedMessage(kind.rawValue)
        }
        guard let testCase else {
            throw TestStepHUDProtocolError.missingField("testCase")
        }
        return testCase
    }

    public func failureValue() throws -> HUDTestFailure {
        guard kind == .showFailure else {
            throw TestStepHUDProtocolError.unexpectedMessage(kind.rawValue)
        }
        guard let failure else {
            throw TestStepHUDProtocolError.missingField("failure")
        }
        return failure
    }

    public func highlightRect() throws -> HUDNormalizedRect {
        guard kind == .highlight else {
            throw TestStepHUDProtocolError.unexpectedMessage(kind.rawValue)
        }
        guard let rect else {
            throw TestStepHUDProtocolError.missingField("rect")
        }
        guard rect.isValid else {
            throw TestStepHUDProtocolError.invalidNormalizedRect
        }
        return rect
    }

    public func interactionVisual() throws -> HUDInteraction {
        guard kind == .interaction else {
            throw TestStepHUDProtocolError.unexpectedMessage(kind.rawValue)
        }
        guard let interaction else {
            throw TestStepHUDProtocolError.missingField("interaction")
        }
        guard interaction.isValid else {
            throw TestStepHUDProtocolError.invalidInteraction
        }
        return interaction
    }

    public func acknowledgementValue() throws -> HUDAcknowledgement {
        guard kind == .acknowledgement else {
            throw TestStepHUDProtocolError.unexpectedMessage(kind.rawValue)
        }
        guard let id else {
            throw TestStepHUDProtocolError.missingField("id")
        }
        guard let success else {
            throw TestStepHUDProtocolError.missingField("success")
        }
        return HUDAcknowledgement(id: id, success: success, error: error)
    }
}

public struct HUDAcknowledgement: Codable, Equatable, Sendable {
    public let id: UUID
    public let success: Bool
    public let error: String?

    public init(id: UUID, success: Bool, error: String? = nil) {
        self.id = id
        self.success = success
        self.error = error
    }
}

public enum HUDMessageCoding {
    public static func encode(_ message: HUDWireMessage) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(message)
    }

    public static func decode(_ payload: Data) throws -> HUDWireMessage {
        do {
            return try JSONDecoder().decode(HUDWireMessage.self, from: payload)
        } catch {
            throw TestStepHUDProtocolError.malformedPayload
        }
    }
}
