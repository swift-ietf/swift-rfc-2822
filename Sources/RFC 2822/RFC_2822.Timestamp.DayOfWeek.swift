//
//  RFC_2822.Timestamp.DayOfWeek.swift
//  swift-rfc-2822
//

extension RFC_2822.Timestamp {
    /// The `day-name` token per RFC 2822 Section 3.3.
    public enum DayOfWeek: Int, Sendable, Codable, Hashable, CaseIterable {
        case monday, tuesday, wednesday, thursday, friday, saturday, sunday
    }
}

extension RFC_2822.Timestamp.DayOfWeek {
    /// The 3-letter wire token (`"Mon"` ... `"Sun"`).
    public var abbreviation: String {
        switch self {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        }
    }
}
