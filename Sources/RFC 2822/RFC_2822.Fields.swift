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

import ASCII_Serializer_Primitives
import INCITS_4_1986

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

// MARK: - Binary.ASCII.Serializable

extension RFC_2822.Fields: Binary.ASCII.Serializable {
    static public func serialize<Buffer>(
        ascii fields: RFC_2822.Fields,
        into buffer: inout Buffer
    ) where Buffer: RangeReplaceableCollection, Buffer.Element == Byte {
        // Helper to add a field line
        func addField(_ name: String, _ value: String) {
            buffer.append(contentsOf: name.utf8)
            buffer.append(ASCII.Code.colon)
            buffer.append(ASCII.Code.space)
            buffer.append(contentsOf: value.utf8)
            buffer.append(ASCII.Code.cr)
            buffer.append(ASCII.Code.lf)
        }

        // Add fields in recommended order per RFC 2822

        // Trace fields first
        for received in fields.receivedFields {
            addField("Received", "\(received)")
        }

        if let returnPath = fields.returnPath {
            addField("Return-Path", "\(returnPath)")
        }

        // Resent fields
        for block in fields.resentFields {
            addField("Resent-Date", "\(block.timestamp.secondsSinceEpoch)")
            addField(
                "Resent-From",
                block.from.map { String(describing: $0) }.joined(separator: ", ")
            )
            if let sender = block.sender {
                addField("Resent-Sender", String(describing: sender))
            }
            if let to = block.to {
                addField("Resent-To", to.map { String(describing: $0) }.joined(separator: ", "))
            }
            if let cc = block.cc {
                addField("Resent-Cc", cc.map { String(describing: $0) }.joined(separator: ", "))
            }
            if let messageID = block.messageID {
                addField("Resent-Message-ID", messageID.description)
            }
        }

        // Required fields
        addField("Date", "\(fields.originationDate.secondsSinceEpoch)")
        addField("From", fields.from.map { String(describing: $0) }.joined(separator: ", "))

        // Optional originator fields
        if let sender = fields.sender {
            addField("Sender", String(describing: sender))
        }
        if let replyTo = fields.replyTo {
            addField("Reply-To", replyTo.map { String(describing: $0) }.joined(separator: ", "))
        }

        // Destination fields
        if let to = fields.to {
            addField("To", to.map { String(describing: $0) }.joined(separator: ", "))
        }
        if let cc = fields.cc {
            addField("Cc", cc.map { String(describing: $0) }.joined(separator: ", "))
        }
        if let bcc = fields.bcc {
            addField("Bcc", bcc.map { String(describing: $0) }.joined(separator: ", "))
        }

        // Identification fields
        if let messageID = fields.messageID {
            addField("Message-ID", messageID.description)
        }
        if let inReplyTo = fields.inReplyTo {
            addField("In-Reply-To", inReplyTo.map(\.description).joined(separator: " "))
        }
        if let references = fields.references {
            addField("References", references.map(\.description).joined(separator: " "))
        }

        // Informational fields
        if let subject = fields.subject {
            addField("Subject", subject)
        }
        if let comments = fields.comments {
            addField("Comments", comments)
        }
        if let keywords = fields.keywords {
            addField("Keywords", keywords.joined(separator: ", "))
        }
    }

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

    /// Parses fields from ASCII bytes (AUTHORITATIVE IMPLEMENTATION)
    ///
    /// ## RFC 2822 Section 3.6
    ///
    /// Parses header fields line by line. Each field is `field-name: field-body CRLF`.
    /// Supports header folding (continuation lines starting with whitespace).
    ///
    /// - Parameter bytes: The header fields as ASCII bytes
    /// - Throws: `Error` if parsing fails
    public init<Bytes: Collection>(ascii bytes: Bytes, in context: Void = ()) throws(Error)
    where Bytes.Element == Byte {
        guard !bytes.isEmpty else { throw Error.empty }

        // Type-up: lift to ASCII.Code at the entry boundary so the body works
        // against ASCII.Code constants directly (RFC 2822 grammar is strict ASCII).
        let codeArray: [ASCII.Code]
        do {
            codeArray = try Array<ASCII.Code>(bytes)
        } catch {
            throw Error.invalidFieldFormat("", String(decoding: bytes, as: UTF8.self))
        }

        // Helper: trim whitespace from code array
        func trimWhitespace(_ input: [ASCII.Code]) -> [ASCII.Code] {
            var result = input
            while !result.isEmpty && (result.first == ASCII.Code.space || result.first == ASCII.Code.htab) {
                result.removeFirst()
            }
            while !result.isEmpty && (result.last == ASCII.Code.space || result.last == ASCII.Code.htab) {
                result.removeLast()
            }
            return result
        }

        // Helper: check if codes equal string (case-insensitive)
        func codesEqualCaseInsensitive(_ codes: [ASCII.Code], _ string: String) -> Bool {
            let stringCodes = (try? Array<ASCII.Code>(string.utf8)) ?? []
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

            if code == ASCII.Code.cr && i + 1 < codeArray.count && codeArray[i + 1] == ASCII.Code.lf {
                // CRLF found
                i += 2

                // Check if next line is a continuation (starts with space/tab)
                if i < codeArray.count
                    && (codeArray[i] == ASCII.Code.space || codeArray[i] == ASCII.Code.htab) {
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
                    && (codeArray[i] == ASCII.Code.space || codeArray[i] == ASCII.Code.htab) {
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
            let valueBytes = Array<Byte>(valueCodes)
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
                            let mailbox = try RFC_2822.Mailbox(ascii: Array<Byte>(trimmed))
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
                            let address = try RFC_2822.Address(ascii: Array<Byte>(trimmed))
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
                            let address = try RFC_2822.Address(ascii: Array<Byte>(trimmed))
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
                            let address = try RFC_2822.Address(ascii: Array<Byte>(trimmed))
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
                            let address = try RFC_2822.Address(ascii: Array<Byte>(trimmed))
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
                            let id = try RFC_2822.Message.ID(ascii: Array<Byte>(trimmed))
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
                            let id = try RFC_2822.Message.ID(ascii: Array<Byte>(trimmed))
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

// MARK: - Protocol Conformances

extension RFC_2822.Fields: Binary.ASCII.RawRepresentable {
    public typealias RawValue = String
}

extension RFC_2822.Fields: CustomStringConvertible {}
