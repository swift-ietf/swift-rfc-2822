extension IETF.RFC.`2822`.AddrSpec.Parse {
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
