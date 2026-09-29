public import ASCII
public import Binary
import INCITS_4_1986

extension RFC_2822.Message {

    public struct ID: Sendable, Codable {
        public let idLeft: String
        public let idRight: String

        init(__unchecked: Void, idLeft: String, idRight: String) {
            self.idLeft = idLeft
            self.idRight = idRight
        }

        public init(idLeft: String, idRight: String) {
            self.init(__unchecked: (), idLeft: idLeft, idRight: idRight)
        }
    }
}

extension RFC_2822.Message.ID: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(idLeft)
        hasher.combine(idRight.lowercased())
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.idLeft == rhs.idLeft && lhs.idRight.lowercased() == rhs.idRight.lowercased()
    }
}

extension RFC_2822.Message.ID: ASCII.Serializable, Binary.Serializable {

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ id: RFC_2822.Message.ID,
        into buffer: inout Buffer
    ) where Buffer.Element == ASCII.Code {
        buffer.reserveCapacity(id.idLeft.count + id.idRight.count + 3)
        buffer.append(ASCII.Code.lessThanSign)
        for byte in id.idLeft.utf8 { buffer.append(ASCII.Code(byte)) }
        buffer.append(ASCII.Code.commercialAt)
        for byte in id.idRight.utf8 { buffer.append(ASCII.Code(byte)) }
        buffer.append(ASCII.Code.greaterThanSign)
    }

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ id: RFC_2822.Message.ID,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        buffer.reserveCapacity(id.idLeft.count + id.idRight.count + 3)
        buffer.append(ASCII.Code.lessThanSign.byte)
        for byte in id.idLeft.utf8 { buffer.append(Byte(byte)) }
        buffer.append(ASCII.Code.commercialAt.byte)
        for byte in id.idRight.utf8 { buffer.append(Byte(byte)) }
        buffer.append(ASCII.Code.greaterThanSign.byte)
    }
}

extension RFC_2822.Message.ID: ASCII.Parseable {

    public init<Bytes: Swift.Collection>(ascii bytes: Bytes) throws(Error)
    where Bytes.Element == Byte {
        guard !bytes.isEmpty else { throw Error.empty }

        var codeArray: [ASCII.Code]
        do throws(ASCII.Code.Error) {
            codeArray = try bytes.map { byte throws(ASCII.Code.Error) in try ASCII.Code(byte) }
        } catch {
            throw Error.missingAngleBrackets(String(decoding: bytes, as: UTF8.self))
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

        guard
            codeArray.first == ASCII.Code.lessThanSign
                && codeArray.last == ASCII.Code.greaterThanSign
        else {
            throw Error.missingAngleBrackets(String(decoding: bytes, as: UTF8.self))
        }

        let contentCodes: [ASCII.Code] = Array(codeArray.dropFirst().dropLast())

        guard let atIndex = contentCodes.firstIndex(of: ASCII.Code.commercialAt) else {
            throw Error.missingAtSign(String(decoding: bytes, as: UTF8.self))
        }

        let idLeftCodes: [ASCII.Code] = Array(contentCodes[..<atIndex])
        let idRightCodes: [ASCII.Code] = Array(contentCodes[(atIndex + 1)...])

        guard !idLeftCodes.isEmpty else {
            throw Error.invalidIdLeft("")
        }

        let firstLeftCode = idLeftCodes[0]
        let lastLeftCode = idLeftCodes.last!

        if firstLeftCode == ASCII.Code.quotationMark && lastLeftCode == ASCII.Code.quotationMark {

            var isEscaped = false
            for code in idLeftCodes.dropFirst().dropLast() {
                if isEscaped {
                    isEscaped = false
                } else if code == ASCII.Code.reverseSolidus {
                    isEscaped = true
                } else {

                    let isValidQText =
                        (code >= 32 && code <= 126) && code != ASCII.Code.reverseSolidus
                        && code != ASCII.Code.quotationMark
                    guard isValidQText else {
                        throw Error.invalidIdLeft(String(ascii: idLeftCodes))
                    }
                }
            }
            if isEscaped {
                throw Error.invalidIdLeft(String(ascii: idLeftCodes))
            }
        } else {

            guard firstLeftCode != ASCII.Code.period && lastLeftCode != ASCII.Code.period else {
                throw Error.invalidIdLeft(String(ascii: idLeftCodes))
            }

            var previousCode: ASCII.Code = ASCII.Code(0)
            for code in idLeftCodes {
                if code == ASCII.Code.period && previousCode == ASCII.Code.period {
                    throw Error.invalidIdLeft(String(ascii: idLeftCodes))
                }
                previousCode = code

                if code == ASCII.Code.period { continue }

                let isAtext =
                    code.isLetter || code.isDigit || code == 0x21
                    || code == ASCII.Code.numberSign
                    || code == ASCII.Code.dollarSign
                    || code == ASCII.Code.percentSign
                    || code == ASCII.Code.ampersand
                    || code == ASCII.Code.apostrophe
                    || code == ASCII.Code.asterisk
                    || code == ASCII.Code.plusSign
                    || code == ASCII.Code.hyphen
                    || code == ASCII.Code.solidus
                    || code == ASCII.Code.equalsSign
                    || code == ASCII.Code.questionMark
                    || code == ASCII.Code.circumflexAccent
                    || code == 0x5F
                    || code == 0x60
                    || code == 0x7B
                    || code == ASCII.Code.verticalLine
                    || code == 0x7D
                    || code == 0x7E

                guard isAtext else {
                    throw Error.invalidIdLeft(String(ascii: idLeftCodes))
                }
            }
        }

        guard !idRightCodes.isEmpty else {
            throw Error.invalidIdRight("")
        }

        let firstRightCode = idRightCodes[0]
        let lastRightCode = idRightCodes.last!

        if firstRightCode == ASCII.Code.leftSquareBracket
            && lastRightCode == ASCII.Code.rightSquareBracket
        {

            for code in idRightCodes.dropFirst().dropLast() {

                let isValidDText = (code >= 33 && code <= 90) || (code >= 94 && code <= 126)
                guard isValidDText else {
                    throw Error.invalidIdRight(String(ascii: idRightCodes))
                }
            }
        } else {

            guard firstRightCode != ASCII.Code.period && lastRightCode != ASCII.Code.period else {
                throw Error.invalidIdRight(String(ascii: idRightCodes))
            }

            var previousCode: ASCII.Code = ASCII.Code(0)
            for code in idRightCodes {
                if code == ASCII.Code.period && previousCode == ASCII.Code.period {
                    throw Error.invalidIdRight(String(ascii: idRightCodes))
                }
                previousCode = code

                if code == ASCII.Code.period { continue }

                let isAtext =
                    code.isLetter || code.isDigit || code == 0x21
                    || code == ASCII.Code.numberSign
                    || code == ASCII.Code.dollarSign
                    || code == ASCII.Code.percentSign
                    || code == ASCII.Code.ampersand
                    || code == ASCII.Code.apostrophe
                    || code == ASCII.Code.asterisk
                    || code == ASCII.Code.plusSign
                    || code == ASCII.Code.hyphen
                    || code == ASCII.Code.solidus
                    || code == ASCII.Code.equalsSign
                    || code == ASCII.Code.questionMark
                    || code == ASCII.Code.circumflexAccent
                    || code == 0x5F
                    || code == 0x60
                    || code == 0x7B
                    || code == ASCII.Code.verticalLine
                    || code == 0x7D
                    || code == 0x7E

                guard isAtext else {
                    throw Error.invalidIdRight(String(ascii: idRightCodes))
                }
            }
        }

        self.init(
            __unchecked: (),
            idLeft: String(ascii: idLeftCodes),
            idRight: String(ascii: idRightCodes)
        )
    }
}

extension RFC_2822.Message.ID: Swift.RawRepresentable {

    public var rawValue: String { description }

    public init?(rawValue: String) {
        do throws(RFC_2822.Message.ID.Error) {
            try self.init(ascii: rawValue.utf8.map { Byte($0) })
        } catch {
            return nil
        }
    }
}

extension RFC_2822.Message.ID: CustomStringConvertible {

    public var description: String {
        "<\(idLeft)@\(idRight)>"
    }
}
