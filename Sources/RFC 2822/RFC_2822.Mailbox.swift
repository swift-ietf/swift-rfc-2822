public import ASCII
public import Binary
import INCITS_4_1986

extension RFC_2822 {

    public struct Mailbox: Hashable, Sendable, Codable {
        public let displayName: String?
        public let emailAddress: AddrSpec

        init(__unchecked: Void, displayName: String?, emailAddress: AddrSpec) {
            self.displayName = displayName
            self.emailAddress = emailAddress
        }

        public init(displayName: String? = nil, emailAddress: AddrSpec) throws(Error) {
            if let displayName { try Self.validateDisplayName(displayName) }
            self.init(__unchecked: (), displayName: displayName, emailAddress: emailAddress)
        }
    }
}

extension RFC_2822.Mailbox {

    static func validateDisplayName(_ displayName: String) throws(Error) {
        for byte in displayName.utf8 {
            guard byte < 0x80 else { throw Error.invalidDisplayName(displayName) }
            guard byte >= 0x20 && byte != 0x7F else {
                throw Error.invalidDisplayName(displayName)
            }
        }
    }

    fileprivate static func preconditionInjectionSafe(_ displayName: String) {
        precondition(
            !displayName.utf8.contains(where: { $0 == 0x0D || $0 == 0x0A }),
            "RFC_2822.Mailbox: displayName contains CR/LF at serialize time — "
                + "construction-time validation was bypassed"
        )
    }
}

extension RFC_2822.Mailbox: ASCII.Serializable, Binary.Serializable {

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ mailbox: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == ASCII.Code {
        if let displayName = mailbox.displayName {
            preconditionInjectionSafe(displayName)
            let needsQuoting = displayName.utf8.contains { byte in
                let code = ASCII.Code(byte)
                return !code.isLetter && !code.isDigit && code != ASCII.Code.space
            }
            if needsQuoting {
                buffer.append(ASCII.Code.quotationMark)
                for byte in displayName.utf8 {
                    let code = ASCII.Code(byte)

                    if code == ASCII.Code.quotationMark || code == ASCII.Code.reverseSolidus {
                        buffer.append(ASCII.Code.reverseSolidus)
                    }
                    buffer.append(code)
                }
                buffer.append(ASCII.Code.quotationMark)
            } else {
                for byte in displayName.utf8 { buffer.append(ASCII.Code(byte)) }
            }
            buffer.append(ASCII.Code.space)
            buffer.append(ASCII.Code.lessThanSign)
            RFC_2822.AddrSpec.serialize(mailbox.emailAddress, into: &buffer)
            buffer.append(ASCII.Code.greaterThanSign)
        } else {
            RFC_2822.AddrSpec.serialize(mailbox.emailAddress, into: &buffer)
        }
    }

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ mailbox: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        if let displayName = mailbox.displayName {
            preconditionInjectionSafe(displayName)
            let needsQuoting = displayName.utf8.contains { byte in
                let code = ASCII.Code(byte)
                return !code.isLetter && !code.isDigit && code != ASCII.Code.space
            }
            if needsQuoting {
                buffer.append(ASCII.Code.quotationMark.byte)
                for byte in displayName.utf8 {
                    let code = ASCII.Code(byte)

                    if code == ASCII.Code.quotationMark || code == ASCII.Code.reverseSolidus {
                        buffer.append(ASCII.Code.reverseSolidus.byte)
                    }
                    buffer.append(Byte(byte))
                }
                buffer.append(ASCII.Code.quotationMark.byte)
            } else {
                for byte in displayName.utf8 { buffer.append(Byte(byte)) }
            }
            buffer.append(ASCII.Code.space.byte)
            buffer.append(ASCII.Code.lessThanSign.byte)
            RFC_2822.AddrSpec.serialize(mailbox.emailAddress, into: &buffer)
            buffer.append(ASCII.Code.greaterThanSign.byte)
        } else {
            RFC_2822.AddrSpec.serialize(mailbox.emailAddress, into: &buffer)
        }
    }
}

extension RFC_2822.Mailbox: ASCII.Parseable {

    public init<Bytes: Swift.Collection>(ascii bytes: Bytes) throws(Error)
    where Bytes.Element == Byte {
        guard !bytes.isEmpty else { throw Error.empty }

        let codeArray: [ASCII.Code]
        do throws(ASCII.Code.Error) {
            codeArray = try [ASCII.Code](bytes)
        } catch {
            throw Error.invalidFormat(String(decoding: bytes, as: UTF8.self))
        }

        if let openIndex = codeArray.lastIndex(of: ASCII.Code.lessThanSign) {

            guard let closeIndex = codeArray.lastIndex(of: ASCII.Code.greaterThanSign),
                closeIndex > openIndex
            else {
                throw Error.missingClosingAngleBracket(String(decoding: bytes, as: UTF8.self))
            }

            var trimmedDisplayNameCodes: [ASCII.Code] = []
            trimmedDisplayNameCodes.append(contentsOf: codeArray[..<openIndex])
            while !trimmedDisplayNameCodes.isEmpty
                && (trimmedDisplayNameCodes.first == ASCII.Code.space
                    || trimmedDisplayNameCodes.first == ASCII.Code.htab)
            {
                trimmedDisplayNameCodes.removeFirst()
            }
            while !trimmedDisplayNameCodes.isEmpty
                && (trimmedDisplayNameCodes.last == ASCII.Code.space
                    || trimmedDisplayNameCodes.last == ASCII.Code.htab)
            {
                trimmedDisplayNameCodes.removeLast()
            }

            var displayName = String(decoding: trimmedDisplayNameCodes, as: UTF8.self)

            if !trimmedDisplayNameCodes.isEmpty
                && trimmedDisplayNameCodes.first == ASCII.Code.quotationMark
                && trimmedDisplayNameCodes.last == ASCII.Code.quotationMark
            {
                displayName = String(
                    decoding: trimmedDisplayNameCodes.dropFirst().dropLast(),
                    as: UTF8.self
                )
            }

            let addrSpecStart = codeArray.index(after: openIndex)
            let addrSpecBytes = [Byte](codeArray[addrSpecStart..<closeIndex])

            let emailAddress: RFC_2822.AddrSpec
            do throws(RFC_2822.AddrSpec.Error) {
                emailAddress = try RFC_2822.AddrSpec(ascii: addrSpecBytes)
            } catch {
                throw Error.invalidAddrSpec(error)
            }

            let validatedDisplayName = displayName.isEmpty ? nil : displayName
            if let validatedDisplayName {
                try Self.validateDisplayName(validatedDisplayName)
            }

            self.init(
                __unchecked: (),
                displayName: validatedDisplayName,
                emailAddress: emailAddress
            )
        } else {

            let emailAddress: RFC_2822.AddrSpec
            do throws(RFC_2822.AddrSpec.Error) {
                emailAddress = try RFC_2822.AddrSpec(ascii: bytes)
            } catch {
                throw Error.invalidAddrSpec(error)
            }

            self.init(__unchecked: (), displayName: nil, emailAddress: emailAddress)
        }
    }
}

extension RFC_2822.Mailbox: Swift.RawRepresentable {

    public var rawValue: String { description }

    public init?(rawValue: String) {
        do throws(RFC_2822.Mailbox.Error) {
            try self.init(ascii: rawValue.utf8.map { Byte($0) })
        } catch {
            return nil
        }
    }
}

extension RFC_2822.Mailbox: CustomStringConvertible {

    public var description: String {
        guard let displayName else { return emailAddress.description }
        Self.preconditionInjectionSafe(displayName)
        let needsQuoting = displayName.utf8.contains { byte in
            let code = ASCII.Code(byte)
            return !code.isLetter && !code.isDigit && code != ASCII.Code.space
        }
        guard needsQuoting else { return "\(displayName) <\(emailAddress)>" }

        var escaped = ""
        escaped.reserveCapacity(displayName.count)
        for character in displayName {
            if character == "\"" || character == "\\" { escaped.append("\\") }
            escaped.append(character)
        }
        return "\"\(escaped)\" <\(emailAddress)>"
    }
}
