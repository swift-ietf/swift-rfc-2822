//
//  RFC_2822.Fields.Error.swift
//  swift-rfc-2822
//
//  Error type for RFC_2822.Fields
//

extension RFC_2822.Fields {

    /// Errors during fields parsing
    public enum Error: Swift.Error, Sendable, Equatable, CustomStringConvertible {
        case empty
        case missingRequiredField(_ fieldName: String)
        case invalidFieldFormat(_ fieldName: String, _ value: String)
        case invalidMailbox(RFC_2822.Mailbox.Error)
        case invalidAddress(RFC_2822.Address.Error)
        case invalidMessageID(RFC_2822.Message.ID.Error)
    }
}

extension RFC_2822.Fields.Error {
    public var description: String {
        switch self {
        case .empty:
            return "Fields cannot be empty"

        case .missingRequiredField(let fieldName):
            return "Missing required field: \(fieldName)"

        case .invalidFieldFormat(let fieldName, let value):
            return "Invalid format for field '\(fieldName)': '\(value)'"

        case .invalidMailbox(let error):
            return "Invalid mailbox: \(error)"

        case .invalidAddress(let error):
            return "Invalid address: \(error)"

        case .invalidMessageID(let error):
            return "Invalid message ID: \(error)"
        }
    }
}
