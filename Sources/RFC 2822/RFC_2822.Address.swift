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
    /// Represents an email address as defined in RFC 2822 Section 3.4
    ///
    /// Per RFC 2822:
    /// ```
    /// address = mailbox / group
    /// group = display-name ":" [mailbox-list / CFWS] ";"
    /// ```
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Mailbox address
    /// let addr1 = try RFC_2822.Address(ascii: "john@example.com".utf8)
    ///
    /// // Group address
    /// let addr2 = try RFC_2822.Address(ascii: "Team: john@example.com, jane@example.com;".utf8)
    /// ```
    public struct Address: Sendable, Codable {
        public enum Kind: Hashable, Sendable, Codable {
            case mailbox(Mailbox)
            case group(String, [Mailbox])  // Display name and members
        }

        public let kind: Kind

        /// Creates an address WITHOUT validation
        init(__unchecked: Void, kind: Kind) {
            self.kind = kind
        }

        /// Creates an address with the given kind
        public init(_ kind: Kind) {
            self.init(__unchecked: (), kind: kind)
        }
    }
}

// MARK: - Hashable

extension RFC_2822.Address: Hashable {}

// MARK: - Binary.ASCII.Serializable

extension RFC_2822.Address: Binary.ASCII.Serializable {
    public static func serialize<Buffer>(
        ascii address: RFC_2822.Address,
        into buffer: inout Buffer
    ) where Buffer: RangeReplaceableCollection, Buffer.Element == Byte {
        switch address.kind {
        case .mailbox(let mailbox):
            buffer.append(ascii: mailbox)

        case .group(let displayName, let mailboxes):
            // Group format: "Display Name: mailbox1, mailbox2;"
            buffer.append(contentsOf: displayName.utf8)
            buffer.append(ASCII.Code.colon)

            for (index, mailbox) in mailboxes.enumerated() {
                if index > 0 {
                    buffer.append(ASCII.Code.comma)
                    buffer.append(ASCII.Code.space)
                } else {
                    buffer.append(ASCII.Code.space)
                }
                buffer.append(ascii: mailbox)
            }

            buffer.append(ASCII.Code.semicolon)
        }
    }

    /// Errors during address parsing
    public enum Error: Swift.Error, Sendable, Equatable, CustomStringConvertible {
        case empty
        case invalidMailbox(RFC_2822.Mailbox.Error)
        case invalidGroup(_ value: String)
        case missingGroupTerminator(_ value: String)

        public var description: String {
            switch self {
            case .empty:
                return "Address cannot be empty"
            case .invalidMailbox(let error):
                return "Invalid mailbox: \(error)"
            case .invalidGroup(let value):
                return "Invalid group format: '\(value)'"
            case .missingGroupTerminator(let value):
                return "Missing ';' terminator in group: '\(value)'"
            }
        }
    }

    /// Parses an address from ASCII bytes (AUTHORITATIVE IMPLEMENTATION)
    ///
    /// ## RFC 2822 Section 3.4
    ///
    /// ```
    /// address = mailbox / group
    /// group = display-name ":" [mailbox-list / CFWS] ";"
    /// ```
    ///
    /// - Parameter bytes: The address as ASCII bytes
    /// - Throws: `Error` if parsing fails
    public init<Bytes: Collection>(ascii bytes: Bytes, in context: Void = ()) throws(Error)
    where Bytes.Element == Byte {
        guard !bytes.isEmpty else { throw Error.empty }

        // Type-up: lift to ASCII.Code at the entry boundary so the body works
        // against ASCII.Code constants directly (RFC 2822 grammar is strict ASCII).
        let codeArray = Array<ASCII.Code>(bytes)

        // Check if this is a group (contains : but not within angle brackets)
        var inAngleBracket = false
        var colonIndex: Int?
        var semicolonIndex: Int?

        for (index, code) in codeArray.enumerated() {
            if code == ASCII.Code.lessThanSign {
                inAngleBracket = true
            } else if code == ASCII.Code.greaterThanSign {
                inAngleBracket = false
            } else if code == ASCII.Code.colon && !inAngleBracket && colonIndex == nil {
                colonIndex = index
            } else if code == ASCII.Code.semicolon && colonIndex != nil {
                semicolonIndex = index
                break
            }
        }

        if let colonIdx = colonIndex {
            // This is a group: "display-name: mailbox-list ;"
            guard let semiIdx = semicolonIndex else {
                throw Error.missingGroupTerminator(String(decoding: bytes, as: UTF8.self))
            }

            // Extract display name (everything before :) and trim whitespace
            var displayNameCodes: [ASCII.Code] = Array(codeArray[..<colonIdx])
            while !displayNameCodes.isEmpty
                && (displayNameCodes.first == ASCII.Code.space || displayNameCodes.first == ASCII.Code.htab) {
                displayNameCodes.removeFirst()
            }
            while !displayNameCodes.isEmpty
                && (displayNameCodes.last == ASCII.Code.space || displayNameCodes.last == ASCII.Code.htab) {
                displayNameCodes.removeLast()
            }

            var displayName: String
            // Remove quotes if present
            if !displayNameCodes.isEmpty && displayNameCodes.first == ASCII.Code.quotationMark
                && displayNameCodes.last == ASCII.Code.quotationMark {
                displayName = String(
                    decoding: displayNameCodes[1..<(displayNameCodes.count - 1)],
                    as: UTF8.self
                )
            } else {
                displayName = String(decoding: displayNameCodes, as: UTF8.self)
            }

            // Extract mailbox list (between : and ;)
            let mailboxListStart = codeArray.index(after: colonIdx)
            let mailboxListCodes = codeArray[mailboxListStart..<semiIdx]

            // Parse mailbox list (comma-separated)
            var mailboxes: [RFC_2822.Mailbox] = []

            if !mailboxListCodes.isEmpty {
                // Split by commas (but not within angle brackets or quotes)
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
                        // End of this mailbox - trim whitespace
                        var trimmed = currentMailbox
                        while !trimmed.isEmpty
                            && (trimmed.first == ASCII.Code.space || trimmed.first == ASCII.Code.htab) {
                            trimmed.removeFirst()
                        }
                        while !trimmed.isEmpty
                            && (trimmed.last == ASCII.Code.space || trimmed.last == ASCII.Code.htab) {
                            trimmed.removeLast()
                        }
                        if !trimmed.isEmpty {
                            do {
                                let mailbox = try RFC_2822.Mailbox(ascii: Array<Byte>(trimmed))
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

                // Don't forget the last mailbox - trim whitespace
                var trimmed = currentMailbox
                while !trimmed.isEmpty
                    && (trimmed.first == ASCII.Code.space || trimmed.first == ASCII.Code.htab) {
                    trimmed.removeFirst()
                }
                while !trimmed.isEmpty
                    && (trimmed.last == ASCII.Code.space || trimmed.last == ASCII.Code.htab) {
                    trimmed.removeLast()
                }
                if !trimmed.isEmpty {
                    do {
                        let mailbox = try RFC_2822.Mailbox(ascii: Array<Byte>(trimmed))
                        mailboxes.append(mailbox)
                    } catch {
                        throw Error.invalidMailbox(error)
                    }
                }
            }

            self.init(__unchecked: (), kind: .group(displayName, mailboxes))
        } else {
            // This is a mailbox
            do {
                let mailbox = try RFC_2822.Mailbox(ascii: bytes)
                self.init(__unchecked: (), kind: .mailbox(mailbox))
            } catch {
                throw Error.invalidMailbox(error)
            }
        }
    }
}

// MARK: - Protocol Conformances

extension RFC_2822.Address: Binary.ASCII.RawRepresentable {
    public typealias RawValue = String
}

extension RFC_2822.Address: CustomStringConvertible {}
