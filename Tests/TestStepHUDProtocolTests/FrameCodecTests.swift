import XCTest
@testable import TestStepHUDProtocol

final class FrameCodecTests: XCTestCase {
    func testRoundTripMessage() throws {
        let id = UUID()
        let message = HUDWireMessage.show(
            id: id,
            text: "Tap “Continue” →"
        )

        let frame = try HUDFrameEncoder.encode(message)
        var decoder = HUDFrameDecoder()
        let payloads = try decoder.append(frame)

        XCTAssertEqual(payloads.count, 1)
        XCTAssertEqual(
            try HUDMessageCoding.decode(try XCTUnwrap(payloads.first)),
            message
        )
    }

    func testRoundTripHighlightMessage() throws {
        let id = UUID()
        let message = HUDWireMessage.highlight(
            id: id,
            rect: HUDNormalizedRect(
                x: 0.1,
                y: 0.25,
                width: 0.8,
                height: 0.1
            )
        )

        let frame = try HUDFrameEncoder.encode(message)
        var decoder = HUDFrameDecoder()
        let payload = try XCTUnwrap(decoder.append(frame).first)
        let decoded = try HUDMessageCoding.decode(payload)

        XCTAssertEqual(decoded, message)
        XCTAssertEqual(try decoded.highlightRect(), message.rect)
    }

    func testRoundTripExistenceHighlightMessage() throws {
        let message = HUDWireMessage.highlight(
            id: UUID(),
            rect: HUDNormalizedRect(
                x: 0.1,
                y: 0.2,
                width: 0.3,
                height: 0.4
            ),
            style: .existence
        )

        let decoded = try HUDMessageCoding.decode(
            HUDMessageCoding.encode(message)
        )

        XCTAssertEqual(decoded, message)
        XCTAssertEqual(decoded.highlightStyle, .existence)
    }

    func testRoundTripTestCaseMessage() throws {
        let message = HUDWireMessage.showTestCase(
            id: UUID(),
            title: "Active purchase does not show the paywall",
            steps: [
                "Configure the application",
                "Activate the subscription",
                "Verify that the paywall is not shown"
            ]
        )

        let frame = try HUDFrameEncoder.encode(message)
        var decoder = HUDFrameDecoder()
        let payload = try XCTUnwrap(decoder.append(frame).first)
        let decoded = try HUDMessageCoding.decode(payload)

        XCTAssertEqual(decoded, message)
        XCTAssertEqual(try decoded.testCaseValue(), message.testCase)
    }

    func testRejectsTestCaseMessageWithoutPayload() {
        let message = HUDWireMessage(
            kind: .showTestCase,
            id: UUID()
        )

        XCTAssertThrowsError(try message.testCaseValue()) { error in
            XCTAssertEqual(
                error as? TestStepHUDProtocolError,
                .missingField("testCase")
            )
        }
    }

    func testRoundTripFailureMessage() throws {
        let message = HUDWireMessage.showFailure(
            id: UUID(),
            failure: HUDTestFailure(
                title: "Assertion failed",
                message: "XCTAssertTrue failed - Continue button is missing",
                location: "CheckoutUITests.swift:42"
            )
        )

        let frame = try HUDFrameEncoder.encode(message)
        var decoder = HUDFrameDecoder()
        let payload = try XCTUnwrap(decoder.append(frame).first)
        let decoded = try HUDMessageCoding.decode(payload)

        XCTAssertEqual(decoded, message)
        XCTAssertEqual(try decoded.failureValue(), message.failure)
    }

    func testRejectsFailureMessageWithoutPayload() {
        let message = HUDWireMessage(
            kind: .showFailure,
            id: UUID()
        )

        XCTAssertThrowsError(try message.failureValue()) { error in
            XCTAssertEqual(
                error as? TestStepHUDProtocolError,
                .missingField("failure")
            )
        }
    }

    func testRejectsInvalidNormalizedHighlightRect() {
        let message = HUDWireMessage.highlight(
            id: UUID(),
            rect: HUDNormalizedRect(
                x: 0.8,
                y: 0.2,
                width: 0.3,
                height: 0.2
            )
        )

        XCTAssertThrowsError(try message.highlightRect()) { error in
            XCTAssertEqual(
                error as? TestStepHUDProtocolError,
                .invalidNormalizedRect
            )
        }
    }

    func testRoundTripSwipeInteraction() throws {
        let message = HUDWireMessage.interaction(
            id: UUID(),
            visual: HUDInteraction(
                kind: .swipe,
                rect: HUDNormalizedRect(
                    x: 0.1,
                    y: 0.2,
                    width: 0.8,
                    height: 0.6
                ),
                direction: .up
            )
        )

        let frame = try HUDFrameEncoder.encode(message)
        var decoder = HUDFrameDecoder()
        let payload = try XCTUnwrap(decoder.append(frame).first)
        let decoded = try HUDMessageCoding.decode(payload)

        XCTAssertEqual(decoded, message)
        XCTAssertEqual(try decoded.interactionVisual(), message.interaction)
    }

    func testRejectsIncompleteDragInteraction() {
        let message = HUDWireMessage.interaction(
            id: UUID(),
            visual: HUDInteraction(
                kind: .drag,
                start: HUDNormalizedPoint(x: 0.2, y: 0.3),
                duration: 0.5
            )
        )

        XCTAssertThrowsError(try message.interactionVisual()) { error in
            XCTAssertEqual(
                error as? TestStepHUDProtocolError,
                .invalidInteraction
            )
        }
    }

    func testFragmentedInputProducesFrameOnlyWhenComplete() throws {
        let payload = Data("fragmented".utf8)
        let frame = try HUDFrameEncoder.encode(payload)
        var decoder = HUDFrameDecoder()
        var output: [Data] = []

        for byte in frame {
            output.append(contentsOf: try decoder.append(Data([byte])))
        }

        XCTAssertEqual(output, [payload])
    }

    func testMultipleFramesInSingleRead() throws {
        let first = Data("first".utf8)
        let second = Data("second".utf8)
        var read = try HUDFrameEncoder.encode(first)
        read.append(try HUDFrameEncoder.encode(second))

        var decoder = HUDFrameDecoder()

        XCTAssertEqual(try decoder.append(read), [first, second])
    }

    func testRejectsZeroLengthFrame() {
        var decoder = HUDFrameDecoder()

        XCTAssertThrowsError(
            try decoder.append(Data([0, 0, 0, 0]))
        ) { error in
            XCTAssertEqual(
                error as? TestStepHUDProtocolError,
                .emptyFrame
            )
        }
    }

    func testRejectsFrameLargerThanLimitBeforePayloadArrives() {
        var decoder = HUDFrameDecoder(maximumFrameSize: 8)
        let declaredLength: [UInt8] = [0, 0, 0, 9]

        XCTAssertThrowsError(try decoder.append(Data(declaredLength))) { error in
            XCTAssertEqual(
                error as? TestStepHUDProtocolError,
                .frameTooLarge(actual: 9, maximum: 8)
            )
        }
    }

    func testEncoderRejectsOversizedPayload() {
        XCTAssertThrowsError(
            try HUDFrameEncoder.encode(
                Data(repeating: 0, count: 5),
                maximumFrameSize: 4
            )
        ) { error in
            XCTAssertEqual(
                error as? TestStepHUDProtocolError,
                .frameTooLarge(actual: 5, maximum: 4)
            )
        }
    }

    func testRejectsMalformedJSON() {
        XCTAssertThrowsError(
            try HUDMessageCoding.decode(Data("{not-json}".utf8))
        ) { error in
            XCTAssertEqual(
                error as? TestStepHUDProtocolError,
                .malformedPayload
            )
        }
    }
}
