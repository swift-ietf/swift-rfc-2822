extension RFC_2822.Message.Path {

    public enum Error: Swift::Error, Sendable, Equatable, CustomStringConvertible {
        case empty
        case missingAngleBrackets(_ value: String)
        case invalidAddrSpec(_ underlying: RFC_2822.AddrSpec.Error)
    }
}

extension RFC_2822.Message.Path.Error {
    public var description: String {
        switch self {
        case .empty:
            return "Path cannot be empty"

        case .missingAngleBrackets(let value):
            return "Path must be enclosed in angle brackets: '\(value)'"

        case .invalidAddrSpec(let error):
            return "Invalid addr-spec in path: \(error)"
        }
    }
}
