//
//  RFC_2822.Timestamp.Month.swift
//  swift-rfc-2822
//

extension RFC_2822.Timestamp {
    /// The `month-name` token per RFC 2822 Section 3.3.
    public enum Month: Int, Sendable, Codable, Hashable, CaseIterable {
        case january = 1
        case february
        case march
        case april
        case may
        case june
        case july
        case august
        case september
        case october
        case november
        case december
    }
}

extension RFC_2822.Timestamp.Month {
    /// The 3-letter wire token (`"Jan"` ... `"Dec"`).
    public var abbreviation: String {
        switch self {
        case .january: return "Jan"
        case .february: return "Feb"
        case .march: return "Mar"
        case .april: return "Apr"
        case .may: return "May"
        case .june: return "Jun"
        case .july: return "Jul"
        case .august: return "Aug"
        case .september: return "Sep"
        case .october: return "Oct"
        case .november: return "Nov"
        case .december: return "Dec"
        }
    }
}
