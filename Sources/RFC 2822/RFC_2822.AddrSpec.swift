public import ASCII
public import Binary
import INCITS_4_1986

extension RFC_2822 {

    public struct AddrSpec: Sendable, Codable {
        public let localPart: String
        public let domain: String

        private init(
            __unchecked: Void,
            localPart: String,
            domain: String
        ) {
            self.localPart = localPart
            self.domain = domain
        }

        public init(
            localPart: String,
            domain: String
        ) throws(Error) {

            guard !localPart.isEmpty else {
                throw Error.invalidLocalPart("")
            }
            let localCodes: [ASCII.Code]
            do throws(ASCII.Code.Error) {
                localCodes = try [Byte](utf8: localPart).map { byte throws(ASCII.Code.Error) in try ASCII.Code(byte) }
            } catch {
                throw Error.invalidLocalPart(localPart)
            }
            try Self.validateLocalPart(localCodes)

            guard !domain.isEmpty else {
                throw Error.invalidDomain("")
            }
            let domainCodes: [ASCII.Code]
            do throws(ASCII.Code.Error) {
                domainCodes = try [Byte](utf8: domain).map { byte throws(ASCII.Code.Error) in try ASCII.Code(byte) }
            } catch {
                throw Error.invalidDomain(domain)
            }
            try Self.validateDomain(domainCodes)

            self.init(__unchecked: (), localPart: localPart, domain: domain)
        }
    }
}

extension RFC_2822.AddrSpec {

    fileprivate static func preconditionInjectionSafe(localPart: String, domain: String) {
        precondition(
            !localPart.utf8.contains(where: { $0 == 0x0D || $0 == 0x0A })
                && !domain.utf8.contains(where: { $0 == 0x0D || $0 == 0x0A }),
            "RFC_2822.AddrSpec: localPart/domain contains CR/LF at serialize time — "
                + "construction-time validation was bypassed"
        )
    }
}

extension RFC_2822.AddrSpec: Hashable {
    public func hash(into hasher: inout Hasher) {

        hasher.combine(localPart)
        hasher.combine(domain.lowercased())
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.localPart == rhs.localPart && lhs.domain.lowercased() == rhs.domain.lowercased()
    }
}

extension RFC_2822.AddrSpec: ASCII.Serializable, Binary.Serializable {

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ addrSpec: RFC_2822.AddrSpec,
        into buffer: inout Buffer
    ) where Buffer.Element == ASCII.Code {
        preconditionInjectionSafe(localPart: addrSpec.localPart, domain: addrSpec.domain)
        buffer.reserveCapacity(
            buffer.count + addrSpec.localPart.utf8.count + 1 + addrSpec.domain.utf8.count
        )
        for byte in addrSpec.localPart.utf8 { buffer.append(ASCII.Code(byte)) }
        buffer.append(ASCII.Code.commercialAt)
        for byte in addrSpec.domain.utf8 { buffer.append(ASCII.Code(byte)) }
    }

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ addrSpec: RFC_2822.AddrSpec,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        preconditionInjectionSafe(localPart: addrSpec.localPart, domain: addrSpec.domain)
        buffer.reserveCapacity(
            buffer.count + addrSpec.localPart.utf8.count + 1 + addrSpec.domain.utf8.count
        )
        for byte in addrSpec.localPart.utf8 { buffer.append(Byte(byte)) }
        buffer.append(ASCII.Code.commercialAt.byte)
        for byte in addrSpec.domain.utf8 { buffer.append(Byte(byte)) }
    }
}

extension RFC_2822.AddrSpec: ASCII.Parseable {

    public init<Bytes: Swift.Collection>(ascii bytes: Bytes) throws(Error)
    where Bytes.Element == Byte {
        guard !bytes.isEmpty else { throw Error.empty }

        var atIndex: Bytes.Index?
        for index in bytes.indices where bytes[index] == ASCII.Code.commercialAt.byte {
            atIndex = index
        }

        guard let at = atIndex else {
            throw Error.missingAtSign(String(decoding: bytes, as: UTF8.self))
        }

        let localPartBytes = bytes[..<at]
        let domainBytes = bytes[bytes.index(after: at)...]

        guard !localPartBytes.isEmpty else {
            throw Error.invalidLocalPart("")
        }

        guard !domainBytes.isEmpty else {
            throw Error.invalidDomain("")
        }

        try self.init(
            localPart: String(decoding: localPartBytes, as: UTF8.self),
            domain: String(decoding: domainBytes, as: UTF8.self)
        )
    }
}

extension RFC_2822.AddrSpec {

    private static func validateLocalPart<Codes: Swift.Collection>(
        _ codes: Codes
    ) throws(Error) where Codes.Element == ASCII.Code {
        guard let firstCode = codes.first else {
            throw Error.invalidLocalPart("")
        }

        var lastCode = firstCode
        for code in codes { lastCode = code }

        if firstCode == ASCII.Code.quotationMark && lastCode == ASCII.Code.quotationMark {

            try validateQuotedString(codes, for: .localPart)
        } else {

            try validateDotAtom(codes, for: .localPart)
        }
    }

    private static func validateDomain<Codes: Swift.Collection>(
        _ codes: Codes
    ) throws(Error) where Codes.Element == ASCII.Code {
        guard let firstCode = codes.first else {
            throw Error.invalidDomain("")
        }

        var lastCode = firstCode
        for code in codes { lastCode = code }

        if firstCode == ASCII.Code.leftSquareBracket && lastCode == ASCII.Code.rightSquareBracket {

            try validateDomainLiteral(codes)
        } else {

            try validateDotAtom(codes, for: .domain)
        }
    }

    private static func validateDotAtom<Codes: Swift.Collection>(
        _ codes: Codes,
        for part: Part
    ) throws(Error) where Codes.Element == ASCII.Code {
        guard let firstCode = codes.first else {
            throw errorFor(part, String(ascii: codes))
        }

        var lastCode = firstCode
        for code in codes { lastCode = code }

        guard firstCode != ASCII.Code.period && lastCode != ASCII.Code.period else {
            throw errorFor(part, String(ascii: codes))
        }

        var previousCode: ASCII.Code = ASCII.Code(0)
        for code in codes {

            if code == ASCII.Code.period && previousCode == ASCII.Code.period {
                throw errorFor(part, String(ascii: codes))
            }
            previousCode = code

            if code == ASCII.Code.period { continue }

            guard RFC_2822.isAtext(code) else {
                throw errorFor(part, String(ascii: codes))
            }
        }
    }

    private static func validateQuotedString<Codes: Swift.Collection>(
        _ codes: Codes,
        for part: Part
    ) throws(Error) where Codes.Element == ASCII.Code {
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
                isEscaped = false
            } else if code == ASCII.Code.reverseSolidus {
                isEscaped = true
            } else {

                let isValidQText =
                    (code >= 1 && code <= 8) || code == 11 || code == 12
                    || (code >= 14 && code <= 31) || code == 33 || (code >= 35 && code <= 91)
                    || (code >= 93 && code <= 126)
                guard isValidQText else {
                    throw errorFor(part, String(ascii: codes))
                }
            }
        }

        if isEscaped {
            throw errorFor(part, String(ascii: codes))
        }
    }

    private static func validateDomainLiteral<Codes: Swift.Collection>(
        _ codes: Codes
    ) throws(Error) where Codes.Element == ASCII.Code {
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
                    throw Error.invalidDomain(String(ascii: codes))
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
                    throw Error.invalidDomain(String(ascii: codes))
                }
            }
        }

        if isEscaped {
            throw Error.invalidDomain(String(ascii: codes))
        }
    }

    private static func errorFor(_ part: Part, _ value: String) -> RFC_2822.AddrSpec.Error {
        switch part {
        case .localPart: return Error.invalidLocalPart(value)
        case .domain: return Error.invalidDomain(value)
        }
    }
}

extension RFC_2822.AddrSpec: Swift.RawRepresentable {

    public var rawValue: String { description }

    public init?(rawValue: String) {
        do throws(RFC_2822.AddrSpec.Error) {
            try self.init(ascii: rawValue.utf8.map { Byte($0) })
        } catch {
            return nil
        }
    }
}

extension RFC_2822.AddrSpec: CustomStringConvertible {

    public var description: String {
        Self.preconditionInjectionSafe(localPart: localPart, domain: domain)
        return "\(localPart)@\(domain)"
    }
}
