public import ASCII
public import Binary
import INCITS_4_1986

extension RFC_2822 {

    public struct Address: Sendable, Codable {
        public let kind: Kind

        init(__unchecked: Void, kind: Kind) {
            self.kind = kind
        }

        public init(_ kind: Kind) {
            self.init(__unchecked: (), kind: kind)
        }
    }
}

extension RFC_2822.Address {
    public enum Kind: Hashable, Sendable, Codable {
        case mailbox(RFC_2822.Mailbox)
        case group(String, [RFC_2822.Mailbox])
    }
}

extension RFC_2822.Address.Kind {
    private enum CodingKeys: String, CodingKey {
        case mailbox
        case group
    }

    private enum PayloadKeys: String, CodingKey {
        case _0
        case _1
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.mailbox) {
            let payload = try container.nestedContainer(
                keyedBy: PayloadKeys.self,
                forKey: .mailbox
            )
            let mailbox = try payload.decode(RFC_2822.Mailbox.self, forKey: ._0)
            self = .mailbox(mailbox)
        } else if container.contains(.group) {
            let payload = try container.nestedContainer(
                keyedBy: PayloadKeys.self,
                forKey: .group
            )
            let displayName = try payload.decode(String.self, forKey: ._0)
            let members = try payload.decode([RFC_2822.Mailbox].self, forKey: ._1)
            try RFC_2822.Mailbox.validateDisplayName(displayName)
            self = .group(displayName, members)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Expected a 'mailbox' or 'group' key"
                )
            )
        }
    }
}

extension RFC_2822.Address {

    fileprivate static func preconditionGroupDisplayNameInjectionSafe(_ displayName: String) {
        precondition(
            !displayName.utf8.contains(where: { $0 == 0x0D || $0 == 0x0A }),
            "RFC_2822.Address.Kind.group: display name contains CR/LF at serialize time — "
                + "construction-time validation was bypassed"
        )
    }
}

extension RFC_2822.Address: Hashable {}

extension RFC_2822.Address: ASCII.Serializable, Binary.Serializable {

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ address: RFC_2822.Address,
        into buffer: inout Buffer
    ) where Buffer.Element == ASCII.Code {
        switch address.kind {
        case .mailbox(let mailbox):
            RFC_2822.Mailbox.serialize(mailbox, into: &buffer)

        case .group(let displayName, let mailboxes):
            preconditionGroupDisplayNameInjectionSafe(displayName)
            for byte in displayName.utf8 { buffer.append(ASCII.Code(byte)) }
            buffer.append(ASCII.Code.colon)
            for (index, mailbox) in mailboxes.enumerated() {
                if index > 0 {
                    buffer.append(ASCII.Code.comma)
                    buffer.append(ASCII.Code.space)
                } else {
                    buffer.append(ASCII.Code.space)
                }
                RFC_2822.Mailbox.serialize(mailbox, into: &buffer)
            }
            buffer.append(ASCII.Code.semicolon)
        }
    }

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ address: RFC_2822.Address,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        switch address.kind {
        case .mailbox(let mailbox):
            RFC_2822.Mailbox.serialize(mailbox, into: &buffer)

        case .group(let displayName, let mailboxes):
            preconditionGroupDisplayNameInjectionSafe(displayName)
            for byte in displayName.utf8 { buffer.append(Byte(byte)) }
            buffer.append(ASCII.Code.colon.byte)
            for (index, mailbox) in mailboxes.enumerated() {
                if index > 0 {
                    buffer.append(ASCII.Code.comma.byte)
                    buffer.append(ASCII.Code.space.byte)
                } else {
                    buffer.append(ASCII.Code.space.byte)
                }
                RFC_2822.Mailbox.serialize(mailbox, into: &buffer)
            }
            buffer.append(ASCII.Code.semicolon.byte)
        }
    }
}

extension RFC_2822.Address: ASCII.Parseable {

    public init<Bytes: Swift.Collection>(ascii bytes: Bytes) throws(Error)
    where Bytes.Element == Byte {
        guard !bytes.isEmpty else { throw Error.empty }

        let codeArray: [ASCII.Code]
        do throws(ASCII.Code.Error) {
            codeArray = try bytes.map { byte throws(ASCII.Code.Error) in try ASCII.Code(byte) }
        } catch {
            throw Error.invalidGroup(String(decoding: bytes, as: UTF8.self))
        }

        var inAngleBracket = false
        var inQuote = false
        var colonIndex: Int?
        var semicolonIndex: Int?

        for (index, code) in codeArray.enumerated() {
            if code == ASCII.Code.quotationMark && !inAngleBracket {
                inQuote.toggle()
            } else if code == ASCII.Code.lessThanSign && !inQuote {
                inAngleBracket = true
            } else if code == ASCII.Code.greaterThanSign && !inQuote {
                inAngleBracket = false
            } else if code == ASCII.Code.colon && !inAngleBracket && !inQuote && colonIndex == nil {
                colonIndex = index
            } else if code == ASCII.Code.semicolon && colonIndex != nil && !inQuote {
                semicolonIndex = index
                break
            }
        }

        if let colonIdx = colonIndex {

            guard let semiIdx = semicolonIndex else {
                throw Error.missingGroupTerminator(String(decoding: bytes, as: UTF8.self))
            }

            var displayNameCodes: [ASCII.Code] = Array(codeArray[..<colonIdx])
            while !displayNameCodes.isEmpty
                && (displayNameCodes.first == ASCII.Code.space
                    || displayNameCodes.first == ASCII.Code.htab)
            {
                displayNameCodes.removeFirst()
            }
            while !displayNameCodes.isEmpty
                && (displayNameCodes.last == ASCII.Code.space
                    || displayNameCodes.last == ASCII.Code.htab)
            {
                displayNameCodes.removeLast()
            }

            var displayName: String

            if !displayNameCodes.isEmpty && displayNameCodes.first == ASCII.Code.quotationMark
                && displayNameCodes.last == ASCII.Code.quotationMark
            {
                displayName = String(
                    ascii: displayNameCodes.dropFirst().dropLast()
                )
            } else {
                displayName = String(ascii: displayNameCodes)
            }

            do throws(RFC_2822.Mailbox.Error) {
                try RFC_2822.Mailbox.validateDisplayName(displayName)
            } catch {
                throw Error.invalidDisplayName(displayName)
            }

            let mailboxListStart = codeArray.index(after: colonIdx)
            let mailboxListCodes = codeArray[mailboxListStart..<semiIdx]

            var mailboxes: [RFC_2822.Mailbox] = []

            if !mailboxListCodes.isEmpty {

                var currentMailbox: [ASCII.Code] = []
                var inQuote = false
                var inBracket = false

                for code in mailboxListCodes {
                    if code == ASCII.Code.quotationMark && !inBracket {
                        inQuote.toggle()
                        currentMailbox.append(code)
                    } else if code == ASCII.Code.lessThanSign && !inQuote {
                        inBracket = true
                        currentMailbox.append(code)
                    } else if code == ASCII.Code.greaterThanSign && !inQuote {
                        inBracket = false
                        currentMailbox.append(code)
                    } else if code == ASCII.Code.comma && !inQuote && !inBracket {

                        var trimmed = currentMailbox
                        while !trimmed.isEmpty
                            && (trimmed.first == ASCII.Code.space
                                || trimmed.first == ASCII.Code.htab)
                        {
                            trimmed.removeFirst()
                        }
                        while !trimmed.isEmpty
                            && (trimmed.last == ASCII.Code.space || trimmed.last == ASCII.Code.htab)
                        {
                            trimmed.removeLast()
                        }
                        if !trimmed.isEmpty {
                            do throws(RFC_2822.Mailbox.Error) {
                                let mailbox = try RFC_2822.Mailbox(ascii: trimmed.map(\.byte))
                                mailboxes.append(mailbox)
                            } catch {
                                throw Error.invalidMailbox(error)
                            }
                        }
                        currentMailbox = []
                    } else {
                        currentMailbox.append(code)
                    }
                }

                var trimmed = currentMailbox
                while !trimmed.isEmpty
                    && (trimmed.first == ASCII.Code.space || trimmed.first == ASCII.Code.htab)
                {
                    trimmed.removeFirst()
                }
                while !trimmed.isEmpty
                    && (trimmed.last == ASCII.Code.space || trimmed.last == ASCII.Code.htab)
                {
                    trimmed.removeLast()
                }
                if !trimmed.isEmpty {
                    do throws(RFC_2822.Mailbox.Error) {
                        let mailbox = try RFC_2822.Mailbox(ascii: trimmed.map(\.byte))
                        mailboxes.append(mailbox)
                    } catch {
                        throw Error.invalidMailbox(error)
                    }
                }
            }

            self.init(__unchecked: (), kind: .group(displayName, mailboxes))
        } else {

            do throws(RFC_2822.Mailbox.Error) {
                let mailbox = try RFC_2822.Mailbox(ascii: bytes)
                self.init(__unchecked: (), kind: .mailbox(mailbox))
            } catch {
                throw Error.invalidMailbox(error)
            }
        }
    }
}

extension RFC_2822.Address: Swift.RawRepresentable {

    public var rawValue: String { description }

    public init?(rawValue: String) {
        do throws(RFC_2822.Address.Error) {
            try self.init(ascii: rawValue.utf8.map { Byte($0) })
        } catch {
            return nil
        }
    }
}

extension RFC_2822.Address: CustomStringConvertible {

    public var description: String {
        switch kind {
        case .mailbox(let mailbox):
            return mailbox.description

        case .group(let displayName, let mailboxes):
            Self.preconditionGroupDisplayNameInjectionSafe(displayName)
            if mailboxes.isEmpty { return "\(displayName):;" }
            let members = mailboxes.map(\.description).joined(separator: ", ")
            return "\(displayName): \(members);"
        }
    }
}
