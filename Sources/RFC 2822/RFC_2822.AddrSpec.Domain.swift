import ASCII
import Binary
import INCITS_4_1986

extension RFC_2822.AddrSpec {

    /// An addr-spec's domain: a dot-atom, or a domain literal such as `[192.0.2.1]`, which DNS names don't cover.
    public struct Domain: Sendable {

        public let value: String

        public init(_ value: String) throws(RFC_2822.AddrSpec.Error) {
            guard !value.isEmpty else {
                throw RFC_2822.AddrSpec.Error.invalidDomain("")
            }
            let codes: [ASCII.Code]
            do throws(ASCII.Code.Error) {
                codes = try [Byte](utf8: value).map { byte throws(ASCII.Code.Error) in try ASCII.Code(byte) }
            } catch {
                throw RFC_2822.AddrSpec.Error.invalidDomain(value)
            }
            try Self.validate(codes)
            self.value = value
        }
    }
}

extension RFC_2822.AddrSpec.Domain: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(value.lowercased())
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.value.lowercased() == rhs.value.lowercased()
    }
}

extension RFC_2822.AddrSpec.Domain: Swift::RawRepresentable {

    public var rawValue: String { value }

    public init?(rawValue: String) {
        do throws(RFC_2822.AddrSpec.Error) {
            try self.init(rawValue)
        } catch {
            return nil
        }
    }
}

extension RFC_2822.AddrSpec.Domain: CustomStringConvertible {

    public var description: String { value }
}

extension RFC_2822.AddrSpec.Domain {

    private static func validate<Codes: Swift::Collection>(
        _ codes: Codes
    ) throws(RFC_2822.AddrSpec.Error) where Codes.Element == ASCII.Code {
        guard let firstCode = codes.first else {
            throw RFC_2822.AddrSpec.Error.invalidDomain("")
        }

        var lastCode = firstCode
        for code in codes { lastCode = code }

        if firstCode == ASCII.Code.leftSquareBracket && lastCode == ASCII.Code.rightSquareBracket {

            try validateLiteral(codes)
        } else {

            try RFC_2822.AddrSpec.validateDotAtom(codes, for: .domain)
        }
    }

    private static func validateLiteral<Codes: Swift::Collection>(
        _ codes: Codes
    ) throws(RFC_2822.AddrSpec.Error) where Codes.Element == ASCII.Code {
        var isEscaped = false
        var isFirst = true
        var codeCount = 0
        let totalCount = codes.count

        for code in codes {
            codeCount += 1

            if isFirst {
                isFirst = false
                continue
            }
            if codeCount == totalCount { continue }

            if isEscaped {

                guard
                    code == ASCII.Code.leftSquareBracket
                        || code == ASCII.Code.rightSquareBracket
                        || code == ASCII.Code.reverseSolidus
                else {
                    throw RFC_2822.AddrSpec.Error.invalidDomain(String(ascii: codes))
                }
                isEscaped = false
            } else if code == ASCII.Code.reverseSolidus {
                isEscaped = true
            } else {

                let isValidDText =
                    (code >= 1 && code <= 8) || code == 11 || code == 12
                    || (code >= 14 && code <= 31) || (code >= 33 && code <= 90)
                    || (code >= 94 && code <= 126)
                guard isValidDText else {
                    throw RFC_2822.AddrSpec.Error.invalidDomain(String(ascii: codes))
                }
            }
        }

        if isEscaped {
            throw RFC_2822.AddrSpec.Error.invalidDomain(String(ascii: codes))
        }
    }
}

#if !hasFeature(Embedded)
    extension RFC_2822.AddrSpec.Domain: Codable {}
#endif
