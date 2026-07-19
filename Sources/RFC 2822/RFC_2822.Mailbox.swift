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
    /// RFC 2822 mailbox (name-addr or addr-spec)
    ///
    /// Per RFC 2822 Section 3.4, a mailbox is either:
    /// - name-addr: `display-name angle-addr` (e.g., "John Doe <john@example.com>")
    /// - addr-spec: `local-part@domain` (e.g., "john@example.com")
    ///
    /// ## Example
    ///
    /// ```swift
    /// // With display name
    /// let mailbox1 = try RFC_2822.Mailbox(ascii: "John Doe <john@example.com>".utf8)
    /// print(mailbox1.displayName) // "John Doe"
    ///
    /// // Without display name
    /// let mailbox2 = try RFC_2822.Mailbox(ascii: "john@example.com".utf8)
    /// print(mailbox2.displayName) // nil
    /// ```
    ///
    /// ## See Also
    ///
    /// - [RFC 2822 Section 3.4](https://www.rfc-editor.org/rfc/rfc2822#section-3.4)
    public struct Mailbox: Hashable, Sendable, Codable {
        public let displayName: String?
        public let emailAddress: AddrSpec

        /// Creates a mailbox WITHOUT validation
        ///
        /// **Warning**: Bypasses RFC 2822 validation. Only use for:
        /// - Static constants
        /// - Pre-validated values
        /// - Internal construction after validation
        init(__unchecked: Void, displayName: String?, emailAddress: AddrSpec) {
            self.displayName = displayName
            self.emailAddress = emailAddress
        }

        /// Creates a validated mailbox
        ///
        /// - Parameters:
        ///   - displayName: Optional display name (e.g., "John Doe")
        ///   - emailAddress: The email address
        /// - Throws: `Error.invalidDisplayName` if `displayName` contains a
        ///   CR, LF, other control byte, or non-ASCII byte — see
        ///   `validateDisplayName(_:)`.
        public init(displayName: String? = nil, emailAddress: AddrSpec) throws(Error) {
            if let displayName { try Self.validateDisplayName(displayName) }
            self.init(__unchecked: (), displayName: displayName, emailAddress: emailAddress)
        }
    }
}

// MARK: - Display Name Validation (header-injection guard)

extension RFC_2822.Mailbox {
    /// Validates a display-name candidate against header injection.
    ///
    /// Rejects every C0 control byte (0x00-0x1F) and DEL (0x7F) — CR (0x0D)
    /// and LF (0x0A) are the injection vector itself (a literal CR/LF in a
    /// header field body breaks out of the field and lets attacker-
    /// controlled input forge additional header lines or a spurious
    /// body-separator blank line); the other C0 controls have no legitimate
    /// place in an unstructured display-name value either. Also rejects
    /// non-ASCII bytes: RFC 2822 header text is 7-bit US-ASCII, and
    /// MIME-encoding a non-ASCII display name (RFC 2047) is out of this
    /// package's scope, so it is rejected rather than silently mis-encoded.
    ///
    /// Applied at every construction path — the validated public
    /// initializer AND the `ASCII.Parseable` wire-text parser — so the
    /// invariant holds by construction and the (non-throwing, per the
    /// `ASCII.Serializable`/`Binary.Serializable` protocol shape)
    /// serializers never have to reject at write time.
    static func validateDisplayName(_ displayName: String) throws(Error) {
        for scalar in displayName.unicodeScalars {
            guard scalar.isASCII else { throw Error.invalidDisplayName(displayName) }
            let value = scalar.value
            guard value >= 0x20 && value != 0x7F else {
                throw Error.invalidDisplayName(displayName)
            }
        }
    }

    /// Belt-and-suspenders emit-time guard (defense in depth, second layer
    /// behind construction-time validation): every construction path — the
    /// validated public initializer and the `ASCII.Parseable` wire-text
    /// parser — routes `displayName` through `validateDisplayName(_:)`
    /// before it can be stored, so a CR/LF byte reaching
    /// `serialize`/`description` means an invariant was violated upstream
    /// (e.g. via the package-internal `__unchecked:` init).
    /// `ASCII.Serializable`/`Binary.Serializable` require a non-throwing
    /// `serialize(_:into:)`, so "reject" here means crash loudly rather than
    /// silently emit a forged header line onto the wire — `precondition`
    /// (not `assert`) so the guard stays live in release builds too.
    ///
    /// `Mailbox` does NOT need a hand-written `Decodable` conformance: it
    /// also conforms to `Swift.RawRepresentable` (`RawValue == String`,
    /// below), and for a type conforming to both `RawRepresentable` and
    /// `Codable`, the Swift standard library's conditional
    /// `RawRepresentable`-based `Encodable`/`Decodable` witness (encode/
    /// decode via the raw string) takes priority over compiler-synthesized
    /// per-property `Codable` — CONFIRMED empirically
    /// (`JSONEncoder().encode(mailbox)` produces `"John <john@example.com>"`,
    /// not `{"displayName":...,"emailAddress":...}`). Decoding therefore
    /// already goes through `init?(rawValue:)` -> `self.init(ascii:)`, the
    /// SAME wire-text parser validated above — there never was a reachable
    /// dictionary-shaped synthesized-decode path to close for this type. See
    /// the F-002 revision-1 report for the adversarial-review claim this
    /// corrects and the probe that disproved it.
    fileprivate static func preconditionInjectionSafe(_ displayName: String) {
        precondition(
            !displayName.utf8.contains(where: { $0 == 0x0D || $0 == 0x0A }),
            "RFC_2822.Mailbox: displayName contains CR/LF at serialize time — "
                + "construction-time validation was bypassed"
        )
    }
}

// MARK: - ASCII.Serializable / Binary.Serializable ([FAM-012] format siblings)

extension RFC_2822.Mailbox: ASCII.Serializable, Binary.Serializable {
    /// Serializes the mailbox as `Display Name <addr-spec>` (or bare `addr-spec`)
    /// ASCII text.
    ///
    /// [FAM-012] text sibling — emits `ASCII.Code` and composes `AddrSpec`'s
    /// ASCII verb directly (clause-9: ASCII verb → sub-part ASCII verb).
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
                    // quoted-pair escape: '"' and '\' must not appear bare
                    // inside a quoted-string (RFC 2822 §3.2.5 qtext excludes
                    // both; an un-escaped '"' would terminate the
                    // quoted-string early and an un-escaped '\' would make
                    // the following byte an unintended quoted-pair).
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

    /// Serializes the mailbox as `Display Name <addr-spec>` (or bare `addr-spec`)
    /// wire bytes.
    ///
    /// [FAM-012] binary sibling. Clause-9: an independent body composing
    /// `AddrSpec`'s Byte verb directly (Byte verb → sub-part Byte verb) — never
    /// a `.serialized` detour. Byte-equivalent to the text form.
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
                    // quoted-pair escape — see the ASCII-verb body above for
                    // the rationale; byte-equivalent independent body.
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

// MARK: - ASCII.Parseable ([FAM-012] parse — free-standing init; marker requirement seal-last)

extension RFC_2822.Mailbox: ASCII.Parseable {

    /// Parses a mailbox from ASCII bytes
    ///
    /// ## Category Theory
    ///
    /// Parsing transformation:
    /// - **Domain**: [Byte] (ASCII bytes)
    /// - **Codomain**: RFC_2822.Mailbox (structured data)
    ///
    /// ## Format
    ///
    /// Supports two formats:
    /// - `Display Name <addr-spec>` (name-addr)
    /// - `addr-spec` (simple address)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let bytes = [Byte]("John Doe <john@example.com>".utf8)
    /// let mailbox = try RFC_2822.Mailbox(ascii: bytes)
    /// ```
    ///
    /// - Parameter bytes: The mailbox as ASCII bytes
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
            throw Error.invalidFormat(String(decoding: bytes, as: UTF8.self))
        }

        // Check if this is a name-addr format (contains angle brackets)
        if let openIndex = codeArray.lastIndex(of: ASCII.Code.lessThanSign) {
            // name-addr format: "Display Name <addr-spec>"
            guard let closeIndex = codeArray.lastIndex(of: ASCII.Code.greaterThanSign),
                closeIndex > openIndex
            else {
                throw Error.missingClosingAngleBracket(String(decoding: bytes, as: UTF8.self))
            }

            // Extract display name (everything before <)
            // Trim whitespace from display name (code level)
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

            // Remove quotes if present
            if !trimmedDisplayNameCodes.isEmpty
                && trimmedDisplayNameCodes.first == ASCII.Code.quotationMark
                && trimmedDisplayNameCodes.last == ASCII.Code.quotationMark
            {
                displayName = String(
                    decoding: trimmedDisplayNameCodes[1..<(trimmedDisplayNameCodes.count - 1)],
                    as: UTF8.self
                )
            }

            // Extract addr-spec (between < and >) as Byte for downstream init
            let addrSpecStart = codeArray.index(after: openIndex)
            let addrSpecBytes = [Byte](codeArray[addrSpecStart..<closeIndex])

            let emailAddress: RFC_2822.AddrSpec
            do throws(RFC_2822.AddrSpec.Error) {
                emailAddress = try RFC_2822.AddrSpec(ascii: addrSpecBytes)
            } catch {
                throw Error.invalidAddrSpec(error)
            }

            // Reject header injection (CR/LF/control bytes) or non-ASCII in
            // a wire-parsed display name too — the invariant is enforced at
            // EVERY construction path, not only the public initializer, so
            // a parse -> re-serialize round trip cannot replay attacker-
            // controlled bytes into a forged header line.
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
            // addr-spec format (no display name)
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

// MARK: - RawRepresentable / CustomStringConvertible

extension RFC_2822.Mailbox: Swift.RawRepresentable {
    /// The canonical `Display Name <addr-spec>` / `addr-spec` string form.
    ///
    /// Re-provides `Swift.RawRepresentable` directly — the retired
    /// `Binary.ASCII.RawRepresentable` no longer synthesizes it.
    public var rawValue: String { description }

    /// Creates a mailbox by parsing `rawValue`, or `nil` if it is malformed.
    public init?(rawValue: String) {
        try? self.init(ascii: rawValue.utf8.map { Byte($0) })
    }
}

extension RFC_2822.Mailbox: CustomStringConvertible {
    /// The mailbox in `Display Name <addr-spec>` (or bare `addr-spec`) form —
    /// the same grammar the `ASCII.Serializable` / `Binary.Serializable` verbs
    /// emit.
    public var description: String {
        guard let displayName else { return emailAddress.description }
        Self.preconditionInjectionSafe(displayName)
        let needsQuoting = displayName.utf8.contains { byte in
            let code = ASCII.Code(byte)
            return !code.isLetter && !code.isDigit && code != ASCII.Code.space
        }
        guard needsQuoting else { return "\(displayName) <\(emailAddress)>" }
        // quoted-pair escape '"' and '\' — matches the ASCII/Binary
        // serialize verbs above.
        var escaped = ""
        escaped.reserveCapacity(displayName.count)
        for character in displayName {
            if character == "\"" || character == "\\" { escaped.append("\\") }
            escaped.append(character)
        }
        return "\"\(escaped)\" <\(emailAddress)>"
    }
}
