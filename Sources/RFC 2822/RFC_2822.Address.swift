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

// MARK: - Kind

extension RFC_2822.Address {
    public enum Kind: Hashable, Sendable, Codable {
        case mailbox(RFC_2822.Mailbox)
        case group(String, [RFC_2822.Mailbox])  // Display name and members
    }
}

// MARK: - Codable (group display-name injection-guard on decode)

extension RFC_2822.Address.Kind {
    private enum CodingKeys: String, CodingKey {
        case mailbox
        case group
    }

    /// Keys for the nested per-case payload container. Unlike `Mailbox`/
    /// `AddrSpec`/`Address` (all `RawRepresentable<String>`, which makes
    /// their Codable conformance resolve to the Swift standard library's
    /// raw-value-based witness instead of per-property synthesis — see
    /// those types' `preconditionInjectionSafe` doc comments), `Kind` is
    /// NOT `RawRepresentable`, so IS decoded via ordinary compiler-
    /// synthesized enum-with-associated-values `Codable`: a keyed container
    /// under the case name, itself holding ANOTHER keyed container whose
    /// keys are the positional labels `_0`, `_1`, … for each unlabeled
    /// associated value — CONFIRMED empirically
    /// (`JSONEncoder().encode(Kind.group("Team", []))` produces
    /// `{"group":{"_0":"Team","_1":[]}}`, and the single-payload `.mailbox`
    /// case produces `{"mailbox":{"_0":"John <john@example.com>"}}`). This
    /// hand-written `init(from:)` mirrors that exact shape (so `encode(to:)`
    /// stays compiler-synthesized and wire-compatible) but routes the
    /// `group` case's display-name `String` through
    /// `RFC_2822.Mailbox.validateDisplayName` — the exact validator
    /// `Mailbox.displayName` uses, reused rather than duplicated — before it
    /// can be stored.
    private enum PayloadKeys: String, CodingKey {
        case _0
        case _1
    }

    /// Hand-written `Decodable` conformance closing a REAL, empirically
    /// confirmed bypass: decoding a bare `RFC_2822.Address.Kind.group` value
    /// directly (not wrapped in `Address` — e.g. as the payload of some
    /// other Codable structure, or via `JSONDecoder().decode(Kind.self,
    /// from:)`) previously assigned the display-name `String` straight from
    /// untrusted JSON with NO validation at all (there never was a
    /// validating construction path for it, unlike `Mailbox.displayName`).
    /// A group display name is the same RFC 2822 §3.4 `display-name`
    /// grammar production as a mailbox's, and `Address`'s serializers apply
    /// NO escaping to it at all — not even the quoted-pair escaping
    /// `Mailbox` applies to `"`/`\` — making this the most exposed of the
    /// Codable header-string fields audited alongside the F-002
    /// residual-bypass fix. (When `Kind` is reached indirectly, wrapped in
    /// `Address`, `Address`'s own `RawRepresentable`-based decode routes
    /// through the now-validated `Address.init(ascii:)` group branch
    /// instead of this initializer — both paths are closed.)
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.mailbox) {
            let payload = try container.nestedContainer(
                keyedBy: PayloadKeys.self, forKey: .mailbox)
            let mailbox = try payload.decode(RFC_2822.Mailbox.self, forKey: ._0)
            self = .mailbox(mailbox)
        } else if container.contains(.group) {
            let payload = try container.nestedContainer(
                keyedBy: PayloadKeys.self, forKey: .group)
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

// MARK: - Emit-time injection guard (defense in depth)

extension RFC_2822.Address {
    /// Belt-and-suspenders emit-time guard for the `group` case's display
    /// name, mirroring `RFC_2822.Mailbox`'s `preconditionInjectionSafe`:
    /// every construction path (the hand-written `Kind.Decodable`
    /// conformance above) validates the display name before it can be
    /// stored, so a CR/LF byte reaching a serializer means an invariant was
    /// violated upstream — crash loudly (a live-in-release `precondition`,
    /// not `assert`) rather than silently emit a forged header line.
    fileprivate static func preconditionGroupDisplayNameInjectionSafe(_ displayName: String) {
        precondition(
            !displayName.utf8.contains(where: { $0 == 0x0D || $0 == 0x0A }),
            "RFC_2822.Address.Kind.group: display name contains CR/LF at serialize time — "
                + "construction-time validation was bypassed"
        )
    }
}

// MARK: - Hashable

extension RFC_2822.Address: Hashable {}

// MARK: - ASCII.Serializable / Binary.Serializable ([FAM-012] format siblings)

extension RFC_2822.Address: ASCII.Serializable, Binary.Serializable {
    /// Serializes the address (`mailbox` or `group`) as ASCII text.
    ///
    /// [FAM-012] text sibling — composes `Mailbox`'s ASCII verb directly
    /// (clause-9: ASCII verb → sub-part ASCII verb).
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

    /// Serializes the address (`mailbox` or `group`) as wire bytes.
    ///
    /// [FAM-012] binary sibling. Clause-9: composes `Mailbox`'s Byte verb
    /// directly (Byte verb → sub-part Byte verb) — never a `.serialized` detour.
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

extension RFC_2822.Address {
    /// Errors during address parsing
    public enum Error: Swift.Error, Sendable, Equatable, CustomStringConvertible {
        case empty
        case invalidMailbox(RFC_2822.Mailbox.Error)
        case invalidGroup(_ value: String)
        case missingGroupTerminator(_ value: String)

        /// Group display name contains a CR/LF (or other control byte) — the
        /// header-injection vector — or a non-ASCII byte. Mirrors
        /// `RFC_2822.Mailbox.Error.invalidDisplayName`; a group's
        /// display-name is the same RFC 2822 §3.4 grammar production as a
        /// mailbox's.
        case invalidDisplayName(_ value: String)
    }
}

extension RFC_2822.Address.Error {
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
        case .invalidDisplayName(let value):
            return "Invalid group display name (control byte or non-ASCII): '\(value)'"
        }
    }
}

// MARK: - ASCII.Parseable ([FAM-012] parse — free-standing init; marker requirement seal-last)

extension RFC_2822.Address: ASCII.Parseable {

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
    public init<Bytes: Collection>(ascii bytes: Bytes) throws(Error)
    where Bytes.Element == Byte {
        guard !bytes.isEmpty else { throw Error.empty }

        // Type-up: lift to ASCII.Code at the entry boundary so the body works
        // against ASCII.Code constants directly (RFC 2822 grammar is strict ASCII).
        let codeArray: [ASCII.Code]
        do throws(ASCII.Code.Error) {
            codeArray = try [ASCII.Code](bytes)
        } catch {
            throw Error.invalidGroup(String(decoding: bytes, as: UTF8.self))
        }

        // Check if this is a group (contains : but not within angle brackets
        // or a quoted-string — F-005: a colon inside a quoted display name,
        // e.g. `"Time: 5pm" <j@d.com>`, is NOT the group separator; a scan
        // that only tracked angle brackets mistook it for one).
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
            // This is a group: "display-name: mailbox-list ;"
            guard let semiIdx = semicolonIndex else {
                throw Error.missingGroupTerminator(String(decoding: bytes, as: UTF8.self))
            }

            // Extract display name (everything before :) and trim whitespace
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
            // Remove quotes if present
            if !displayNameCodes.isEmpty && displayNameCodes.first == ASCII.Code.quotationMark
                && displayNameCodes.last == ASCII.Code.quotationMark
            {
                displayName = String(
                    decoding: displayNameCodes[1..<(displayNameCodes.count - 1)],
                    as: UTF8.self
                )
            } else {
                displayName = String(decoding: displayNameCodes, as: UTF8.self)
            }

            // Reject header injection (CR/LF/control bytes) or non-ASCII in a
            // wire-parsed group display name too — mirrors Mailbox's F-002
            // fix, applied at every construction path (not only the
            // Codable-decode path fixed alongside it), so a parse ->
            // re-serialize round trip cannot replay attacker-controlled
            // bytes into a forged header line.
            do throws(RFC_2822.Mailbox.Error) {
                try RFC_2822.Mailbox.validateDisplayName(displayName)
            } catch {
                throw Error.invalidDisplayName(displayName)
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
                                let mailbox = try RFC_2822.Mailbox(ascii: [Byte](trimmed))
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
                        let mailbox = try RFC_2822.Mailbox(ascii: [Byte](trimmed))
                        mailboxes.append(mailbox)
                    } catch {
                        throw Error.invalidMailbox(error)
                    }
                }
            }

            self.init(__unchecked: (), kind: .group(displayName, mailboxes))
        } else {
            // This is a mailbox
            do throws(RFC_2822.Mailbox.Error) {
                let mailbox = try RFC_2822.Mailbox(ascii: bytes)
                self.init(__unchecked: (), kind: .mailbox(mailbox))
            } catch {
                throw Error.invalidMailbox(error)
            }
        }
    }
}

// MARK: - RawRepresentable / CustomStringConvertible

extension RFC_2822.Address: Swift.RawRepresentable {
    /// The canonical address string form (`mailbox` or `group`).
    ///
    /// Re-provides `Swift.RawRepresentable` directly — the retired
    /// `Binary.ASCII.RawRepresentable` no longer synthesizes it.
    public var rawValue: String { description }

    /// Creates an address by parsing `rawValue`, or `nil` if it is malformed.
    public init?(rawValue: String) {
        try? self.init(ascii: rawValue.utf8.map { Byte($0) })
    }
}

extension RFC_2822.Address: CustomStringConvertible {
    /// The address in `mailbox` / `display-name: mailbox-list;` form — the same
    /// grammar the `ASCII.Serializable` / `Binary.Serializable` verbs emit.
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
