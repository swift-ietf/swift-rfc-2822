extension IETF.RFC.`2822`.Fields {

    public enum Error: Swift::Error, Sendable, Equatable, CustomStringConvertible {
        case empty
        case missingRequiredField(_ fieldName: String)
        case invalidFieldFormat(_ fieldName: String, _ value: String)
        case invalidMailbox(IETF.RFC.`2822`.Mailbox.Error)
        case invalidAddress(IETF.RFC.`2822`.Address.Error)
        case invalidMessageID(IETF.RFC.`2822`.Message.ID.Error)
        case invalidReturnPath(IETF.RFC.`2822`.Message.Path.Error)
        case invalidReceived(IETF.RFC.`2822`.Message.Received.Error)
        case invalidResentBlock(IETF.RFC.`2822`.Message.ResentBlock.Error)
        case misplacedField(_ fieldName: String)
    }
}

extension IETF.RFC.`2822`.Fields.Error {
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

        case .invalidReturnPath(let error):
            return "Invalid Return-Path: \(error)"

        case .invalidReceived(let error):
            return "Invalid Received: \(error)"

        case .invalidResentBlock(let error):
            return "Invalid resent block: \(error)"

        case .misplacedField(let fieldName):
            return "Field out of trace, resent or origination order: \(fieldName)"
        }
    }
}
