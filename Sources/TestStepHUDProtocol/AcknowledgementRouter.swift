import Foundation

public final class PendingHUDAcknowledgement: @unchecked Sendable {
    private let semaphore = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var result: Result<HUDAcknowledgement, Error>?

    fileprivate init() {}

    fileprivate func finish(_ result: Result<HUDAcknowledgement, Error>) {
        lock.lock()
        guard self.result == nil else {
            lock.unlock()
            return
        }
        self.result = result
        lock.unlock()
        semaphore.signal()
    }

    public func wait(
        id: UUID,
        timeout: TimeInterval
    ) throws -> HUDAcknowledgement {
        guard semaphore.wait(timeout: .now() + timeout) == .success else {
            throw TestStepHUDProtocolError.timeout(id)
        }

        lock.lock()
        let result = self.result
        lock.unlock()

        guard let result else {
            throw TestStepHUDProtocolError.cancelled
        }

        let acknowledgement = try result.get()
        guard acknowledgement.success else {
            throw TestStepHUDProtocolError.remoteFailure(
                acknowledgement.error ?? "Unknown app-side error."
            )
        }
        return acknowledgement
    }
}

public final class HUDAcknowledgementRouter: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: [UUID: PendingHUDAcknowledgement] = [:]

    public init() {}

    public func register(id: UUID) throws -> PendingHUDAcknowledgement {
        lock.lock()
        defer { lock.unlock() }

        guard pending[id] == nil else {
            throw TestStepHUDProtocolError.duplicateCommand(id)
        }

        let waiter = PendingHUDAcknowledgement()
        pending[id] = waiter
        return waiter
    }

    @discardableResult
    public func resolve(_ acknowledgement: HUDAcknowledgement) -> Bool {
        lock.lock()
        let waiter = pending.removeValue(forKey: acknowledgement.id)
        lock.unlock()

        waiter?.finish(.success(acknowledgement))
        return waiter != nil
    }

    public func fail(id: UUID, error: Error) {
        lock.lock()
        let waiter = pending.removeValue(forKey: id)
        lock.unlock()
        waiter?.finish(.failure(error))
    }

    public func cancelAll() {
        lock.lock()
        let waiters = Array(pending.values)
        pending.removeAll()
        lock.unlock()

        waiters.forEach {
            $0.finish(.failure(TestStepHUDProtocolError.cancelled))
        }
    }
}
