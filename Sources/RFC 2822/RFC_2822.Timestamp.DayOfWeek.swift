extension RFC_2822.Timestamp {

    public enum DayOfWeek: Int, Sendable, Hashable, CaseIterable {
        case monday, tuesday, wednesday, thursday, friday, saturday, sunday
    }
}

extension RFC_2822.Timestamp.DayOfWeek {

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

#if !hasFeature(Embedded)
    extension RFC_2822.Timestamp.DayOfWeek: Codable {}
#endif
