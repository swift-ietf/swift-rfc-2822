extension IETF.RFC.`2822`.Message {

    public enum Error: Swift::Error, Sendable, Equatable, CustomStringConvertible {
        case empty
        case invalidFields(IETF.RFC.`2822`.Fields.Error)
    }
}

extension IETF.RFC.`2822`.Message.Error {
    public var description: String {
        switch self {
        case .empty:
            return "Message cannot be empty"

        case .invalidFields(let error):
            return "Invalid fields: \(error)"
        }
    }
}
