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

extension RFC_2822.Message {
    /// Block of resent fields
    ///
    /// Per RFC 2822 Section 3.6.6, resent fields provide trace information
    /// when a message is resent. They appear as a group:
    /// - Resent-Date (required in block)
    /// - Resent-From (required in block)
    /// - Resent-Sender (optional)
    /// - Resent-To (optional)
    /// - Resent-Cc (optional)
    /// - Resent-Bcc (optional)
    /// - Resent-Message-ID (optional)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let block = try RFC_2822.Message.ResentBlock(
    ///     ascii: "Resent-Date: 1234567890\r\nResent-From: user@example.com".utf8
    /// )
    /// ```
    public struct ResentBlock: Hashable, Sendable, Codable {
        public let timestamp: RFC_2822.Timestamp
        public let from: [RFC_2822.Mailbox]
        public let sender: RFC_2822.Mailbox?
        public let to: [RFC_2822.Address]?
        public let cc: [RFC_2822.Address]?
        public let bcc: [RFC_2822.Address]?
        public let messageID: ID?

        /// Creates a resent block WITHOUT validation
        init(
            __unchecked: Void,
            timestamp: RFC_2822.Timestamp,
            from: [RFC_2822.Mailbox],
            sender: RFC_2822.Mailbox?,
            to: [RFC_2822.Address]?,
            cc: [RFC_2822.Address]?,
            bcc: [RFC_2822.Address]?,
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

        /// Creates a resent block with required and optional fields
        public init(
            timestamp: RFC_2822.Timestamp,
            from: [RFC_2822.Mailbox],
            sender: RFC_2822.Mailbox? = nil,
            to: [RFC_2822.Address]? = nil,
            cc: [RFC_2822.Address]? = nil,
            bcc: [RFC_2822.Address]? = nil,
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

// MARK: - Binary.ASCII.Serializable

extension RFC_2822.Message.ResentBlock: Binary.ASCII.Serializable {
    static public func serialize<Buffer>(
        ascii block: RFC_2822.Message.ResentBlock,
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

        // Resent-Date (required)
        addField("Resent-Date", "\(block.timestamp.secondsSinceEpoch)")

        // Resent-From (required)
        addField("Resent-From", block.from.map { String(describing: $0) }.joined(separator: ", "))

        // Resent-Sender (optional)
        if let sender = block.sender {
            addField("Resent-Sender", String(describing: sender))
        }

        // Resent-To (optional)
        if let to = block.to {
            addField("Resent-To", to.map { String(describing: $0) }.joined(separator: ", "))
        }

        // Resent-Cc (optional)
        if let cc = block.cc {
            addField("Resent-Cc", cc.map { String(describing: $0) }.joined(separator: ", "))
        }

        // Resent-Bcc (optional)
        if let bcc = block.bcc {
            addField("Resent-Bcc", bcc.map { String(describing: $0) }.joined(separator: ", "))
        }

        // Resent-Message-ID (optional)
        if let messageID = block.messageID {
            addField("Resent-Message-ID", messageID.description)
        }
    }

    /// Parses a resent block from ASCII bytes (AUTHORITATIVE IMPLEMENTATION)
    ///
    /// ## RFC 2822 Section 3.6.6
    ///
    /// Resent fields appear as a block with required Resent-Date and Resent-From.
    ///
    /// ## Category Theory
    ///
    /// Parsing transformation:
    /// - **Domain**: [Byte] (ASCII bytes)
    /// - **Codomain**: RFC_2822.Message.ResentBlock (structured data)
    ///
    /// - Parameter bytes: The resent block as ASCII bytes
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
            throw Error.missingResentDate(String(decoding: bytes, as: UTF8.self))
        }

        // Helper to trim whitespace from code array
        func trimWhitespace(_ arr: [ASCII.Code]) -> [ASCII.Code] {
            var result = arr
            while !result.isEmpty && (result.first == ASCII.Code.space || result.first == ASCII.Code.htab) {
                result.removeFirst()
            }
            while !result.isEmpty && (result.last == ASCII.Code.space || result.last == ASCII.Code.htab) {
                result.removeLast()
            }
            return result
        }

        // Helper to split codes on separator
        func splitCodes(_ arr: [ASCII.Code], on separator: ASCII.Code) -> [[ASCII.Code]] {
            var result: [[ASCII.Code]] = []
            var current: [ASCII.Code] = []
            for code in arr {
                if code == separator {
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

        // Split into lines (on CR or LF)
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

        var timestamp: RFC_2822.Timestamp?
        var from: [RFC_2822.Mailbox] = []
        var sender: RFC_2822.Mailbox?
        var to: [RFC_2822.Address]?
        var cc: [RFC_2822.Address]?
        var bcc: [RFC_2822.Address]?
        var messageID: RFC_2822.Message.ID?

        for line in lines {
            // Find colon separator
            guard let colonIndex = line.firstIndex(of: ASCII.Code.colon) else { continue }

            let fieldNameCodes = trimWhitespace(Array(line[..<colonIndex]))
            let fieldValueCodes = trimWhitespace(Array(line[(colonIndex + 1)...]))

            let fieldName = String(decoding: fieldNameCodes, as: UTF8.self).lowercased()
            let fieldValueBytes = Array<Byte>(fieldValueCodes)

            switch fieldName {
            case "resent-date":
                timestamp = try? RFC_2822.Timestamp(ascii: fieldValueBytes)

            case "resent-from":
                // Parse comma-separated mailboxes
                let mailboxCodeArrays = splitCodes(fieldValueCodes, on: ASCII.Code.comma)
                for mailboxCodes in mailboxCodeArrays {
                    let trimmed = trimWhitespace(mailboxCodes)
                    guard !trimmed.isEmpty else { continue }
                    if let mailbox = try? RFC_2822.Mailbox(ascii: Array<Byte>(trimmed)) {
                        from.append(mailbox)
                    }
                }

            case "resent-sender":
                sender = try? RFC_2822.Mailbox(ascii: fieldValueBytes)

            case "resent-to":
                var addresses: [RFC_2822.Address] = []
                let addressCodeArrays = splitCodes(fieldValueCodes, on: ASCII.Code.comma)
                for addressCodes in addressCodeArrays {
                    let trimmed = trimWhitespace(addressCodes)
                    guard !trimmed.isEmpty else { continue }
                    if let address = try? RFC_2822.Address(ascii: Array<Byte>(trimmed)) {
                        addresses.append(address)
                    }
                }
                to = addresses.isEmpty ? nil : addresses

            case "resent-cc":
                var addresses: [RFC_2822.Address] = []
                let addressCodeArrays = splitCodes(fieldValueCodes, on: ASCII.Code.comma)
                for addressCodes in addressCodeArrays {
                    let trimmed = trimWhitespace(addressCodes)
                    guard !trimmed.isEmpty else { continue }
                    if let address = try? RFC_2822.Address(ascii: Array<Byte>(trimmed)) {
                        addresses.append(address)
                    }
                }
                cc = addresses.isEmpty ? nil : addresses

            case "resent-bcc":
                var addresses: [RFC_2822.Address] = []
                let addressCodeArrays = splitCodes(fieldValueCodes, on: ASCII.Code.comma)
                for addressCodes in addressCodeArrays {
                    let trimmed = trimWhitespace(addressCodes)
                    guard !trimmed.isEmpty else { continue }
                    if let address = try? RFC_2822.Address(ascii: Array<Byte>(trimmed)) {
                        addresses.append(address)
                    }
                }
                bcc = addresses.isEmpty ? nil : addresses

            case "resent-message-id":
                messageID = try? RFC_2822.Message.ID(ascii: fieldValueBytes)

            default:
                break
            }
        }

        guard let ts = timestamp else {
            throw Error.missingResentDate(String(decoding: codeArray, as: UTF8.self))
        }

        guard !from.isEmpty else {
            throw Error.missingResentFrom(String(decoding: codeArray, as: UTF8.self))
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

// MARK: - Protocol Conformances

extension RFC_2822.Message.ResentBlock: Binary.ASCII.RawRepresentable {
    public typealias RawValue = String
}

extension RFC_2822.Message.ResentBlock: CustomStringConvertible {}
