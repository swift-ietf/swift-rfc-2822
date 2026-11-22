public import ASCII
public import Binary
import INCITS_4_1986

extension IETF.RFC.`2822`.Message {

    public struct ResentBlock: Hashable, Sendable {
        public let timestamp: IETF.RFC.`2822`.Timestamp
        public let from: [IETF.RFC.`2822`.Mailbox]
        public let sender: IETF.RFC.`2822`.Mailbox?
        public let to: [IETF.RFC.`2822`.Address]?
        public let cc: [IETF.RFC.`2822`.Address]?
        public let bcc: [IETF.RFC.`2822`.Address]?
        public let messageID: ID?

        init(
            __unchecked: Void,
            timestamp: IETF.RFC.`2822`.Timestamp,
            from: [IETF.RFC.`2822`.Mailbox],
            sender: IETF.RFC.`2822`.Mailbox?,
            to: [IETF.RFC.`2822`.Address]?,
            cc: [IETF.RFC.`2822`.Address]?,
            bcc: [IETF.RFC.`2822`.Address]?,
            messageID: ID?
        ) {
            self.timestamp = timestamp
            self.from = from
            self.sender = sender
            self.to = to
            self.cc = cc
            self.bcc = bcc
            self.messageID = messageID
        }

        public init(
            timestamp: IETF.RFC.`2822`.Timestamp,
            from: [IETF.RFC.`2822`.Mailbox],
            sender: IETF.RFC.`2822`.Mailbox? = nil,
            to: [IETF.RFC.`2822`.Address]? = nil,
            cc: [IETF.RFC.`2822`.Address]? = nil,
            bcc: [IETF.RFC.`2822`.Address]? = nil,
            messageID: ID? = nil
        ) {
            self.init(
                __unchecked: (),
                timestamp: timestamp,
                from: from,
                sender: sender,
                to: to,
                cc: cc,
                bcc: bcc,
                messageID: messageID
            )
        }
    }
}

extension IETF.RFC.`2822`.Message.ResentBlock: ASCII.Serializable, Binary.Serializable {

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ block: IETF.RFC.`2822`.Message.ResentBlock,
        into buffer: inout Buffer
    ) where Buffer.Element == ASCII.Code {
        func name(_ s: String) {
            for byte in s.utf8 { buffer.append(ASCII.Code(byte)) }
            buffer.append(ASCII.Code.colon)
            buffer.append(ASCII.Code.space)
        }
        func crlf() {
            buffer.append(ASCII.Code.cr)
            buffer.append(ASCII.Code.lf)
        }
        func mailboxes(_ list: [IETF.RFC.`2822`.Mailbox]) {
            for (index, mailbox) in list.enumerated() {
                if index > 0 {
                    buffer.append(ASCII.Code.comma)
                    buffer.append(ASCII.Code.space)
                }
                IETF.RFC.`2822`.Mailbox.serialize(mailbox, into: &buffer)
            }
        }
        func addresses(_ list: [IETF.RFC.`2822`.Address]) {
            for (index, address) in list.enumerated() {
                if index > 0 {
                    buffer.append(ASCII.Code.comma)
                    buffer.append(ASCII.Code.space)
                }
                IETF.RFC.`2822`.Address.serialize(address, into: &buffer)
            }
        }

        name("Resent-Date")
        IETF.RFC.`2822`.Timestamp.serialize(block.timestamp, into: &buffer)
        crlf()
        name("Resent-From")
        mailboxes(block.from)
        crlf()
        if let sender = block.sender {
            name("Resent-Sender")
            IETF.RFC.`2822`.Mailbox.serialize(sender, into: &buffer)
            crlf()
        }
        if let to = block.to {
            name("Resent-To")
            addresses(to)
            crlf()
        }
        if let cc = block.cc {
            name("Resent-Cc")
            addresses(cc)
            crlf()
        }
        if let bcc = block.bcc {
            name("Resent-Bcc")
            addresses(bcc)
            crlf()
        }
        if let messageID = block.messageID {
            name("Resent-Message-ID")
            IETF.RFC.`2822`.Message.ID.serialize(messageID, into: &buffer)
            crlf()
        }
    }

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ block: IETF.RFC.`2822`.Message.ResentBlock,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        func name(_ s: String) {
            for byte in s.utf8 { buffer.append(Byte(byte)) }
            buffer.append(ASCII.Code.colon.byte)
            buffer.append(ASCII.Code.space.byte)
        }
        func crlf() {
            buffer.append(ASCII.Code.cr.byte)
            buffer.append(ASCII.Code.lf.byte)
        }
        func mailboxes(_ list: [IETF.RFC.`2822`.Mailbox]) {
            for (index, mailbox) in list.enumerated() {
                if index > 0 {
                    buffer.append(ASCII.Code.comma.byte)
                    buffer.append(ASCII.Code.space.byte)
                }
                IETF.RFC.`2822`.Mailbox.serialize(mailbox, into: &buffer)
            }
        }
        func addresses(_ list: [IETF.RFC.`2822`.Address]) {
            for (index, address) in list.enumerated() {
                if index > 0 {
                    buffer.append(ASCII.Code.comma.byte)
                    buffer.append(ASCII.Code.space.byte)
                }
                IETF.RFC.`2822`.Address.serialize(address, into: &buffer)
            }
        }

        name("Resent-Date")
        IETF.RFC.`2822`.Timestamp.serialize(block.timestamp, into: &buffer)
        crlf()
        name("Resent-From")
        mailboxes(block.from)
        crlf()
        if let sender = block.sender {
            name("Resent-Sender")
            IETF.RFC.`2822`.Mailbox.serialize(sender, into: &buffer)
            crlf()
        }
        if let to = block.to {
            name("Resent-To")
            addresses(to)
            crlf()
        }
        if let cc = block.cc {
            name("Resent-Cc")
            addresses(cc)
            crlf()
        }
        if let bcc = block.bcc {
            name("Resent-Bcc")
            addresses(bcc)
            crlf()
        }
        if let messageID = block.messageID {
            name("Resent-Message-ID")
            IETF.RFC.`2822`.Message.ID.serialize(messageID, into: &buffer)
            crlf()
        }
    }
}

extension IETF.RFC.`2822`.Message.ResentBlock: ASCII.Parseable {

    public init<Bytes: Swift::Collection>(ascii bytes: Bytes) throws(Error)
    where Bytes.Element == Byte {
        guard !bytes.isEmpty else { throw Error.empty }

        let codeArray: [ASCII.Code]
        do throws(ASCII.Code.Error) {
            codeArray = try bytes.map { byte throws(ASCII.Code.Error) in try ASCII.Code(byte) }
        } catch {
            throw Error.missingResentDate(String(decoding: bytes, as: UTF8.self))
        }

        func trimWhitespace(_ arr: [ASCII.Code]) -> [ASCII.Code] {
            var result = arr
            while !result.isEmpty
                && (result.first == ASCII.Code.space || result.first == ASCII.Code.htab)
            {
                result.removeFirst()
            }
            while !result.isEmpty
                && (result.last == ASCII.Code.space || result.last == ASCII.Code.htab)
            {
                result.removeLast()
            }
            return result
        }

        func splitCodes(_ arr: [ASCII.Code], on separator: ASCII.Code) -> [[ASCII.Code]] {
            var result: [[ASCII.Code]] = []
            var current: [ASCII.Code] = []
            var inQuote = false
            var inBracket = false
            for code in arr {
                if code == ASCII.Code.quotationMark && !inBracket {
                    inQuote.toggle()
                    current.append(code)
                } else if code == ASCII.Code.lessThanSign && !inQuote {
                    inBracket = true
                    current.append(code)
                } else if code == ASCII.Code.greaterThanSign && !inQuote {
                    inBracket = false
                    current.append(code)
                } else if code == separator && !inQuote && !inBracket {
                    if !current.isEmpty {
                        result.append(current)
                    }
                    current = []
                } else {
                    current.append(code)
                }
            }
            if !current.isEmpty {
                result.append(current)
            }
            return result
        }

        var lines: [[ASCII.Code]] = []
        var currentLine: [ASCII.Code] = []
        for code in codeArray {
            if code == ASCII.Code.cr || code == ASCII.Code.lf {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                    currentLine = []
                }
            } else {
                currentLine.append(code)
            }
        }
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        var timestamp: IETF.RFC.`2822`.Timestamp?
        var from: [IETF.RFC.`2822`.Mailbox] = []
        var sender: IETF.RFC.`2822`.Mailbox?
        var to: [IETF.RFC.`2822`.Address]?
        var cc: [IETF.RFC.`2822`.Address]?
        var bcc: [IETF.RFC.`2822`.Address]?
        var messageID: IETF.RFC.`2822`.Message.ID?

        for line in lines {

            guard let colonIndex = line.firstIndex(of: ASCII.Code.colon) else { continue }

            let fieldNameCodes = trimWhitespace(Array(line[..<colonIndex]))
            let fieldValueCodes = trimWhitespace(Array(line[(colonIndex + 1)...]))

            let fieldName = String(ascii: fieldNameCodes).lowercased()
            let fieldValueBytes = fieldValueCodes.map({ $0.byte })

            switch fieldName {
            case "resent-date":
                do throws(IETF.RFC.`2822`.Timestamp.Error) {
                    timestamp = try IETF.RFC.`2822`.Timestamp(ascii: fieldValueBytes)
                } catch {
                    throw Error.invalidTimestamp(error)
                }

            case "resent-from":

                let mailboxCodeArrays = splitCodes(fieldValueCodes, on: ASCII.Code.comma)
                for mailboxCodes in mailboxCodeArrays {
                    let trimmed = trimWhitespace(mailboxCodes)
                    guard !trimmed.isEmpty else { continue }
                    do throws(IETF.RFC.`2822`.Mailbox.Error) {
                        from.append(try IETF.RFC.`2822`.Mailbox(ascii: trimmed.map({ $0.byte })))
                    } catch {
                        throw Error.invalidMailbox(error)
                    }
                }

            case "resent-sender":
                do throws(IETF.RFC.`2822`.Mailbox.Error) {
                    sender = try IETF.RFC.`2822`.Mailbox(ascii: fieldValueBytes)
                } catch {
                    throw Error.invalidMailbox(error)
                }

            case "resent-to":
                var addresses: [IETF.RFC.`2822`.Address] = []
                let addressCodeArrays = splitCodes(fieldValueCodes, on: ASCII.Code.comma)
                for addressCodes in addressCodeArrays {
                    let trimmed = trimWhitespace(addressCodes)
                    guard !trimmed.isEmpty else { continue }
                    do throws(IETF.RFC.`2822`.Address.Error) {
                        addresses.append(try IETF.RFC.`2822`.Address(ascii: trimmed.map({ $0.byte })))
                    } catch {
                        throw Error.invalidAddress("Resent-To", value: String(ascii: trimmed))
                    }
                }
                to = addresses.isEmpty ? nil : addresses

            case "resent-cc":
                var addresses: [IETF.RFC.`2822`.Address] = []
                let addressCodeArrays = splitCodes(fieldValueCodes, on: ASCII.Code.comma)
                for addressCodes in addressCodeArrays {
                    let trimmed = trimWhitespace(addressCodes)
                    guard !trimmed.isEmpty else { continue }
                    do throws(IETF.RFC.`2822`.Address.Error) {
                        addresses.append(try IETF.RFC.`2822`.Address(ascii: trimmed.map({ $0.byte })))
                    } catch {
                        throw Error.invalidAddress("Resent-Cc", value: String(ascii: trimmed))
                    }
                }
                cc = addresses.isEmpty ? nil : addresses

            case "resent-bcc":
                var addresses: [IETF.RFC.`2822`.Address] = []
                let addressCodeArrays = splitCodes(fieldValueCodes, on: ASCII.Code.comma)
                for addressCodes in addressCodeArrays {
                    let trimmed = trimWhitespace(addressCodes)
                    guard !trimmed.isEmpty else { continue }
                    do throws(IETF.RFC.`2822`.Address.Error) {
                        addresses.append(try IETF.RFC.`2822`.Address(ascii: trimmed.map({ $0.byte })))
                    } catch {
                        throw Error.invalidAddress("Resent-Bcc", value: String(ascii: trimmed))
                    }
                }
                bcc = addresses.isEmpty ? nil : addresses

            case "resent-message-id":
                do throws(IETF.RFC.`2822`.Message.ID.Error) {
                    messageID = try IETF.RFC.`2822`.Message.ID(ascii: fieldValueBytes)
                } catch {
                    throw Error.invalidMessageID(error)
                }

            default:
                break
            }
        }

        guard let ts = timestamp else {
            throw Error.missingResentDate(String(ascii: codeArray))
        }

        guard !from.isEmpty else {
            throw Error.missingResentFrom(String(ascii: codeArray))
        }

        self.init(
            __unchecked: (),
            timestamp: ts,
            from: from,
            sender: sender,
            to: to,
            cc: cc,
            bcc: bcc,
            messageID: messageID
        )
    }
}

extension IETF.RFC.`2822`.Message.ResentBlock: Swift::RawRepresentable {

    public var rawValue: String { description }

    public init?(rawValue: String) {
        do throws(IETF.RFC.`2822`.Message.ResentBlock.Error) {
            try self.init(ascii: rawValue.utf8.map { Byte($0) })
        } catch {
            return nil
        }
    }
}

extension IETF.RFC.`2822`.Message.ResentBlock: CustomStringConvertible {

    public var description: String {
        var lines: [String] = []
        lines.append("Resent-Date: \(timestamp)")
        lines.append("Resent-From: \(from.map({ $0.description }).joined(separator: ", "))")
        if let sender { lines.append("Resent-Sender: \(sender)") }
        if let to { lines.append("Resent-To: \(to.map({ $0.description }).joined(separator: ", "))") }
        if let cc { lines.append("Resent-Cc: \(cc.map({ $0.description }).joined(separator: ", "))") }
        if let bcc { lines.append("Resent-Bcc: \(bcc.map({ $0.description }).joined(separator: ", "))") }
        if let messageID { lines.append("Resent-Message-ID: \(messageID)") }
        return lines.map { "\($0)\r\n" }.joined()
    }
}

#if !hasFeature(Embedded)
    extension IETF.RFC.`2822`.Message.ResentBlock: Codable {}
#endif
