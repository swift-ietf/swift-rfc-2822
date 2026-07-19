// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-rfc-2822 open source project
//
// Copyright (c) 2025 Coen ten Thije Boonkkamp
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
// ===----------------------------------------------------------------------===//

public import ASCII_Serializer_Primitives
public import Binary_Serializable_Primitives
import INCITS_4_1986
public import Parseable_ASCII_Primitives

extension RFC_2822 {
    /// RFC 2822 timestamp
    ///
    /// Per RFC 2822 Section 3.3:
    /// ```
    /// date-time = [ day-of-week "," ] date FWS time [CFWS]
    /// date = day month year
    /// time = time-of-day FWS zone
    /// time-of-day = hour ":" minute [ ":" second ]
    /// zone = (( "+" / "-" ) 4DIGIT) / obs-zone
    /// ```
    ///
    /// The full RFC 2822 date-time grammar — day-of-week, date, time-of-day,
    /// and zone — is this type's AUTHORITATIVE wire form: every
    /// `ASCII.Parseable` / `ASCII.Serializable` / `Binary.Serializable`
    /// conformance reads and writes real date-time text (e.g. `Fri, 21 Nov
    /// 1997 09:55:06 -0600`), not a bare numeric epoch. `secondsSinceEpoch`
    /// remains available as a derived accessor, computed from the stored
    /// calendar fields with a pure-Swift proleptic-Gregorian conversion — no
    /// `Foundation.Date` / `Calendar` dependency (this target stays
    /// Foundation-free per the workspace's primitives-layer rule).
    /// `Foundation.Date` / `FormatStyle` interop belongs in the sibling
    /// `RFC 2822 Foundation` target.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let generated = RFC_2822.Timestamp(secondsSinceEpoch: 1234567890)
    /// let parsed = try RFC_2822.Timestamp(
    ///     ascii: Array("Fri, 13 Feb 2009 23:31:30 +0000".utf8)
    /// )
    /// ```
    public struct Timestamp: Sendable, Codable {
        /// The `day-name` token, if the wire text carried one. RFC 2822
        /// permits (but does not require) a day name preceding the date.
        /// On parse this is preserved verbatim from the wire text and is
        /// NOT cross-checked against the actual weekday of
        /// `day`/`month`/`year` — a mismatching day name is a generator
        /// bug, not a parse failure (Section 3.3 leniency).
        public let dayOfWeek: DayOfWeek?
        public let day: Int
        public let month: Month
        public let year: Int
        public let hour: Int
        public let minute: Int
        public let second: Int
        public let zone: Zone

        /// Creates a timestamp WITHOUT validation
        init(
            __unchecked: Void,
            dayOfWeek: DayOfWeek?,
            day: Int,
            month: Month,
            year: Int,
            hour: Int,
            minute: Int,
            second: Int,
            zone: Zone
        ) {
            self.dayOfWeek = dayOfWeek
            self.day = day
            self.month = month
            self.year = year
            self.hour = hour
            self.minute = minute
            self.second = second
            self.zone = zone
        }

        /// Creates a timestamp from explicit RFC 2822 date-time components
        ///
        /// - Throws: `Error` if any component is out of range for the
        ///   proleptic Gregorian calendar (e.g. day 30 in February) or
        ///   outside its wire-grammar bounds (e.g. minute 60).
        public init(
            dayOfWeek: DayOfWeek? = nil,
            day: Int,
            month: Month,
            year: Int,
            hour: Int,
            minute: Int,
            second: Int = 0,
            zone: Zone = .offset(minutes: 0)
        ) throws(Error) {
            guard day >= 1 && day <= RFC_2822.Timestamp.daysInMonth(month: month.rawValue, year: year)
            else { throw Error.invalidComponent("day", "\(day)") }
            guard hour >= 0 && hour <= 23 else { throw Error.invalidComponent("hour", "\(hour)") }
            guard minute >= 0 && minute <= 59 else { throw Error.invalidComponent("minute", "\(minute)") }
            // RFC 2822 second = 2DIGIT; tolerate a positive leap second (60).
            guard second >= 0 && second <= 60 else { throw Error.invalidComponent("second", "\(second)") }
            if case .offset(let minutes) = zone {
                guard minutes > -1440 && minutes < 1440 else {
                    throw Error.invalidComponent("zone", "\(minutes)")
                }
            }

            self.init(
                __unchecked: (),
                dayOfWeek: dayOfWeek,
                day: day,
                month: month,
                year: year,
                hour: hour,
                minute: minute,
                second: second,
                zone: zone
            )
        }
    }
}

// MARK: - DayOfWeek

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

// MARK: - Month

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

// MARK: - Zone

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

// MARK: - Proleptic Gregorian Calendar Conversion (Foundation-free)

extension RFC_2822.Timestamp {
    /// `true` if `year` is a leap year in the proleptic Gregorian calendar.
    static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    /// Days in `month` (1-12) for `year`, per the proleptic Gregorian calendar.
    static func daysInMonth(month: Int, year: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        case 2: return isLeapYear(year) ? 29 : 28
        default: return 31
        }
    }

    /// Days since the epoch (1970-01-01) for a proleptic-Gregorian civil
    /// date. Howard Hinnant's `days_from_civil` algorithm (public domain,
    /// http://howardhinnant.github.io/date_algorithms.html), transliterated
    /// to Swift integer arithmetic — valid for every `Int`-representable
    /// year, no `Foundation.Calendar` dependency.
    static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400  // [0, 399]
        let mp = (month + 9) % 12  // [0, 11]
        let doy = (153 * mp + 2) / 5 + day - 1  // [0, 365]
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy  // [0, 146096]
        return era * 146097 + doe - 719468
    }

    /// Inverse of `daysFromCivil` — the proleptic-Gregorian civil date for
    /// `days` days since the epoch (1970-01-01).
    static func civilFromDays(_ days: Int) -> (year: Int, month: Int, day: Int) {
        let z = days + 719468
        let era = (z >= 0 ? z : z - 146096) / 146097
        let doe = z - era * 146097  // [0, 146096]
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365  // [0, 399]
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)  // [0, 365]
        let mp = (5 * doy + 2) / 153  // [0, 11]
        let d = doy - (153 * mp + 2) / 5 + 1  // [1, 31]
        let m = mp < 10 ? mp + 3 : mp - 9  // [1, 12]
        return (y + (m <= 2 ? 1 : 0), m, d)
    }

    /// The day-of-week for `days` days since the epoch (1970-01-01, a
    /// Thursday). Hinnant's `weekday_from_days` (0 = Sunday), remapped to
    /// `DayOfWeek`'s Monday-first raw values (0 = Monday ... 6 = Sunday).
    static func dayOfWeek(fromDays days: Int) -> DayOfWeek {
        let sundayFirst = days >= -4 ? (days + 4) % 7 : (days + 5) % 7 + 6  // [0, 6], 0 = Sunday
        let mondayFirst = (sundayFirst + 6) % 7
        return DayOfWeek(rawValue: mondayFirst) ?? .monday
    }
}

// MARK: - secondsSinceEpoch accessor

extension RFC_2822.Timestamp {
    /// Creates a timestamp from seconds-since-epoch (UTC — the RFC 2822
    /// `+0000` zone), with a computed, correct `dayOfWeek`.
    ///
    /// Sub-second precision does not survive the RFC 2822 wire form (its
    /// grammar has no fractional-seconds field) and is truncated toward
    /// negative infinity.
    public init(secondsSinceEpoch: Double) {
        let totalSeconds = Int(secondsSinceEpoch.rounded(.down))
        var days = totalSeconds / 86400
        var secondsOfDay = totalSeconds % 86400
        if secondsOfDay < 0 {
            secondsOfDay += 86400
            days -= 1
        }
        let (y, m, d) = Self.civilFromDays(days)
        self.init(
            __unchecked: (),
            dayOfWeek: Self.dayOfWeek(fromDays: days),
            day: d,
            month: Month(rawValue: m) ?? .january,
            year: y,
            hour: secondsOfDay / 3600,
            minute: (secondsOfDay % 3600) / 60,
            second: secondsOfDay % 60,
            zone: .offset(minutes: 0)
        )
    }

    /// The instant this timestamp denotes, as seconds since the epoch
    /// (1970-01-01T00:00:00 UTC) — derived from the stored calendar fields
    /// and `zone` offset (`.unknown` is treated as a zero offset, per its
    /// documented "no zone information" semantics).
    public var secondsSinceEpoch: Double {
        let days = Self.daysFromCivil(year: year, month: month.rawValue, day: day)
        let localSeconds = days * 86400 + hour * 3600 + minute * 60 + second
        let offsetSeconds: Int
        switch zone {
        case .offset(let minutes): offsetSeconds = minutes * 60
        case .unknown: offsetSeconds = 0
        }
        return Double(localSeconds - offsetSeconds)
    }
}

// MARK: - Hashable

extension RFC_2822.Timestamp: Hashable {
    /// Equality (and hashing) compare the resolved instant
    /// (`secondsSinceEpoch`), not the literal wire representation — two
    /// timestamps naming the same instant through different zones (or a
    /// present vs. absent `dayOfWeek`) are equal, matching this type's
    /// pre-existing epoch-based identity.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.secondsSinceEpoch == rhs.secondsSinceEpoch
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(secondsSinceEpoch)
    }
}

// MARK: - ASCII.Serializable / Binary.Serializable ([FAM-012] format siblings)

extension RFC_2822.Timestamp {
    /// The canonical RFC 2822 date-time wire text, e.g.
    /// `Fri, 21 Nov 1997 09:55:06 -0600`.
    ///
    /// Shared by the ASCII/Binary serialize verbs below (both iterate this
    /// `String`'s `.utf8` directly into their own buffer element type — the
    /// same "compose from a stored/derived `String`'s `.utf8`" shape
    /// `AddrSpec`/`Mailbox` use for their stored fields, not a
    /// `.serialized`/`.bytes` detour through each other) and by
    /// `description`.
    private static func text(for timestamp: Self) -> String {
        func pad(_ value: Int, _ width: Int) -> String {
            let digits = String(abs(value))
            guard digits.count < width else { return digits }
            return String(repeating: "0", count: width - digits.count) + digits
        }

        var out = ""
        if let dayOfWeek = timestamp.dayOfWeek {
            out += "\(dayOfWeek.abbreviation), "
        }
        out += "\(pad(timestamp.day, 2)) \(timestamp.month.abbreviation) \(pad(timestamp.year, 4)) "
        out += "\(pad(timestamp.hour, 2)):\(pad(timestamp.minute, 2)):\(pad(timestamp.second, 2)) "
        switch timestamp.zone {
        case .unknown:
            out += "-0000"
        case .offset(let minutes):
            let sign = minutes < 0 ? "-" : "+"
            let absMinutes = abs(minutes)
            out += "\(sign)\(pad(absMinutes / 60, 2))\(pad(absMinutes % 60, 2))"
        }
        return out
    }
}

extension RFC_2822.Timestamp: ASCII.Serializable, Binary.Serializable {
    /// Serializes the timestamp as RFC 2822 date-time ASCII text.
    ///
    /// [FAM-012] text sibling — emits the typed text substrate `ASCII.Code`.
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ timestamp: RFC_2822.Timestamp,
        into buffer: inout Buffer
    ) where Buffer.Element == ASCII.Code {
        for byte in text(for: timestamp).utf8 { buffer.append(ASCII.Code(byte)) }
    }

    /// Serializes the timestamp as RFC 2822 date-time wire bytes.
    ///
    /// [FAM-012] binary sibling. Clause-9: an independent body re-emitting
    /// the value directly into the `Byte` domain — byte-equivalent to the
    /// text form; the ASCII==Binary equivalence test guards the two bodies
    /// against drift.
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ timestamp: RFC_2822.Timestamp,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        for byte in text(for: timestamp).utf8 { buffer.append(Byte(byte)) }
    }
}

// MARK: - ASCII.Parseable ([FAM-012] parse — free-standing init; marker requirement seal-last)

extension RFC_2822.Timestamp: ASCII.Parseable {

    /// Parses a timestamp from ASCII bytes (AUTHORITATIVE IMPLEMENTATION)
    ///
    /// Implements the full RFC 2822 Section 3.3 `date-time` grammar —
    /// `[ day-of-week "," ] date FWS time [CFWS]` — with `obs-zone`
    /// leniency: named zones (`UT`, `GMT`, `EST`/`EDT`, `CST`/`CDT`,
    /// `MST`/`MDT`, `PST`/`PDT`) resolve to their fixed offsets; any other
    /// alphabetic zone token (the single-letter military zones, and any
    /// unrecognized alphabetic zone) resolves to `.unknown` per Section
    /// 4.3's "SHOULD all be considered equivalent to '-0000'" guidance.
    /// `obs-year` 2/3-digit century normalization (Section 4.3) is applied.
    ///
    /// - Parameter bytes: The timestamp as ASCII bytes
    /// - Throws: `Error` if parsing fails
    public init<Bytes: Collection>(ascii bytes: Bytes) throws(Error)
    where Bytes.Element == Byte {
        guard !bytes.isEmpty else { throw Error.empty }

        // Type-up: lift to ASCII.Code at the entry boundary so the body works
        // against ASCII.Code constants directly (RFC 2822 timestamp grammar is
        // strict ASCII).
        var codeArray: [ASCII.Code]
        do throws(ASCII.Code.Error) {
            codeArray = try [ASCII.Code](bytes)
        } catch {
            throw Error.invalidFormat(String(decoding: bytes, as: UTF8.self))
        }

        // Strip leading/trailing whitespace
        while !codeArray.isEmpty
            && (codeArray.first == ASCII.Code.space || codeArray.first == ASCII.Code.htab)
        {
            codeArray.removeFirst()
        }
        while !codeArray.isEmpty
            && (codeArray.last == ASCII.Code.space || codeArray.last == ASCII.Code.htab)
        {
            codeArray.removeLast()
        }

        guard !codeArray.isEmpty else { throw Error.empty }

        let original = String(decoding: codeArray, as: UTF8.self)

        let dayNames: [String: DayOfWeek] = [
            "mon": .monday, "tue": .tuesday, "wed": .wednesday, "thu": .thursday,
            "fri": .friday, "sat": .saturday, "sun": .sunday,
        ]
        let monthNames: [String: Month] = [
            "jan": .january, "feb": .february, "mar": .march, "apr": .april,
            "may": .may, "jun": .june, "jul": .july, "aug": .august,
            "sep": .september, "oct": .october, "nov": .november, "dec": .december,
        ]

        var idx = 0
        let end = codeArray.count

        // Skips FWS (space/htab runs) and `(...)` comments (nested, with
        // quoted-pair escapes honored) — the `CFWS` production.
        func skipCFWS() {
            while idx < end {
                if codeArray[idx] == ASCII.Code.space || codeArray[idx] == ASCII.Code.htab {
                    idx += 1
                } else if codeArray[idx] == ASCII.Code.leftParenthesis {
                    var depth = 1
                    idx += 1
                    while idx < end && depth > 0 {
                        if codeArray[idx] == ASCII.Code.reverseSolidus && idx + 1 < end {
                            idx += 2
                            continue
                        } else if codeArray[idx] == ASCII.Code.leftParenthesis {
                            depth += 1
                        } else if codeArray[idx] == ASCII.Code.rightParenthesis {
                            depth -= 1
                        }
                        idx += 1
                    }
                } else {
                    break
                }
            }
        }

        // Peeks (without consuming) a run of `count` letters, lowercased, or
        // nil if fewer than `count` letters remain at the cursor.
        func peekLetters(_ count: Int) -> String? {
            guard idx + count <= end else { return nil }
            for offset in 0..<count {
                guard codeArray[idx + offset].isLetter else { return nil }
            }
            return String(decoding: codeArray[idx..<(idx + count)], as: UTF8.self).lowercased()
        }

        // Consumes 1...max decimal digits, or nil if none are present.
        func parseDigits(max: Int) -> (value: Int, count: Int)? {
            var value = 0
            var count = 0
            while idx < end, count < max, let digit = codeArray[idx].digitValue {
                value = value * 10 + Int(digit)
                idx += 1
                count += 1
            }
            return count > 0 ? (value, count) : nil
        }

        // Consumes the `zone` token: numeric `(+|-)HHMM`, or an alphabetic
        // obs-zone (named or, per §4.3 leniency, unrecognized -> .unknown).
        func parseZone() -> Zone? {
            guard idx < end else { return nil }
            if codeArray[idx] == ASCII.Code.plusSign || codeArray[idx] == ASCII.Code.hyphen {
                let isNegative = codeArray[idx] == ASCII.Code.hyphen
                let saved = idx
                idx += 1
                guard let (value, count) = parseDigits(max: 4), count == 4 else {
                    idx = saved
                    return nil
                }
                let minutes = (value / 100) * 60 + (value % 100)
                if minutes == 0 && isNegative { return .unknown }
                return .offset(minutes: isNegative ? -minutes : minutes)
            }

            var letterEnd = idx
            while letterEnd < end && codeArray[letterEnd].isLetter { letterEnd += 1 }
            guard letterEnd > idx else { return nil }
            let token = String(decoding: codeArray[idx..<letterEnd], as: UTF8.self).uppercased()
            idx = letterEnd
            switch token {
            case "UT", "GMT": return .offset(minutes: 0)
            case "EST": return .offset(minutes: -300)
            case "EDT": return .offset(minutes: -240)
            case "CST": return .offset(minutes: -360)
            case "CDT": return .offset(minutes: -300)
            case "MST": return .offset(minutes: -420)
            case "MDT": return .offset(minutes: -360)
            case "PST": return .offset(minutes: -480)
            case "PDT": return .offset(minutes: -420)
            default: return .unknown  // obs-zone military / unrecognized alphabetic zone (§4.3)
            }
        }

        // ===== day-of-week "," (optional) =====

        skipCFWS()
        var dayOfWeek: DayOfWeek?
        let beforeDayName = idx
        if let token = peekLetters(3), let candidate = dayNames[token] {
            idx += 3
            skipCFWS()
            if idx < end && codeArray[idx] == ASCII.Code.comma {
                idx += 1
                dayOfWeek = candidate
            } else {
                idx = beforeDayName
            }
        }

        // ===== date = day month year =====

        skipCFWS()
        guard let (dayValue, _) = parseDigits(max: 2) else { throw Error.invalidFormat(original) }
        guard dayValue >= 1 && dayValue <= 31 else {
            throw Error.invalidComponent("day", "\(dayValue)")
        }

        skipCFWS()
        guard let monthToken = peekLetters(3), let month = monthNames[monthToken] else {
            let remainder = String(decoding: codeArray[idx...], as: UTF8.self)
            throw Error.invalidMonthName(remainder)
        }
        idx += 3

        skipCFWS()
        guard let (yearValue, yearDigits) = parseDigits(max: 9) else {
            throw Error.invalidFormat(original)
        }
        var year = yearValue
        if yearDigits == 2 {
            // obs-year §4.3: 00-49 -> 2000-2049, 50-99 -> 1950-1999.
            year += yearValue < 50 ? 2000 : 1900
        } else if yearDigits == 3 {
            year += 1900
        }

        // ===== time = time-of-day FWS zone =====

        skipCFWS()
        guard let (hourValue, _) = parseDigits(max: 2) else { throw Error.invalidFormat(original) }
        guard hourValue >= 0 && hourValue <= 23 else {
            throw Error.invalidComponent("hour", "\(hourValue)")
        }

        skipCFWS()
        guard idx < end && codeArray[idx] == ASCII.Code.colon else { throw Error.invalidFormat(original) }
        idx += 1
        skipCFWS()
        guard let (minuteValue, _) = parseDigits(max: 2) else { throw Error.invalidFormat(original) }
        guard minuteValue >= 0 && minuteValue <= 59 else {
            throw Error.invalidComponent("minute", "\(minuteValue)")
        }

        var secondValue = 0
        skipCFWS()
        if idx < end && codeArray[idx] == ASCII.Code.colon {
            idx += 1
            skipCFWS()
            guard let (parsedSecond, _) = parseDigits(max: 2) else {
                throw Error.invalidFormat(original)
            }
            // RFC 2822 second = 2DIGIT; tolerate a positive leap second (60).
            guard parsedSecond >= 0 && parsedSecond <= 60 else {
                throw Error.invalidComponent("second", "\(parsedSecond)")
            }
            secondValue = parsedSecond
        }

        skipCFWS()
        guard let zone = parseZone() else { throw Error.invalidZone(original) }

        skipCFWS()
        guard idx == end else { throw Error.invalidFormat(original) }

        self.init(
            __unchecked: (),
            dayOfWeek: dayOfWeek,
            day: dayValue,
            month: month,
            year: year,
            hour: hourValue,
            minute: minuteValue,
            second: secondValue,
            zone: zone
        )
    }
}

// MARK: - RawRepresentable / CustomStringConvertible

extension RFC_2822.Timestamp: Swift.RawRepresentable {
    /// The canonical RFC 2822 date-time string form.
    ///
    /// Re-provides `Swift.RawRepresentable` directly — the retired
    /// `Binary.ASCII.RawRepresentable` no longer synthesizes it.
    public var rawValue: String { description }

    /// Creates a timestamp by parsing `rawValue`, or `nil` if it is malformed.
    public init?(rawValue: String) {
        try? self.init(ascii: rawValue.utf8.map { Byte($0) })
    }
}

extension RFC_2822.Timestamp: CustomStringConvertible {
    /// The timestamp's RFC 2822 date-time text — the same form the
    /// `ASCII.Serializable` / `Binary.Serializable` verbs emit.
    public var description: String {
        Self.text(for: self)
    }
}
