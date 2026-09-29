public import Binary

extension RFC_2822.Message {

    public struct Body: Hashable, Sendable {

        public let bytes: [Byte]

        init(__unchecked: Void, bytes: [Byte]) {
            self.bytes = bytes
        }

        public init(_ bytes: [Byte]) {
            self.init(__unchecked: (), bytes: bytes)
        }
    }
}

extension RFC_2822.Message.Body: Binary.Serializable {

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ body: RFC_2822.Message.Body,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        buffer.append(contentsOf: body.bytes)
    }
}

extension RFC_2822.Message.Body {

    public init<Bytes: Swift.Collection>(binary bytes: Bytes) where Bytes.Element == Byte {
        self.init(__unchecked: (), bytes: Array(bytes))
    }
}

extension RFC_2822.Message.Body: Swift.RawRepresentable {

    public var rawValue: String { description }

    public init?(rawValue: String) { self.init(rawValue) }
}

extension RFC_2822.Message.Body {

    public init(_ string: String) {
        self.init(__unchecked: (), bytes: [Byte](string.utf8))
    }
}

extension RFC_2822.Message.Body: CustomStringConvertible {

    public var description: String {
        String(decoding: bytes, as: UTF8.self)
    }
}

extension RFC_2822.Message.Body: Codable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()

        try container.encode(String(self))
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        self.init(string)
    }
}

extension RFC_2822.Message.Body: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}
