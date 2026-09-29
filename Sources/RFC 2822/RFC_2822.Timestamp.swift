public import ASCII
public import Binary
import INCITS_4_1986

extension RFC_2822 {

    public struct Timestamp: Sendable, Codable {

        public let dayOfWeek: DayOfWeek?
        public let day: Int
        public let month: Month
        public let year: Int
        public let hour: Int
        public let minute: Int
        public let second: Int
        public let zone: Zone

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
            guard
                day >= 1 && day <= RFC_2822.Timestamp.daysInMonth(month: month.rawValue, year: year)
            else { throw Error.invalidComponent("day", "\(day)") }
            guard hour >= 0 && hour <= 23 else { throw Error.invalidComponent("hour", "\(hour)") }
            guard minute >= 0 && minute <= 59 else {
                throw Error.invalidComponent("minute", "\(minute)")
            }

            guard second >= 0 && second <= 60 else {
                throw Error.invalidComponent("second", "\(second)")
            }
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

extension RFC_2822.Timestamp {

    static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    static func daysInMonth(month: Int, year: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        case 2: return isLeapYear(year) ? 29 : 28
        default: return 31
        }
    }

    static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (month + 9) % 12
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146097 + doe - 719468
    }

    static func civilFromDays(_ days: Int) -> (year: Int, month: Int, day: Int) {
        let z = days + 719468
        let era = (z >= 0 ? z : z - 146096) / 146097
        let doe = z - era * 146097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        return (y + (m <= 2 ? 1 : 0), m, d)
    }

    static func dayOfWeek(fromDays days: Int) -> DayOfWeek {
        let sundayFirst = days >= -4 ? (days + 4) % 7 : (days + 5) % 7 + 6
        let mondayFirst = (sundayFirst + 6) % 7
        return DayOfWeek(rawValue: mondayFirst) ?? .monday
    }
}

extension RFC_2822.Timestamp {

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

extension RFC_2822.Timestamp: Hashable {

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.secondsSinceEpoch == rhs.secondsSinceEpoch
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(secondsSinceEpoch)
    }
}

extension RFC_2822.Timestamp {

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

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ timestamp: RFC_2822.Timestamp,
        into buffer: inout Buffer
    ) where Buffer.Element == ASCII.Code {
        for byte in text(for: timestamp).utf8 { buffer.append(ASCII.Code(byte)) }
    }

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ timestamp: RFC_2822.Timestamp,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        for byte in text(for: timestamp).utf8 { buffer.append(Byte(byte)) }
    }
}

extension RFC_2822.Timestamp: ASCII.Parseable {

    public init<Bytes: Swift.Collection>(ascii bytes: Bytes) throws(Error)
    where Bytes.Element == Byte {
        guard !bytes.isEmpty else { throw Error.empty }

        var codeArray: [ASCII.Code]
        do throws(ASCII.Code.Error) {
            codeArray = try bytes.map { byte throws(ASCII.Code.Error) in try ASCII.Code(byte) }
        } catch {
            throw Error.invalidFormat(String(decoding: bytes, as: UTF8.self))
        }

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

        let original = String(ascii: codeArray)

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

        func peekLetters(_ count: Int) -> String? {
            guard idx + count <= end else { return nil }
            for offset in 0..<count {
                guard codeArray[idx + offset].isLetter else { return nil }
            }
            return String(ascii: codeArray[idx..<(idx + count)]).lowercased()
        }

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
            let token = String(ascii: codeArray[idx..<letterEnd]).uppercased()
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
            default: return .unknown
            }
        }

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

        skipCFWS()
        guard let (dayValue, _) = parseDigits(max: 2) else { throw Error.invalidFormat(original) }
        guard dayValue >= 1 && dayValue <= 31 else {
            throw Error.invalidComponent("day", "\(dayValue)")
        }

        skipCFWS()
        guard let monthToken = peekLetters(3), let month = monthNames[monthToken] else {
            let remainder = String(ascii: codeArray[idx...])
            throw Error.invalidMonthName(remainder)
        }
        idx += 3

        skipCFWS()
        guard let (yearValue, yearDigits) = parseDigits(max: 9) else {
            throw Error.invalidFormat(original)
        }
        var year = yearValue
        if yearDigits == 2 {

            year += yearValue < 50 ? 2000 : 1900
        } else if yearDigits == 3 {
            year += 1900
        }

        skipCFWS()
        guard let (hourValue, _) = parseDigits(max: 2) else { throw Error.invalidFormat(original) }
        guard hourValue >= 0 && hourValue <= 23 else {
            throw Error.invalidComponent("hour", "\(hourValue)")
        }

        skipCFWS()
        guard idx < end && codeArray[idx] == ASCII.Code.colon else {
            throw Error.invalidFormat(original)
        }
        idx += 1
        skipCFWS()
        guard let (minuteValue, _) = parseDigits(max: 2) else {
            throw Error.invalidFormat(original)
        }
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

extension RFC_2822.Timestamp: Swift.RawRepresentable {

    public var rawValue: String { description }

    public init?(rawValue: String) {
        do throws(RFC_2822.Timestamp.Error) {
            try self.init(ascii: rawValue.utf8.map { Byte($0) })
        } catch {
            return nil
        }
    }
}

extension RFC_2822.Timestamp: CustomStringConvertible {

    public var description: String {
        Self.text(for: self)
    }
}
