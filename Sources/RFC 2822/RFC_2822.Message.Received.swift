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

// MARK: - Binary.ASCII.Serializable

extension RFC_2822.Message.Received: Binary.ASCII.Serializable {
    static public func serialize<Buffer>(
        ascii received: RFC_2822.Message.Received,
        into buffer: inout Buffer
    ) where Buffer: RangeReplaceableCollection, Buffer.Element == Byte {

        // Add name-value pairs
        for (index, token) in received.tokens.enumerated() {
            if index > 0 {
                buffer.append(ASCII.Code.space)
            }
            buffer.append(ascii: token)
        }

        // Add semicolon and timestamp
        buffer.append(ASCII.Code.semicolon)
        buffer.append(ASCII.Code.space)
        buffer.append(ascii: received.timestamp)
    }

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
    /// let received = try RFC_2822.Message.Received(ascii: Array<Byte>("from mail.example.com; 1234567890".utf8))
    /// ```
    ///
    /// - Parameter bytes: The received field as ASCII bytes
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
            && (timestampCodes.first == ASCII.Code.space || timestampCodes.first == ASCII.Code.htab) {
            timestampCodes.removeFirst()
        }

        guard !timestampCodes.isEmpty else {
            throw Error.missingTimestamp(String(decoding: bytes, as: UTF8.self))
        }

        let timestamp: RFC_2822.Timestamp
        do {
            timestamp = try RFC_2822.Timestamp(ascii: Array<Byte>(timestampCodes))
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

// MARK: - Protocol Conformances

extension RFC_2822.Message.Received: Binary.ASCII.RawRepresentable {
    public typealias RawValue = String
}

extension RFC_2822.Message.Received: CustomStringConvertible {}
