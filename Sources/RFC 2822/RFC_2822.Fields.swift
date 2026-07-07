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
    /// Message fields as defined in RFC 2822 Section 3.6
    ///
    /// Per RFC 2822:
    /// ```
    /// fields = *(trace *resent-field) *orig-date *from
    ///          [sender] [reply-to] *to *cc *bcc
    ///          [message-id] [in-reply-to] [references]
    ///          [subject] [comments] [keywords]
    /// ```
    public struct Fields: Sendable, Codable {
        // Required fields
        public let originationDate: RFC_2822.Timestamp
        public let from: [Mailbox]

        // Optional originator fields
        public let sender: Mailbox?
        public let replyTo: [Address]?

        // Optional destination fields
        public let to: [Address]?
        public let cc: [Address]?
        public let bcc: [Address]?

        // Optional identification fields
        public let messageID: Message.ID?
        public let inReplyTo: [Message.ID]?
        public let references: [Message.ID]?

        // Optional informational fields
        public let subject: String?
        public let comments: String?
        public let keywords: [String]?

        // Trace fields (optional but important)
        public let receivedFields: [Message.Received]
        public let returnPath: Message.Path?

        // Resent fields (optional block)
        public let resentFields: [Message.ResentBlock]

        /// Creates fields WITHOUT validation
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

            // Validate sender field requirement per RFC 2822 3.6.2
            if from.count > 1 && sender == nil {
                // RFC 2822 requires sender field when from has multiple mailboxes
                assertionFailure("Sender field required when From contains multiple mailboxes")
            }
        }
    }
}

// MARK: - Hashable

extension RFC_2822.Fields: Hashable {}

// MARK: - ASCII.Serializable / Binary.Serializable ([FAM-012] format siblings)

extension RFC_2822.Fields: ASCII.Serializable, Binary.Serializable {
    /// Serializes the header fields as a `field-name: value` block (ASCII text).
    ///
    /// [FAM-012] text sibling — composes every sub-part's ASCII verb directly
    /// (clause-9: ASCII verb → sub-part ASCII verbs; no `.description` /
    /// `.serialized` detour). The resent block composes `ResentBlock`'s own verb.
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

    /// Serializes the header fields as a `field-name: value` block (wire bytes).
    ///
    /// [FAM-012] binary sibling. Clause-9: composes every sub-part's Byte verb
    /// directly (Byte verb → sub-part Byte verbs) — never a `.description` /
    /// `.serialized` detour.
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

extension RFC_2822.Fields {

    /// Errors during fields parsing
    public enum Error: Swift.Error, Sendable, Equatable, CustomStringConvertible {
        case empty
        case missingRequiredField(_ fieldName: String)
        case invalidFieldFormat(_ fieldName: String, _ value: String)
        case invalidMailbox(RFC_2822.Mailbox.Error)
        case invalidAddress(RFC_2822.Address.Error)
        case invalidMessageID(RFC_2822.Message.ID.Error)

        public var description: String {
            switch self {
            case .empty:
                return "Fields cannot be empty"
            case .missingRequiredField(let fieldName):
                return "Missing required field: \(fieldName)"
            case .invalidFieldFormat(let fieldName, let value):
                return "Invalid format for field '\(fieldName)': '\(value)'"
            case .invalidMailbox(let error):
                return "Invalid mailbox: \(error)"
            case .invalidAddress(let error):
                return "Invalid address: \(error)"
            case .invalidMessageID(let error):
                return "Invalid message ID: \(error)"
            }
        }
    }
}

// MARK: - ASCII.Parseable ([FAM-012] parse — free-standing init; marker requirement seal-last)

extension RFC_2822.Fields: ASCII.Parseable {

    /// Parses fields from ASCII bytes (AUTHORITATIVE IMPLEMENTATION)
    ///
    /// ## RFC 2822 Section 3.6
    ///
    /// Parses header fields line by line. Each field is `field-name: field-body CRLF`.
    /// Supports header folding (continuation lines starting with whitespace).
    ///
    /// - Parameter bytes: The header fields as ASCII bytes
    /// - Throws: `Error` if parsing fails
    public init<Bytes: Collection>(ascii bytes: Bytes) throws(Error)
    where Bytes.Element == Byte {
        guard !bytes.isEmpty else { throw Error.empty }

        // Type-up: lift to ASCII.Code at the entry boundary so the body works
        // against ASCII.Code constants directly (RFC 2822 grammar is strict ASCII).
        let codeArray: [ASCII.Code]
        do {
            codeArray = try [ASCII.Code](bytes)
        } catch {
            throw Error.invalidFieldFormat("", String(decoding: bytes, as: UTF8.self))
        }

        // Helper: trim whitespace from code array
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

        // Helper: check if codes equal string (case-insensitive)
        func codesEqualCaseInsensitive(_ codes: [ASCII.Code], _ string: String) -> Bool {
            let stringCodes = (try? [ASCII.Code](string.utf8)) ?? []
            guard codes.count == stringCodes.count else { return false }
            for i in 0..<codes.count {
                let c1 = codes[i].lowercased()
                let c2 = stringCodes[i].lowercased()
                guard c1 == c2 else { return false }
            }
            return true
        }

        // Helper: split codes by separator (simple, not considering quotes)
        func splitCodes(_ codes: [ASCII.Code], separator: ASCII.Code) -> [[ASCII.Code]] {
            var result: [[ASCII.Code]] = []
            var current: [ASCII.Code] = []
            for code in codes {
                if code == separator {
                    result.append(current)
                    current = []
                } else {
                    current.append(code)
                }
            }
            result.append(current)
            return result
        }

        // Parse headers into name-value code pairs
        var headers: [(nameCodes: [ASCII.Code], valueCodes: [ASCII.Code])] = []
        var currentLine: [ASCII.Code] = []

        var i = 0
        while i < codeArray.count {
            let code = codeArray[i]

            if code == ASCII.Code.cr && i + 1 < codeArray.count && codeArray[i + 1] == ASCII.Code.lf
            {
                // CRLF found
                i += 2

                // Check if next line is a continuation (starts with space/tab)
                if i < codeArray.count
                    && (codeArray[i] == ASCII.Code.space || codeArray[i] == ASCII.Code.htab)
                {
                    // Folded header - continue current line
                    currentLine.append(ASCII.Code.space)
                    i += 1  // Skip the leading whitespace
                } else {
                    // End of this header field
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
                // LF only (lenient parsing)
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

        // Don't forget the last line
        if !currentLine.isEmpty {
            if let colonIdx = currentLine.firstIndex(of: ASCII.Code.colon) {
                let nameCodes = trimWhitespace(Array(currentLine[..<colonIdx]))
                let valueCodes = trimWhitespace(Array(currentLine[(colonIdx + 1)...]))
                headers.append((nameCodes: nameCodes, valueCodes: valueCodes))
            }
        }

        // Extract field values
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
            let valueBytes = [Byte](valueCodes)
            if codesEqualCaseInsensitive(nameCodes, "date") {
                do {
                    date = try RFC_2822.Timestamp(ascii: valueBytes)
                } catch {
                    throw Error.invalidFieldFormat(
                        "Date",
                        String(decoding: valueCodes, as: UTF8.self)
                    )
                }
            } else if codesEqualCaseInsensitive(nameCodes, "from") {
                // Parse comma-separated mailboxes
                let parts = splitCodes(valueCodes, separator: ASCII.Code.comma)
                for part in parts {
                    let trimmed = trimWhitespace(part)
                    if !trimmed.isEmpty {
                        do {
                            let mailbox = try RFC_2822.Mailbox(ascii: [Byte](trimmed))
                            from.append(mailbox)
                        } catch let error {
                            throw Error.invalidMailbox(error)
                        }
                    }
                }
            } else if codesEqualCaseInsensitive(nameCodes, "sender") {
                do {
                    sender = try RFC_2822.Mailbox(ascii: valueBytes)
                } catch let error {
                    throw Error.invalidMailbox(error)
                }
            } else if codesEqualCaseInsensitive(nameCodes, "reply-to") {
                var addresses: [RFC_2822.Address] = []
                let parts = splitCodes(valueCodes, separator: ASCII.Code.comma)
                for part in parts {
                    let trimmed = trimWhitespace(part)
                    if !trimmed.isEmpty {
                        do {
                            let address = try RFC_2822.Address(ascii: [Byte](trimmed))
                            addresses.append(address)
                        } catch let error {
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
                        do {
                            let address = try RFC_2822.Address(ascii: [Byte](trimmed))
                            addresses.append(address)
                        } catch let error {
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
                        do {
                            let address = try RFC_2822.Address(ascii: [Byte](trimmed))
                            addresses.append(address)
                        } catch let error {
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
                        do {
                            let address = try RFC_2822.Address(ascii: [Byte](trimmed))
                            addresses.append(address)
                        } catch let error {
                            throw Error.invalidAddress(error)
                        }
                    }
                }
                bcc = addresses.isEmpty ? nil : addresses
            } else if codesEqualCaseInsensitive(nameCodes, "message-id") {
                do {
                    messageID = try RFC_2822.Message.ID(ascii: valueBytes)
                } catch let error {
                    throw Error.invalidMessageID(error)
                }
            } else if codesEqualCaseInsensitive(nameCodes, "in-reply-to") {
                var ids: [RFC_2822.Message.ID] = []
                // Message IDs are space-separated
                let parts = splitCodes(valueCodes, separator: ASCII.Code.space)
                for part in parts {
                    let trimmed = trimWhitespace(part)
                    if !trimmed.isEmpty && trimmed.first == ASCII.Code.lessThanSign {
                        do {
                            let id = try RFC_2822.Message.ID(ascii: [Byte](trimmed))
                            ids.append(id)
                        } catch let error {
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
                        do {
                            let id = try RFC_2822.Message.ID(ascii: [Byte](trimmed))
                            ids.append(id)
                        } catch let error {
                            throw Error.invalidMessageID(error)
                        }
                    }
                }
                references = ids.isEmpty ? nil : ids
            } else if codesEqualCaseInsensitive(nameCodes, "subject") {
                subject = String(decoding: valueCodes, as: UTF8.self)
            } else if codesEqualCaseInsensitive(nameCodes, "comments") {
                comments = String(decoding: valueCodes, as: UTF8.self)
            } else if codesEqualCaseInsensitive(nameCodes, "keywords") {
                let parts = splitCodes(valueCodes, separator: ASCII.Code.comma)
                keywords = parts.map { String(decoding: trimWhitespace($0), as: UTF8.self) }
            }
            // Ignore unknown fields
        }

        // Validate required fields
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
            receivedFields: [],  // TODO: Parse trace fields
            returnPath: nil,
            resentFields: []
        )
    }
}

// MARK: - RawRepresentable / CustomStringConvertible

extension RFC_2822.Fields: Swift.RawRepresentable {
    /// The canonical header-field-block string form.
    ///
    /// Re-provides `Swift.RawRepresentable` directly — the retired
    /// `Binary.ASCII.RawRepresentable` no longer synthesizes it.
    public var rawValue: String { description }

    /// Creates fields by parsing `rawValue`, or `nil` if they are malformed.
    public init?(rawValue: String) {
        try? self.init(ascii: rawValue.utf8.map { Byte($0) })
    }
}

extension RFC_2822.Fields: CustomStringConvertible {
    /// The header fields as a `field-name: value` block — derived from the
    /// `Binary.Serializable` verb (the retired `Binary.ASCII` tier formerly
    /// synthesized this from the serialized form).
    public var description: String {
        var out: [Byte] = []
        RFC_2822.Fields.serialize(self, into: &out)
        return String(decoding: out, as: UTF8.self)
    }
}
