extension RFC_2822.Timestamp {

    public enum Zone: Sendable, Hashable {
        case offset(minutes: Int)
        case unknown
    }
}

#if !hasFeature(Embedded)
    extension RFC_2822.Timestamp.Zone: Codable {}
#endif
