public import ASCII
public import Binary
import INCITS_4_1986

extension IETF.RFC.`2822` {

    public struct Fields: Sendable {

        public let originationDate: IETF.RFC.`2822`.Timestamp
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
            originationDate: IETF.RFC.`2822`.Timestamp,
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
            originationDate: IETF.RFC.`2822`.Timestamp,
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
        ) throws(Error) {
            guard !from.isEmpty else { throw Error.missingRequiredField("From") }
            if from.count > 1 && sender == nil { throw Error.missingRequiredField("Sender") }
            if let subject { try Self.validateUnstructured(subject, field: "Subject") }
            if let comments { try Self.validateUnstructured(comments, field: "Comments") }
            for keyword in keywords ?? [] {
                try Self.validateUnstructured(keyword, field: "Keywords")
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
                receivedFields: receivedFields,
                returnPath: returnPath,
                resentFields: resentFields
            )
        }
    }
}

extension IETF.RFC.`2822`.Fields {

    static func validateUnstructured(_ value: String, field: String) throws(Error) {
        for byte in value.utf8 {
            guard byte < 0x80, byte != 0x7F, byte >= 0x20 || byte == 0x09 else {
                throw Error.invalidFieldFormat(field, value)
            }
        }
    }
}

extension IETF.RFC.`2822`.Fields: ASCII.Serializable, Binary.Serializable {

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ fields: IETF.RFC.`2822`.Fields,
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
        func mailboxList(_ list: [IETF.RFC.`2822`.Mailbox]) {
            for (index, mailbox) in list.enumerated() {
                if index > 0 {
                    buffer.append(ASCII.Code.comma)
                    buffer.append(ASCII.Code.space)
                }
                IETF.RFC.`2822`.Mailbox.serialize(mailbox, into: &buffer)
            }
        }
        func addressList(_ list: [IETF.RFC.`2822`.Address]) {
            for (index, address) in list.enumerated() {
                if index > 0 {
                    buffer.append(ASCII.Code.comma)
                    buffer.append(ASCII.Code.space)
                }
                IETF.RFC.`2822`.Address.serialize(address, into: &buffer)
            }
        }
        func idList(_ list: [IETF.RFC.`2822`.Message.ID]) {
            for (index, id) in list.enumerated() {
                if index > 0 { buffer.append(ASCII.Code.space) }
                IETF.RFC.`2822`.Message.ID.serialize(id, into: &buffer)
            }
        }

        if let returnPath = fields.returnPath {
            name("Return-Path")
            IETF.RFC.`2822`.Message.Path.serialize(returnPath, into: &buffer)
            crlf()
        }
        for received in fields.receivedFields {
            name("Received")
            IETF.RFC.`2822`.Message.Received.serialize(received, into: &buffer)
            crlf()
        }
        for block in fields.resentFields {
            IETF.RFC.`2822`.Message.ResentBlock.serialize(block, into: &buffer)
        }
        name("Date")
        IETF.RFC.`2822`.Timestamp.serialize(fields.originationDate, into: &buffer)
        crlf()
        name("From")
        mailboxList(fields.from)
        crlf()
        if let sender = fields.sender {
            name("Sender")
            IETF.RFC.`2822`.Mailbox.serialize(sender, into: &buffer)
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
            IETF.RFC.`2822`.Message.ID.serialize(messageID, into: &buffer)
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
        _ fields: IETF.RFC.`2822`.Fields,
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
        func mailboxList(_ list: [IETF.RFC.`2822`.Mailbox]) {
            for (index, mailbox) in list.enumerated() {
                if index > 0 {
                    buffer.append(ASCII.Code.comma.byte)
                    buffer.append(ASCII.Code.space.byte)
                }
                IETF.RFC.`2822`.Mailbox.serialize(mailbox, into: &buffer)
            }
        }
        func addressList(_ list: [IETF.RFC.`2822`.Address]) {
            for (index, address) in list.enumerated() {
                if index > 0 {
                    buffer.append(ASCII.Code.comma.byte)
                    buffer.append(ASCII.Code.space.byte)
                }
                IETF.RFC.`2822`.Address.serialize(address, into: &buffer)
            }
        }
        func idList(_ list: [IETF.RFC.`2822`.Message.ID]) {
            for (index, id) in list.enumerated() {
                if index > 0 { buffer.append(ASCII.Code.space.byte) }
                IETF.RFC.`2822`.Message.ID.serialize(id, into: &buffer)
            }
        }

        if let returnPath = fields.returnPath {
            name("Return-Path")
            IETF.RFC.`2822`.Message.Path.serialize(returnPath, into: &buffer)
            crlf()
        }
        for received in fields.receivedFields {
            name("Received")
            IETF.RFC.`2822`.Message.Received.serialize(received, into: &buffer)
            crlf()
        }
        for block in fields.resentFields {
            IETF.RFC.`2822`.Message.ResentBlock.serialize(block, into: &buffer)
        }
        name("Date")
        IETF.RFC.`2822`.Timestamp.serialize(fields.originationDate, into: &buffer)
        crlf()
        name("From")
        mailboxList(fields.from)
        crlf()
        if let sender = fields.sender {
            name("Sender")
            IETF.RFC.`2822`.Mailbox.serialize(sender, into: &buffer)
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
            IETF.RFC.`2822`.Message.ID.serialize(messageID, into: &buffer)
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

extension IETF.RFC.`2822`.Fields: ASCII.Parseable {

    public init<Bytes: Swift::Collection>(ascii bytes: Bytes) throws(Error)
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

            if code == ASCII.Code.cr && i + 1 < codeArray.count && codeArray[i + 1] == ASCII.Code.lf {

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

        var date: IETF.RFC.`2822`.Timestamp?
        var from: [IETF.RFC.`2822`.Mailbox] = []
        var sender: IETF.RFC.`2822`.Mailbox?
        var replyTo: [IETF.RFC.`2822`.Address]?
        var to: [IETF.RFC.`2822`.Address]?
        var cc: [IETF.RFC.`2822`.Address]?
        var bcc: [IETF.RFC.`2822`.Address]?
        var messageID: IETF.RFC.`2822`.Message.ID?
        var inReplyTo: [IETF.RFC.`2822`.Message.ID]?
        var references: [IETF.RFC.`2822`.Message.ID]?
        var subject: String?
        var comments: String?
        var keywords: [String]?
        var receivedFields: [IETF.RFC.`2822`.Message.Received] = []
        var returnPath: IETF.RFC.`2822`.Message.Path?
        var resentFields: [IETF.RFC.`2822`.Message.ResentBlock] = []

        let resentFieldNames: [String: String] = [
            "resent-date": "Resent-Date",
            "resent-from": "Resent-From",
            "resent-sender": "Resent-Sender",
            "resent-to": "Resent-To",
            "resent-cc": "Resent-Cc",
            "resent-bcc": "Resent-Bcc",
            "resent-message-id": "Resent-Message-ID",
        ]
        let originationFieldNames: Set<String> = [
            "date", "from", "sender", "reply-to", "to", "cc", "bcc",
            "message-id", "in-reply-to", "references", "subject", "comments", "keywords",
        ]

        var resentLines: [ASCII.Code] = []
        var resentNamesInBlock: Set<String> = []
        var awaitingReceived = false
        var inOrigination = false

        func closeResentBlock() throws(Error) {
            guard !resentLines.isEmpty else { return }
            do throws(IETF.RFC.`2822`.Message.ResentBlock.Error) {
                resentFields.append(try IETF.RFC.`2822`.Message.ResentBlock(ascii: resentLines.map({ $0.byte })))
            } catch {
                throw Error.invalidResentBlock(error)
            }
            resentLines = []
            resentNamesInBlock = []
        }

        for (nameCodes, valueCodes) in headers {
            let valueBytes = valueCodes.map({ $0.byte })
            let fieldName = String(ascii: nameCodes).lowercased()

            if awaitingReceived && fieldName != "received"
                && (fieldName == "return-path" || resentFieldNames[fieldName] != nil
                    || originationFieldNames.contains(fieldName))
            {
                throw Error.misplacedField("Return-Path")
            }

            if fieldName == "return-path" {
                guard !inOrigination && returnPath == nil else {
                    throw Error.misplacedField("Return-Path")
                }
                try closeResentBlock()
                do throws(IETF.RFC.`2822`.Message.Path.Error) {
                    returnPath = try IETF.RFC.`2822`.Message.Path(ascii: valueBytes)
                } catch {
                    throw Error.invalidReturnPath(error)
                }
                awaitingReceived = true
                continue
            }

            if fieldName == "received" {
                guard !inOrigination else { throw Error.misplacedField("Received") }
                try closeResentBlock()
                do throws(IETF.RFC.`2822`.Message.Received.Error) {
                    receivedFields.append(try IETF.RFC.`2822`.Message.Received(ascii: valueBytes))
                } catch {
                    throw Error.invalidReceived(error)
                }
                awaitingReceived = false
                continue
            }

            if let resentFieldName = resentFieldNames[fieldName] {
                guard !inOrigination else { throw Error.misplacedField(resentFieldName) }
                if resentNamesInBlock.contains(fieldName) { try closeResentBlock() }
                resentNamesInBlock.insert(fieldName)
                resentLines.append(contentsOf: nameCodes)
                resentLines.append(ASCII.Code.colon)
                resentLines.append(ASCII.Code.space)
                resentLines.append(contentsOf: valueCodes)
                resentLines.append(ASCII.Code.cr)
                resentLines.append(ASCII.Code.lf)
                continue
            }

            if originationFieldNames.contains(fieldName) {
                try closeResentBlock()
                inOrigination = true
            }

            if codesEqualCaseInsensitive(nameCodes, "date") {
                do throws(IETF.RFC.`2822`.Timestamp.Error) {
                    date = try IETF.RFC.`2822`.Timestamp(ascii: valueBytes)
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
                        do throws(IETF.RFC.`2822`.Mailbox.Error) {
                            let mailbox = try IETF.RFC.`2822`.Mailbox(ascii: trimmed.map({ $0.byte }))
                            from.append(mailbox)
                        } catch {
                            throw Error.invalidMailbox(error)
                        }
                    }
                }
            } else if codesEqualCaseInsensitive(nameCodes, "sender") {
                do throws(IETF.RFC.`2822`.Mailbox.Error) {
                    sender = try IETF.RFC.`2822`.Mailbox(ascii: valueBytes)
                } catch {
                    throw Error.invalidMailbox(error)
                }
            } else if codesEqualCaseInsensitive(nameCodes, "reply-to") {
                var addresses: [IETF.RFC.`2822`.Address] = []
                let parts = splitCodes(valueCodes, separator: ASCII.Code.comma)
                for part in parts {
                    let trimmed = trimWhitespace(part)
                    if !trimmed.isEmpty {
                        do throws(IETF.RFC.`2822`.Address.Error) {
                            let address = try IETF.RFC.`2822`.Address(ascii: trimmed.map({ $0.byte }))
                            addresses.append(address)
                        } catch {
                            throw Error.invalidAddress(error)
                        }
                    }
                }
                replyTo = addresses.isEmpty ? nil : addresses
            } else if codesEqualCaseInsensitive(nameCodes, "to") {
                var addresses: [IETF.RFC.`2822`.Address] = []
                let parts = splitCodes(valueCodes, separator: ASCII.Code.comma)
                for part in parts {
                    let trimmed = trimWhitespace(part)
                    if !trimmed.isEmpty {
                        do throws(IETF.RFC.`2822`.Address.Error) {
                            let address = try IETF.RFC.`2822`.Address(ascii: trimmed.map({ $0.byte }))
                            addresses.append(address)
                        } catch {
                            throw Error.invalidAddress(error)
                        }
                    }
                }
                to = addresses.isEmpty ? nil : addresses
            } else if codesEqualCaseInsensitive(nameCodes, "cc") {
                var addresses: [IETF.RFC.`2822`.Address] = []
                let parts = splitCodes(valueCodes, separator: ASCII.Code.comma)
                for part in parts {
                    let trimmed = trimWhitespace(part)
                    if !trimmed.isEmpty {
                        do throws(IETF.RFC.`2822`.Address.Error) {
                            let address = try IETF.RFC.`2822`.Address(ascii: trimmed.map({ $0.byte }))
                            addresses.append(address)
                        } catch {
                            throw Error.invalidAddress(error)
                        }
                    }
                }
                cc = addresses.isEmpty ? nil : addresses
            } else if codesEqualCaseInsensitive(nameCodes, "bcc") {
                var addresses: [IETF.RFC.`2822`.Address] = []
                let parts = splitCodes(valueCodes, separator: ASCII.Code.comma)
                for part in parts {
                    let trimmed = trimWhitespace(part)
                    if !trimmed.isEmpty {
                        do throws(IETF.RFC.`2822`.Address.Error) {
                            let address = try IETF.RFC.`2822`.Address(ascii: trimmed.map({ $0.byte }))
                            addresses.append(address)
                        } catch {
                            throw Error.invalidAddress(error)
                        }
                    }
                }
                bcc = addresses.isEmpty ? nil : addresses
            } else if codesEqualCaseInsensitive(nameCodes, "message-id") {
                do throws(IETF.RFC.`2822`.Message.ID.Error) {
                    messageID = try IETF.RFC.`2822`.Message.ID(ascii: valueBytes)
                } catch {
                    throw Error.invalidMessageID(error)
                }
            } else if codesEqualCaseInsensitive(nameCodes, "in-reply-to") {
                var ids: [IETF.RFC.`2822`.Message.ID] = []

                let parts = splitCodes(valueCodes, separator: ASCII.Code.space)
                for part in parts {
                    let trimmed = trimWhitespace(part)
                    if !trimmed.isEmpty && trimmed.first == ASCII.Code.lessThanSign {
                        do throws(IETF.RFC.`2822`.Message.ID.Error) {
                            let id = try IETF.RFC.`2822`.Message.ID(ascii: trimmed.map({ $0.byte }))
                            ids.append(id)
                        } catch {
                            throw Error.invalidMessageID(error)
                        }
                    }
                }
                inReplyTo = ids.isEmpty ? nil : ids
            } else if codesEqualCaseInsensitive(nameCodes, "references") {
                var ids: [IETF.RFC.`2822`.Message.ID] = []
                let parts = splitCodes(valueCodes, separator: ASCII.Code.space)
                for part in parts {
                    let trimmed = trimWhitespace(part)
                    if !trimmed.isEmpty && trimmed.first == ASCII.Code.lessThanSign {
                        do throws(IETF.RFC.`2822`.Message.ID.Error) {
                            let id = try IETF.RFC.`2822`.Message.ID(ascii: trimmed.map({ $0.byte }))
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

        try closeResentBlock()
        if awaitingReceived { throw Error.misplacedField("Return-Path") }

        guard let originationDate = date else {
            throw Error.missingRequiredField("Date")
        }
        guard !from.isEmpty else {
            throw Error.missingRequiredField("From")
        }

        try self.init(
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
    }
}

extension IETF.RFC.`2822`.Fields: Swift::RawRepresentable {

    public var rawValue: String { description }

    public init?(rawValue: String) {
        do throws(IETF.RFC.`2822`.Fields.Error) {
            try self.init(ascii: rawValue.utf8.map { Byte($0) })
        } catch {
            return nil
        }
    }
}

extension IETF.RFC.`2822`.Fields: CustomStringConvertible {

    public var description: String {
        var out: [Byte] = []
        IETF.RFC.`2822`.Fields.serialize(self, into: &out)
        return String(decoding: out, as: UTF8.self)
    }
}

#if !hasFeature(Embedded)
    extension IETF.RFC.`2822`.Fields: Codable {}
#endif
