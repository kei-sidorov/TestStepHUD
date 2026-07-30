import Foundation

public enum HUDFrameEncoder {
    public static func encode(
        _ payload: Data,
        maximumFrameSize: Int = TestStepHUDProtocolConstants.maximumFrameSize
    ) throws -> Data {
        guard !payload.isEmpty else {
            throw TestStepHUDProtocolError.emptyFrame
        }
        guard payload.count <= maximumFrameSize else {
            throw TestStepHUDProtocolError.frameTooLarge(
                actual: payload.count,
                maximum: maximumFrameSize
            )
        }

        let length = UInt32(payload.count)
        let header: [UInt8] = [
            UInt8((length >> 24) & 0xff),
            UInt8((length >> 16) & 0xff),
            UInt8((length >> 8) & 0xff),
            UInt8(length & 0xff)
        ]

        var frame = Data(header)
        frame.append(payload)
        return frame
    }

    public static func encode(
        _ message: HUDWireMessage,
        maximumFrameSize: Int = TestStepHUDProtocolConstants.maximumFrameSize
    ) throws -> Data {
        try encode(
            HUDMessageCoding.encode(message),
            maximumFrameSize: maximumFrameSize
        )
    }
}
public struct HUDFrameDecoder: Sendable {
    private var buffer = Data()
    private let maximumFrameSize: Int

    public init(
        maximumFrameSize: Int = TestStepHUDProtocolConstants.maximumFrameSize
    ) {
        self.maximumFrameSize = maximumFrameSize
    }

    public mutating func append(_ data: Data) throws -> [Data] {
        buffer.append(data)
        var payloads: [Data] = []

        while buffer.count >= 4 {
            let header = buffer.prefix(4)
            let length = header.reduce(UInt32(0)) { partial, byte in
                (partial << 8) | UInt32(byte)
            }
            let payloadLength = Int(length)

            guard payloadLength > 0 else {
                buffer.removeAll(keepingCapacity: false)
                throw TestStepHUDProtocolError.emptyFrame
            }
            guard payloadLength <= maximumFrameSize else {
                buffer.removeAll(keepingCapacity: false)
                throw TestStepHUDProtocolError.frameTooLarge(
                    actual: payloadLength,
                    maximum: maximumFrameSize
                )
            }

            let completeFrameLength = 4 + payloadLength
            guard buffer.count >= completeFrameLength else {
                break
            }

            payloads.append(buffer.subdata(in: 4..<completeFrameLength))
            buffer.removeSubrange(0..<completeFrameLength)
        }

        return payloads
    }
}
