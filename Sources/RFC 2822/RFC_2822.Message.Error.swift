//
//  RFC_2822.Message.Error.swift
//  swift-rfc-2822
//
//  Error type for RFC_2822.Message
//

extension RFC_2822.Message {
    /// Errors during message parsing
    public enum Error: Swift.Error, Sendable, Equatable, CustomStringConvertible {
        case empty
        case invalidFields(RFC_2822.Fields.Error)
    }
}

extension RFC_2822.Message.Error {
    public var description: String {
        switch self {
        case .empty:
            return "Message cannot be empty"

        case .invalidFields(let error):
            return "Invalid fields: \(error)"
        }
    }
}
