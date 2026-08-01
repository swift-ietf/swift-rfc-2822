//
//  RFC_2822.Message.Body.Error.swift
//  swift-rfc-2822
//
//  Error type for RFC_2822.Message.Body
//

extension RFC_2822.Message.Body {
    /// Error type (body parsing never fails).
    public enum Error: Swift.Error, Sendable, Equatable, CustomStringConvertible {
        case never
    }
}

extension RFC_2822.Message.Body.Error {
    public var description: String {
        "Body parsing never fails"
    }
}
