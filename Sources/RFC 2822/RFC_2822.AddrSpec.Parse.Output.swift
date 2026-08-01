//
//  RFC_2822.AddrSpec.Parse.Output.swift
//  swift-rfc-2822
//
//  Output of RFC_2822.AddrSpec.Parse
//

extension RFC_2822.AddrSpec.Parse {
    public struct Output: Sendable {
        public let localPart: Input
        public let domain: Input

        @inlinable
        public init(localPart: Input, domain: Input) {
            self.localPart = localPart
            self.domain = domain
        }
    }
}
