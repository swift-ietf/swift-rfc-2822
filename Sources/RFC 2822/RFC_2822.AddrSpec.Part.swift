//
//  RFC_2822.AddrSpec.Part.swift
//  swift-rfc-2822
//

extension RFC_2822.AddrSpec {
    /// Part being validated (for error context)
    enum Part {
        case localPart
        case domain
    }
}
