extension RFC_2822.Message.ID {

    public enum Error: Swift::Error, Sendable, Equatable, CustomStringConvertible {
        case empty
        case missingAngleBrackets(_ value: String)
        case missingAtSign(_ value: String)
        case invalidIdLeft(_ value: String)
        case invalidIdRight(_ value: String)
    }
}

extension RFC_2822.Message.ID.Error {
    public var description: String {
        switch self {
        case .empty:
            return "Message ID cannot be empty"

        case .missingAngleBrackets(let value):
            return "Message ID must be enclosed in angle brackets: '\(value)'"

        case .missingAtSign(let value):
            return "Message ID must contain '@': '\(value)'"

        case .invalidIdLeft(let value):
            return "Invalid id-left in message ID: '\(value)'"

        case .invalidIdRight(let value):
            return "Invalid id-right in message ID: '\(value)'"
        }
    }
}
