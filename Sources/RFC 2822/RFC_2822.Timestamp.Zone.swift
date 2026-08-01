//
//  RFC_2822.Timestamp.Zone.swift
//  swift-rfc-2822
//

extension RFC_2822.Timestamp {
    /// The `zone` token per RFC 2822 Section 3.3.
    ///
    /// `-0000` (Section 3.3: "the time was generated on a system that may
    /// be in a local time zone other than universal time and that the
    /// date-time contains no information about the local time zone") and
    /// the obsolete alphabetic/military zones (Section 4.3: "SHOULD all be
    /// considered equivalent to '-0000'" — they are ambiguous) both parse
    /// to `.unknown`: a zero numeric offset that explicitly disclaims
    /// knowledge of the true local offset. `.offset` covers every other
    /// zone, including an explicit, known `+0000` / `UT` / `GMT`.
    public enum Zone: Sendable, Codable, Hashable {
        case offset(minutes: Int)
        case unknown
    }
}
