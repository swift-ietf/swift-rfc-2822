//
//  RFC_2822.AddrSpec.Parse.Error.swift
//  swift-rfc-2822
//
//  Error type for RFC_2822.AddrSpec.Parse
//

extension RFC_2822.AddrSpec.Parse {
    public enum Error: Swift.Error, Sendable, Equatable {
        case empty
        case missingAtSign
        case emptyLocalPart
        case emptyDomain
    }
}
