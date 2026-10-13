extension RFC_2822.Message.Received {

    public enum Error: Swift::Error, Sendable, Equatable, CustomStringConvertible {
        case empty
        case missingSemicolon(_ value: String)
        case missingTimestamp(_ value: String)
        case invalidTimestamp(_ underlying: RFC_2822.Timestamp.Error)
        case invalidNameValuePair(_ underlying: NameValuePair.Error)
    }
}

extension RFC_2822.Message.Received.Error {
    public var description: String {
        switch self {
        case .empty:
            return "Received field cannot be empty"

        case .missingSemicolon(let value):
            return "Received field must contain semicolon before timestamp: '\(value)'"

        case .missingTimestamp(let value):
            return "Received field must contain timestamp after semicolon: '\(value)'"

        case .invalidTimestamp(let error):
            return "Invalid timestamp in received field: \(error)"

        case .invalidNameValuePair(let error):
            return "Invalid name-value pair: \(error)"
        }
    }
}
