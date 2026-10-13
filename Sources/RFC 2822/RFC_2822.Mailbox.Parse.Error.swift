extension RFC_2822.Mailbox.Parse {
    public enum Error: Swift::Error, Sendable, Equatable {
        case empty
        case missingAtSign
        case unterminatedAngleBracket
        case emptyLocalPart
        case emptyDomain
    }
}
