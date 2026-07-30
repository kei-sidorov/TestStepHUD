import XCTest
@testable import TestStepHUDProtocol

final class AcknowledgementRouterTests: XCTestCase {
    func testRoutesAcknowledgementsByUUID() throws {
        let router = HUDAcknowledgementRouter()
        let firstID = UUID()
        let secondID = UUID()
        let first = try router.register(id: firstID)
        let second = try router.register(id: secondID)

        XCTAssertTrue(
            router.resolve(
                HUDAcknowledgement(id: secondID, success: true)
            )
        )
        XCTAssertEqual(
            try second.wait(id: secondID, timeout: 0.1).id,
            secondID
        )

        XCTAssertTrue(
            router.resolve(
                HUDAcknowledgement(id: firstID, success: true)
            )
        )
        XCTAssertEqual(
            try first.wait(id: firstID, timeout: 0.1).id,
            firstID
        )
    }

    func testIgnoresUnknownAcknowledgement() {
        let router = HUDAcknowledgementRouter()

        XCTAssertFalse(
            router.resolve(
                HUDAcknowledgement(id: UUID(), success: true)
            )
        )
    }

    func testPropagatesRemoteFailure() throws {
        let router = HUDAcknowledgementRouter()
        let id = UUID()
        let waiter = try router.register(id: id)
        router.resolve(
            HUDAcknowledgement(
                id: id,
                success: false,
                error: "Scene unavailable"
            )
        )

        XCTAssertThrowsError(
            try waiter.wait(id: id, timeout: 0.1)
        ) { error in
            XCTAssertEqual(
                error as? TestStepHUDProtocolError,
                .remoteFailure("Scene unavailable")
            )
        }
    }

    func testTimesOutWhenNoAcknowledgementArrives() throws {
        let router = HUDAcknowledgementRouter()
        let id = UUID()
        let waiter = try router.register(id: id)

        XCTAssertThrowsError(
            try waiter.wait(id: id, timeout: 0.01)
        ) { error in
            XCTAssertEqual(
                error as? TestStepHUDProtocolError,
                .timeout(id)
            )
        }
    }

    func testCancellationReleasesAllWaiters() throws {
        let router = HUDAcknowledgementRouter()
        let id = UUID()
        let waiter = try router.register(id: id)

        router.cancelAll()

        XCTAssertThrowsError(
            try waiter.wait(id: id, timeout: 0.1)
        ) { error in
            XCTAssertEqual(
                error as? TestStepHUDProtocolError,
                .cancelled
            )
        }
    }

    func testRejectsDuplicateCommandID() throws {
        let router = HUDAcknowledgementRouter()
        let id = UUID()
        _ = try router.register(id: id)

        XCTAssertThrowsError(try router.register(id: id)) { error in
            XCTAssertEqual(
                error as? TestStepHUDProtocolError,
                .duplicateCommand(id)
            )
        }
    }
}
