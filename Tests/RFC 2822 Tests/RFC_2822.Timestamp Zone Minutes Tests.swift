import Testing

@testable import RFC_2822

@Suite
struct `Timestamp zone minutes` {
    @Test(arguments: ["+0060", "+0099", "-0175"])
    func `a zone with more than 59 minutes is refused`(_ zone: String) {
        #expect(throws: RFC_2822.Timestamp.Error.self) {
            try RFC_2822.Timestamp(ascii: [Byte](utf8: "Fri, 13 Feb 2009 23:31:30 " + zone))
        }
    }

    @Test
    func `a zone of hours and minutes is read as such`() throws {
        let timestamp = try RFC_2822.Timestamp(ascii: [Byte](utf8: "Fri, 13 Feb 2009 23:31:30 +0130"))
        #expect(timestamp.zone == .offset(minutes: 90))
    }
}
