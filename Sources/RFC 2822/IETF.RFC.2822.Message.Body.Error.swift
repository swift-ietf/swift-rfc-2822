extension IETF.RFC.`2822`.Message.Body {

    public enum Error: Swift::Error, Sendable, Equatable, CustomStringConvertible {
        case never
    }
}

extension IETF.RFC.`2822`.Message.Body.Error {
    public var description: String {
        "Body parsing never fails"
    }
}
