extension RFC_2822.Message.Body {

    public enum Error: Swift::Error, Sendable, Equatable, CustomStringConvertible {
        case never
    }
}

extension RFC_2822.Message.Body.Error {
    public var description: String {
        "Body parsing never fails"
    }
}
