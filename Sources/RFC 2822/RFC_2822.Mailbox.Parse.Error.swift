//
//  RFC_2822.Mailbox.Parse.Error.swift
//  swift-rfc-2822
//
//  Error type for RFC_2822.Mailbox.Parse
//

extension RFC_2822.Mailbox.Parse {
    public enum Error: Swift.Error, Sendable, Equatable {
        case empty
        case missingAtSign
        case unterminatedAngleBracket
        case emptyLocalPart
        case emptyDomain
    }
}
