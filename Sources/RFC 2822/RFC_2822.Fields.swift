public import ASCII
public import Binary
import INCITS_4_1986

extension RFC_2822 {

    public struct Fields: Sendable, Codable {

        public let originationDate: RFC_2822.Timestamp
        public let from: [Mailbox]

        public let sender: Mailbox?
        public let replyTo: [Address]?

        public let to: [Address]?
        public let cc: [Address]?
        public let bcc: [Address]?

        public let messageID: Message.ID?
        public let inReplyTo: [Message.ID]?
        public let references: [Message.ID]?

        public let subject: String?
        public let comments: String?
        public let keywords: [String]?

        public let receivedFields: [Message.Received]
        public let returnPath: Message.Path?

        public let resentFields: [Message.ResentBlock]

        init(
            __unchecked: Void,
            originationDate: RFC_2822.Timestamp,
            from: [Mailbox],
            sender: Mailbox?,
            replyTo: [Address]?,
            to: [Address]?,
            cc: [Address]?,
            bcc: [Address]?,
            messageID: Message.ID?,
            inReplyTo: [Message.ID]?,
            references: [Message.ID]?,
            subject: String?,
            comments: String?,
            keywords: [String]?,
            receivedFields: [Message.Received],
            returnPath: Message.Path?,
            resentFields: [Message.ResentBlock]
        ) {
            self.originationDate = originationDate
            self.from = from
            self.sender = sender
            self.replyTo = replyTo
            self.to = to
            self.cc = cc
            self.bcc = bcc
            self.messageID = messageID
            self.inReplyTo = inReplyTo
            self.references = references
            self.subject = subject
            self.comments = comments
            self.keywords = keywords
            self.receivedFields = receivedFields
            self.returnPath = returnPath
            self.resentFields = resentFields
        }

        public init(
            originationDate: RFC_2822.Timestamp,
            from: [Mailbox],
            sender: Mailbox? = nil,
            replyTo: [Address]? = nil,
            to: [Address]? = nil,
            cc: [Address]? = nil,
            bcc: [Address]? = nil,
            messageID: Message.ID? = nil,
            inReplyTo: [Message.ID]? = nil,
            references: [Message.ID]? = nil,
            subject: String? = nil,
            comments: String? = nil,
            keywords: [String]? = nil,
            receivedFields: [Message.Received] = [],
            returnPath: Message.Path? = nil,
            resentFields: [Message.ResentBlock] = []
        ) {
            self.init(
                __unchecked: (),
                originationDate: originationDate,
                from: from,
                sender: sender,
                replyTo: replyTo,
                to: to,
                cc: cc,
                bcc: bcc,
                messageID: messageID,
                inReplyTo: inReplyTo,
                references: references,
                subject: subject,
                comments: comments,
                keywords: keywords,
                receivedFields: receivedFields,
                returnPath: returnPath,
                resentFields: resentFields
            )

            if from.count > 1 && sender == nil {

                assertionFailure("Sender field required when From contains multiple mailboxes")
            }
        }
    }
}

extension RFC_2822.Fields: Hashable {}

extension RFC_2822.Fields: ASCII.Serializable, Binary.Serializable {

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ fields: RFC_2822.Fields,
        into buffer: inout Buffer
    ) where Buffer.Element == ASCII.Code {
        func name(_ s: String) {
            for byte in s.utf8 { buffer.append(ASCII.Code(byte)) }
            buffer.append(ASCII.Code.colon)
            buffer.append(ASCII.Code.space)
        }
        func string(_ s: String) { for byte in s.utf8 { buffer.append(ASCII.Code(byte)) } }
        func crlf() {
            buffer.append(ASCII.Code.cr)
            buffer.append(ASCII.Code.lf)
        }
        func mailboxList(_ list: [RFC_2822.Mailbox]) {
            for (index, mailbox) in list.enumerated() {
                if index > 0 {
                    buffer.append(ASCII.Code.comma)
                    buffer.append(ASCII.Code.space)
                }
                RFC_2822.Mailbox.serialize(mailbox, into: &buffer)
            }
        }
        func addressList(_ list: [RFC_2822.Address]) {
            for (index, address) in list.enumerated() {
                if index > 0 {
                    buffer.append(ASCII.Code.comma)
                    buffer.append(ASCII.Code.space)
                }
                RFC_2822.Address.serialize(address, into: &buffer)
            }
        }
        func idList(_ list: [RFC_2822.Message.ID]) {
            for (index, id) in list.enumerated() {
                if index > 0 { buffer.append(ASCII.Code.space) }
                RFC_2822.Message.ID.serialize(id, into: &buffer)
            }
        }

        for received in fields.receivedFields {
            name("Received")
            RFC_2822.Message.Received.serialize(received, into: &buffer)
            crlf()
        }
        if let returnPath = fields.returnPath {
            name("Return-Path")
            RFC_2822.Message.Path.serialize(returnPath, into: &buffer)
            crlf()
        }
        for block in fields.resentFields {
            RFC_2822.Message.ResentBlock.serialize(block, into: &buffer)
        }
        name("Date")
        RFC_2822.Timestamp.serialize(fields.originationDate, into: &buffer)
        crlf()
        name("From")
        mailboxList(fields.from)
        crlf()
        if let sender = fields.sender {
            name("Sender")
            RFC_2822.Mailbox.serialize(sender, into: &buffer)
            crlf()
        }
        if let replyTo = fields.replyTo {
            name("Reply-To")
            addressList(replyTo)
            crlf()
        }
        if let to = fields.to {
            name("To")
            addressList(to)
            crlf()
        }
        if let cc = fields.cc {
            name("Cc")
            addressList(cc)
            crlf()
        }
        if let bcc = fields.bcc {
            name("Bcc")
            addressList(bcc)
            crlf()
        }
        if let messageID = fields.messageID {
            name("Message-ID")
            RFC_2822.Message.ID.serialize(messageID, into: &buffer)
            crlf()
        }
        if let inReplyTo = fields.inReplyTo {
            name("In-Reply-To")
            idList(inReplyTo)
            crlf()
        }
        if let references = fields.references {
            name("References")
            idList(references)
            crlf()
        }
        if let subject = fields.subject {
            name("Subject")
            string(subject)
            crlf()
        }
        if let comments = fields.comments {
            name("Comments")
            string(comments)
            crlf()
        }
        if let keywords = fields.keywords {
            name("Keywords")
            string(keywords.joined(separator: ", "))
            crlf()
        }
    }

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ fields: RFC_2822.Fields,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        func name(_ s: String) {
            for byte in s.utf8 { buffer.append(Byte(byte)) }
            buffer.append(ASCII.Code.colon.byte)
            buffer.append(ASCII.Code.space.byte)
        }
        func string(_ s: String) { for byte in s.utf8 { buffer.append(Byte(byte)) } }
        func crlf() {
            buffer.append(ASCII.Code.cr.byte)
            buffer.append(ASCII.Code.lf.byte)
        }
        func mailboxList(_ list: [RFC_2822.Mailbox]) {
            for (index, mailbox) in list.enumerated() {
                if index > 0 {
                    buffer.append(ASCII.Code.comma.byte)
                    buffer.append(ASCII.Code.space.byte)
                }
                RFC_2822.Mailbox.serialize(mailbox, into: &buffer)
            }
        }
        func addressList(_ list: [RFC_2822.Address]) {
            for (index, address) in list.enumerated() {
                if index > 0 {
                    buffer.append(ASCII.Code.comma.byte)
                    buffer.append(ASCII.Code.space.byte)
                }
                RFC_2822.Address.serialize(address, into: &buffer)
            }
        }
        func idList(_ list: [RFC_2822.Message.ID]) {
            for (index, id) in list.enumerated() {
                if index > 0 { buffer.append(ASCII.Code.space.byte) }
                RFC_2822.Message.ID.serialize(id, into: &buffer)
            }
        }

        for received in fields.receivedFields {
            name("Received")
            RFC_2822.Message.Received.serialize(received, into: &buffer)
            crlf()
        }
        if let returnPath = fields.returnPath {
            name("Return-Path")
            RFC_2822.Message.Path.serialize(returnPath, into: &buffer)
            crlf()
        }
        for block in fields.resentFields {
            RFC_2822.Message.ResentBlock.serialize(block, into: &buffer)
        }
        name("Date")
        RFC_2822.Timestamp.serialize(fields.originationDate, into: &buffer)
        crlf()
        name("From")
        mailboxList(fields.from)
        crlf()
        if let sender = fields.sender {
            name("Sender")
            RFC_2822.Mailbox.serialize(sender, into: &buffer)
            crlf()
        }
        if let replyTo = fields.replyTo {
            name("Reply-To")
            addressList(replyTo)
            crlf()
        }
        if let to = fields.to {
            name("To")
            addressList(to)
            crlf()
        }
        if let cc = fields.cc {
            name("Cc")
            addressList(cc)
            crlf()
        }
        if let bcc = fields.bcc {
            name("Bcc")
            addressList(bcc)
            crlf()
        }
        if let messageID = fields.messageID {
            name("Message-ID")
            RFC_2822.Message.ID.serialize(messageID, into: &buffer)
            crlf()
        }
        if let inReplyTo = fields.inReplyTo {
            name("In-Reply-To")
            idList(inReplyTo)
            crlf()
        }
        if let references = fields.references {
            name("References")
            idList(references)
            crlf()
        }
        if let subject = fields.subject {
            name("Subject")
            string(subject)
            crlf()
        }
        if let comments = fields.comments {
            name("Comments")
            string(comments)
            crlf()
        }
        if let keywords = fields.keywords {
            name("Keywords")
            string(keywords.joined(separator: ", "))
            crlf()
        }
    }
}

extension RFC_2822.Fields: ASCII.Parseable {

    public init<Bytes: Swift.Collection>(ascii bytes: Bytes) throws(Error)
    where Bytes.Element == Byte {
        guard !bytes.isEmpty else { throw Error.empty }

        let codeArray: [ASCII.Code]
        do throws(ASCII.Code.Error) {
            codeArray = try bytes.map { byte throws(ASCII.Code.Error) in try ASCII.Code(byte) }
        } catch {
            throw Error.invalidFieldFormat("", String(decoding: bytes, as: UTF8.self))
        }

        func trimWhitespace(_ input: [ASCII.Code]) -> [ASCII.Code] {
            var result = input
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

        func codesEqualCaseInsensitive(_ codes: [ASCII.Code], _ string: String) -> Bool {
            let stringCodes: [ASCII.Code]
            do throws(ASCII.Code.Error) {
                stringCodes = try [Byte](utf8: string).map { byte throws(ASCII.Code.Error) in try ASCII.Code(byte) }
            } catch {

                return false
            }
            guard codes.count == stringCodes.count else { return false }
            return zip(codes, stringCodes).allSatisfy { $0.lowercased() == $1.lowercased() }
        }

        func splitCodes(_ codes: [ASCII.Code], separator: ASCII.Code) -> [[ASCII.Code]] {
            var result: [[ASCII.Code]] = []
            var current: [ASCII.Code] = []
            var inQuote = false
            var inBracket = false
            for code in codes {
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
                    result.append(current)
                    current = []
                } else {
                    current.append(code)
                }
            }
            result.append(current)
            return result
        }

        var headers: [(nameCodes: [ASCII.Code], valueCodes: [ASCII.Code])] = []
        var currentLine: [ASCII.Code] = []

        var i = 0
        while i < codeArray.count {
            let code = codeArray[i]

            if code == ASCII.Code.cr && i + 1 < codeArray.count && codeArray[i + 1] == ASCII.Code.lf
            {

                i += 2

                if i < codeArray.count
                    && (codeArray[i] == ASCII.Code.space || codeArray[i] == ASCII.Code.htab)
                {

                    currentLine.append(ASCII.Code.space)
                    i += 1
                } else {

                    if !currentLine.isEmpty {
                        if let colonIdx = currentLine.firstIndex(of: ASCII.Code.colon) {
                            let nameCodes = trimWhitespace(Array(currentLine[..<colonIdx]))
                            let valueCodes = trimWhitespace(Array(currentLine[(colonIdx + 1)...]))
                            headers.append((nameCodes: nameCodes, valueCodes: valueCodes))
                        }
                    }
                    currentLine = []
                }
            } else if code == ASCII.Code.lf {

                i += 1

                if i < codeArray.count
                    && (codeArray[i] == ASCII.Code.space || codeArray[i] == ASCII.Code.htab)
                {
                    currentLine.append(ASCII.Code.space)
                    i += 1
                } else {
                    if !currentLine.isEmpty {
                        if let colonIdx = currentLine.firstIndex(of: ASCII.Code.colon) {
                            let nameCodes = trimWhitespace(Array(currentLine[..<colonIdx]))
                            let valueCodes = trimWhitespace(Array(currentLine[(colonIdx + 1)...]))
                            headers.append((nameCodes: nameCodes, valueCodes: valueCodes))
                        }
                    }
                    currentLine = []
                }
            } else {
                currentLine.append(code)
                i += 1
            }
        }

        if !currentLine.isEmpty {
            if let colonIdx = currentLine.firstIndex(of: ASCII.Code.colon) {
                let nameCodes = trimWhitespace(Array(currentLine[..<colonIdx]))
                let valueCodes = trimWhitespace(Array(currentLine[(colonIdx + 1)...]))
                headers.append((nameCodes: nameCodes, valueCodes: valueCodes))
            }
        }

        var date: RFC_2822.Timestamp?
        var from: [RFC_2822.Mailbox] = []
        var sender: RFC_2822.Mailbox?
        var replyTo: [RFC_2822.Address]?
        var to: [RFC_2822.Address]?
        var cc: [RFC_2822.Address]?
        var bcc: [RFC_2822.Address]?
        var messageID: RFC_2822.Message.ID?
        var inReplyTo: [RFC_2822.Message.ID]?
        var references: [RFC_2822.Message.ID]?
        var subject: String?
        var comments: String?
        var keywords: [String]?

        for (nameCodes, valueCodes) in headers {
            let valueBytes = valueCodes.map(\.byte)
            if codesEqualCaseInsensitive(nameCodes, "date") {
                do throws(RFC_2822.Timestamp.Error) {
                    date = try RFC_2822.Timestamp(ascii: valueBytes)
                } catch {
                    throw Error.invalidFieldFormat(
                        "Date",
                        String(ascii: valueCodes)
                    )
                }
            } else if codesEqualCaseInsensitive(nameCodes, "from") {

                let parts = splitCodes(valueCodes, separator: ASCII.Code.comma)
                for part in parts {
                    let trimmed = trimWhitespace(part)
                    if !trimmed.isEmpty {
                        do throws(RFC_2822.Mailbox.Error) {
                            let mailbox = try RFC_2822.Mailbox(ascii: trimmed.map(\.byte))
                            from.append(mailbox)
                        } catch {
                            throw Error.invalidMailbox(error)
                        }
                    }
                }
            } else if codesEqualCaseInsensitive(nameCodes, "sender") {
                do throws(RFC_2822.Mailbox.Error) {
                    sender = try RFC_2822.Mailbox(ascii: valueBytes)
                } catch {
                    throw Error.invalidMailbox(error)
                }
            } else if codesEqualCaseInsensitive(nameCodes, "reply-to") {
                var addresses: [RFC_2822.Address] = []
                let parts = splitCodes(valueCodes, separator: ASCII.Code.comma)
                for part in parts {
                    let trimmed = trimWhitespace(part)
                    if !trimmed.isEmpty {
                        do throws(RFC_2822.Address.Error) {
                            let address = try RFC_2822.Address(ascii: trimmed.map(\.byte))
                            addresses.append(address)
                        } catch {
                            throw Error.invalidAddress(error)
                        }
                    }
                }
                replyTo = addresses.isEmpty ? nil : addresses
            } else if codesEqualCaseInsensitive(nameCodes, "to") {
                var addresses: [RFC_2822.Address] = []
                let parts = splitCodes(valueCodes, separator: ASCII.Code.comma)
                for part in parts {
                    let trimmed = trimWhitespace(part)
                    if !trimmed.isEmpty {
                        do throws(RFC_2822.Address.Error) {
                            let address = try RFC_2822.Address(ascii: trimmed.map(\.byte))
                            addresses.append(address)
                        } catch {
                            throw Error.invalidAddress(error)
                        }
                    }
                }
                to = addresses.isEmpty ? nil : addresses
            } else if codesEqualCaseInsensitive(nameCodes, "cc") {
                var addresses: [RFC_2822.Address] = []
                let parts = splitCodes(valueCodes, separator: ASCII.Code.comma)
                for part in parts {
                    let trimmed = trimWhitespace(part)
                    if !trimmed.isEmpty {
                        do throws(RFC_2822.Address.Error) {
                            let address = try RFC_2822.Address(ascii: trimmed.map(\.byte))
                            addresses.append(address)
                        } catch {
                            throw Error.invalidAddress(error)
                        }
                    }
                }
                cc = addresses.isEmpty ? nil : addresses
            } else if codesEqualCaseInsensitive(nameCodes, "bcc") {
                var addresses: [RFC_2822.Address] = []
                let parts = splitCodes(valueCodes, separator: ASCII.Code.comma)
                for part in parts {
                    let trimmed = trimWhitespace(part)
                    if !trimmed.isEmpty {
                        do throws(RFC_2822.Address.Error) {
                            let address = try RFC_2822.Address(ascii: trimmed.map(\.byte))
                            addresses.append(address)
                        } catch {
                            throw Error.invalidAddress(error)
                        }
                    }
                }
                bcc = addresses.isEmpty ? nil : addresses
            } else if codesEqualCaseInsensitive(nameCodes, "message-id") {
                do throws(RFC_2822.Message.ID.Error) {
                    messageID = try RFC_2822.Message.ID(ascii: valueBytes)
                } catch {
                    throw Error.invalidMessageID(error)
                }
            } else if codesEqualCaseInsensitive(nameCodes, "in-reply-to") {
                var ids: [RFC_2822.Message.ID] = []

                let parts = splitCodes(valueCodes, separator: ASCII.Code.space)
                for part in parts {
                    let trimmed = trimWhitespace(part)
                    if !trimmed.isEmpty && trimmed.first == ASCII.Code.lessThanSign {
                        do throws(RFC_2822.Message.ID.Error) {
                            let id = try RFC_2822.Message.ID(ascii: trimmed.map(\.byte))
                            ids.append(id)
                        } catch {
                            throw Error.invalidMessageID(error)
                        }
                    }
                }
                inReplyTo = ids.isEmpty ? nil : ids
            } else if codesEqualCaseInsensitive(nameCodes, "references") {
                var ids: [RFC_2822.Message.ID] = []
                let parts = splitCodes(valueCodes, separator: ASCII.Code.space)
                for part in parts {
                    let trimmed = trimWhitespace(part)
                    if !trimmed.isEmpty && trimmed.first == ASCII.Code.lessThanSign {
                        do throws(RFC_2822.Message.ID.Error) {
                            let id = try RFC_2822.Message.ID(ascii: trimmed.map(\.byte))
                            ids.append(id)
                        } catch {
                            throw Error.invalidMessageID(error)
                        }
                    }
                }
                references = ids.isEmpty ? nil : ids
            } else if codesEqualCaseInsensitive(nameCodes, "subject") {
                subject = String(ascii: valueCodes)
            } else if codesEqualCaseInsensitive(nameCodes, "comments") {
                comments = String(ascii: valueCodes)
            } else if codesEqualCaseInsensitive(nameCodes, "keywords") {
                let parts = splitCodes(valueCodes, separator: ASCII.Code.comma)
                keywords = parts.map { String(ascii: trimWhitespace($0)) }
            }

        }

        guard let originationDate = date else {
            throw Error.missingRequiredField("Date")
        }
        guard !from.isEmpty else {
            throw Error.missingRequiredField("From")
        }

        self.init(
            __unchecked: (),
            originationDate: originationDate,
            from: from,
            sender: sender,
            replyTo: replyTo,
            to: to,
            cc: cc,
            bcc: bcc,
            messageID: messageID,
            inReplyTo: inReplyTo,
            references: references,
            subject: subject,
            comments: comments,
            keywords: keywords,
            receivedFields: [],
            returnPath: nil,
            resentFields: []
        )
    }
}

extension RFC_2822.Fields: Swift.RawRepresentable {

    public var rawValue: String { description }

    public init?(rawValue: String) {
        do throws(RFC_2822.Fields.Error) {
            try self.init(ascii: rawValue.utf8.map { Byte($0) })
        } catch {
            return nil
        }
    }
}

extension RFC_2822.Fields: CustomStringConvertible {

    public var description: String {
        var out: [Byte] = []
        RFC_2822.Fields.serialize(self, into: &out)
        return String(decoding: out, as: UTF8.self)
    }
}
