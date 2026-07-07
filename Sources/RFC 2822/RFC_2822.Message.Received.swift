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

extension RFC_2822.Message {
    /// Received trace field
    ///
    /// Per RFC 2822 Section 3.6.7:
    /// ```
    /// received = "Received:" name-val-list ";" date-time CRLF
    /// name-val-list = [CFWS] [name-val-pair *(CFWS name-val-pair)]
    /// name-val-pair = item-name CFWS item-value
    /// ```
    ///
    /// ## Example
    ///
    /// ```swift
    /// let received = try RFC_2822.Message.Received(ascii: "from mail.example.com by mx.example.org; 1234567890".utf8)
    /// ```
    public struct Received: Hashable, Sendable, Codable {
        public let tokens: [NameValuePair]
        public let timestamp: RFC_2822.Timestamp

        /// Creates a received field WITHOUT validation
        init(__unchecked: Void, tokens: [NameValuePair], timestamp: RFC_2822.Timestamp) {
            self.tokens = tokens
            self.timestamp = timestamp
        }

        /// Creates a received field with tokens and timestamp
        public init(tokens: [NameValuePair], timestamp: RFC_2822.Timestamp) {
            self.init(__unchecked: (), tokens: tokens, timestamp: timestamp)
        }
    }
}

// Note: NameValuePair is defined in RFC_2822.Message.Received.NameValuePair.swift

// MARK: - ASCII.Serializable / Binary.Serializable ([FAM-012] format siblings)

extension RFC_2822.Message.Received: ASCII.Serializable, Binary.Serializable {
    /// Serializes the received field as `name-val-list; timestamp` ASCII text.
    ///
    /// [FAM-012] text sibling — composes `NameValuePair` + `Timestamp` ASCII
    /// verbs directly (clause-9: ASCII verb → sub-part ASCII verbs).
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ received: RFC_2822.Message.Received,
        into buffer: inout Buffer
    ) where Buffer.Element == ASCII.Code {
        for (index, token) in received.tokens.enumerated() {
            if index > 0 { buffer.append(ASCII.Code.space) }
            NameValuePair.serialize(token, into: &buffer)
        }
        buffer.append(ASCII.Code.semicolon)
        buffer.append(ASCII.Code.space)
        RFC_2822.Timestamp.serialize(received.timestamp, into: &buffer)
    }

    /// Serializes the received field as `name-val-list; timestamp` wire bytes.
    ///
    /// [FAM-012] binary sibling. Clause-9: composes `NameValuePair` + `Timestamp`
    /// Byte verbs directly (Byte verb → sub-part Byte verbs) — never a
    /// `.serialized` detour.
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ received: RFC_2822.Message.Received,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        for (index, token) in received.tokens.enumerated() {
            if index > 0 { buffer.append(ASCII.Code.space.byte) }
            NameValuePair.serialize(token, into: &buffer)
        }
        buffer.append(ASCII.Code.semicolon.byte)
        buffer.append(ASCII.Code.space.byte)
        RFC_2822.Timestamp.serialize(received.timestamp, into: &buffer)
    }
}

// MARK: - ASCII.Parseable ([FAM-012] parse — free-standing init; marker requirement seal-last)

extension RFC_2822.Message.Received: ASCII.Parseable {

    /// Parses a received field from ASCII bytes (AUTHORITATIVE IMPLEMENTATION)
    ///
    /// ## RFC 2822 Section 3.6.7
    ///
    /// ```
    /// received = "Received:" name-val-list ";" date-time CRLF
    /// ```
    ///
    /// ## Category Theory
    ///
    /// Parsing transformation:
    /// - **Domain**: [Byte] (ASCII bytes)
    /// - **Codomain**: RFC_2822.Message.Received (structured data)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let received = try RFC_2822.Message.Received(ascii: [Byte]("from mail.example.com; 1234567890".utf8))
    /// ```
    ///
    /// - Parameter bytes: The received field as ASCII bytes
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
            throw Error.missingSemicolon(String(decoding: bytes, as: UTF8.self))
        }

        // Find semicolon that separates name-val-list from timestamp
        guard let semicolonIndex = codeArray.lastIndex(of: ASCII.Code.semicolon) else {
            throw Error.missingSemicolon(String(decoding: bytes, as: UTF8.self))
        }

        // Parse timestamp after semicolon
        let timestampStart = codeArray.index(after: semicolonIndex)
        guard timestampStart < codeArray.endIndex else {
            throw Error.missingTimestamp(String(decoding: bytes, as: UTF8.self))
        }

        var timestampCodes = Array(codeArray[timestampStart...])

        // Strip leading whitespace from timestamp
        while !timestampCodes.isEmpty
            && (timestampCodes.first == ASCII.Code.space || timestampCodes.first == ASCII.Code.htab)
        {
            timestampCodes.removeFirst()
        }

        guard !timestampCodes.isEmpty else {
            throw Error.missingTimestamp(String(decoding: bytes, as: UTF8.self))
        }

        let timestamp: RFC_2822.Timestamp
        do throws(RFC_2822.Timestamp.Error) {
            timestamp = try RFC_2822.Timestamp(ascii: [Byte](timestampCodes))
        } catch {
            throw Error.invalidTimestamp(error)
        }

        // Parse name-value pairs before semicolon
        let nameValCodes = Array(codeArray[..<semicolonIndex])
        var tokens: [NameValuePair] = []

        // Simple parsing: split on whitespace, pair up name-value
        var currentName: String?
        var currentToken: [ASCII.Code] = []

        for code in nameValCodes {
            if code == ASCII.Code.space || code == ASCII.Code.htab {
                if !currentToken.isEmpty {
                    let tokenString = String(decoding: currentToken, as: UTF8.self)
                    if let name = currentName {
                        tokens.append(
                            NameValuePair(__unchecked: (), name: name, value: tokenString)
                        )
                        currentName = nil
                    } else {
                        currentName = tokenString
                    }
                    currentToken = []
                }
            } else {
                currentToken.append(code)
            }
        }

        // Handle last token
        if !currentToken.isEmpty {
            let tokenString = String(decoding: currentToken, as: UTF8.self)
            if let name = currentName {
                tokens.append(NameValuePair(__unchecked: (), name: name, value: tokenString))
            } else if !tokenString.isEmpty {
                // Unpaired name - use as both name and value
                tokens.append(NameValuePair(__unchecked: (), name: tokenString, value: ""))
            }
        }

        self.init(__unchecked: (), tokens: tokens, timestamp: timestamp)
    }
}

// MARK: - RawRepresentable / CustomStringConvertible

extension RFC_2822.Message.Received: Swift.RawRepresentable {
    /// The canonical `name-val-list; timestamp` string form.
    ///
    /// Re-provides `Swift.RawRepresentable` directly — the retired
    /// `Binary.ASCII.RawRepresentable` no longer synthesizes it.
    public var rawValue: String { description }

    /// Creates a received field by parsing `rawValue`, or `nil` if it is malformed.
    public init?(rawValue: String) {
        try? self.init(ascii: rawValue.utf8.map { Byte($0) })
    }
}

extension RFC_2822.Message.Received: CustomStringConvertible {
    /// The received field in `name-val-list; timestamp` form — the same grammar
    /// the `ASCII.Serializable` / `Binary.Serializable` verbs emit.
    public var description: String {
        let pairs = tokens.map(\.description).joined(separator: " ")
        return "\(pairs); \(timestamp)"
    }
}
