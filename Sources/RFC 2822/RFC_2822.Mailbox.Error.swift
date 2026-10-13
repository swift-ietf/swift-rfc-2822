extension RFC_2822.Mailbox {

    public enum Error: Swift::Error, Sendable, Equatable {

        case empty

        case invalidFormat(_ value: String)

        case missingClosingAngleBracket(_ value: String)

        case invalidAddrSpec(RFC_2822.AddrSpec.Error)

        case invalidDisplayName(_ value: String)
    }
}

extension RFC_2822.Mailbox.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .empty:
            return "Mailbox cannot be empty"

        case .invalidFormat(let value):
            return "Invalid mailbox format '\(value)'"

        case .missingClosingAngleBracket(let value):
            return "Missing closing '>' in '\(value)'"

        case .invalidAddrSpec(let error):
            return "Invalid address: \(error)"

        case .invalidDisplayName(let value):
            return "Invalid display name (control byte or non-ASCII): '\(value)'"
        }
    }
}
