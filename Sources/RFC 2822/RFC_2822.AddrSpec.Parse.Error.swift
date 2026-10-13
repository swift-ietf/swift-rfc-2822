extension RFC_2822.AddrSpec.Parse {
    public enum Error: Swift::Error, Sendable, Equatable {
        case empty
        case missingAtSign
        case emptyLocalPart
        case emptyDomain
    }
}
