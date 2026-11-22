extension IETF.RFC.`2822`.Mailbox.Parse {
    public struct Output: Sendable {
        public let displayName: Input?
        public let localPart: Input
        public let domain: Input

        @inlinable
        public init(displayName: Input?, localPart: Input, domain: Input) {
            self.displayName = displayName
            self.localPart = localPart
            self.domain = domain
        }
    }
}
