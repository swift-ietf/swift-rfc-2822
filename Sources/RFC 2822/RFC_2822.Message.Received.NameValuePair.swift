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

extension RFC_2822.Message.Received {
    /// Name-value pair in a Received trace field
    ///
    /// Per RFC 2822 Section 3.6.7:
    /// ```
    /// name-val-pair = item-name CFWS item-value
    /// item-name = ALPHA *(["-"] (ALPHA / DIGIT))
    /// item-value = 1*angle-addr / addr-spec / atom / domain / msg-id
    /// ```
    ///
    /// ## Example
    ///
    /// ```swift
    /// let pair = try RFC_2822.Message.Received.NameValuePair(ascii: "from mail.example.com".utf8)
    /// print(pair.name)  // "from"
    /// print(pair.value) // "mail.example.com"
    /// ```
    public struct NameValuePair: Hashable, Sendable, Codable {
        public let name: String
        public let value: String

        /// Creates a name-value pair WITHOUT validation
        init(__unchecked: Void, name: String, value: String) {
            self.name = name
            self.value = value
        }

        /// Creates a name-value pair with name and value
        public init(name: String, value: String) {
            self.init(__unchecked: (), name: name, value: value)
        }
    }
}

// MARK: - Binary.ASCII.Serializable

extension RFC_2822.Message.Received.NameValuePair: Binary.ASCII.Serializable {
    static public func serialize<Buffer>(
        ascii pair: RFC_2822.Message.Received.NameValuePair,
        into buffer: inout Buffer
    ) where Buffer: RangeReplaceableCollection, Buffer.Element == Byte {
        buffer.reserveCapacity(pair.name.count + 1 + pair.value.count)

        buffer.append(contentsOf: pair.name.utf8)
        if !pair.value.isEmpty {
            buffer.append(ASCII.Code.space)
            buffer.append(contentsOf: pair.value.utf8)
        }
    }

    /// Parses a name-value pair from ASCII bytes (AUTHORITATIVE IMPLEMENTATION)
    ///
    /// ## RFC 2822 Section 3.6.7
    ///
    /// ```
    /// name-val-pair = item-name CFWS item-value
    /// ```
    ///
    /// ## Category Theory
    ///
    /// Parsing transformation:
    /// - **Domain**: [Byte] (ASCII bytes)
    /// - **Codomain**: RFC_2822.Message.Received.NameValuePair (structured data)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let pair = try RFC_2822.Message.Received.NameValuePair(ascii: Array<Byte>("from mail.example.com".utf8))
    /// ```
    ///
    /// - Parameter bytes: The name-value pair as ASCII bytes
    /// - Throws: `Error` if parsing fails
    public init<Bytes: Collection>(ascii bytes: Bytes, in context: Void = ()) throws(Error)
    where Bytes.Element == Byte {
        guard !bytes.isEmpty else { throw Error.empty }

        // Type-up: lift to ASCII.Code at the entry boundary so the body works
        // against ASCII.Code constants directly (RFC 2822 grammar is strict ASCII).
        var codeArray: [ASCII.Code]
        do {
            codeArray = try Array<ASCII.Code>(bytes)
        } catch {
            throw Error.invalidName(String(decoding: bytes, as: UTF8.self))
        }

        // Strip leading/trailing whitespace
        while !codeArray.isEmpty
            && (codeArray.first == ASCII.Code.space || codeArray.first == ASCII.Code.htab) {
            codeArray.removeFirst()
        }
        while !codeArray.isEmpty
            && (codeArray.last == ASCII.Code.space || codeArray.last == ASCII.Code.htab) {
            codeArray.removeLast()
        }

        guard !codeArray.isEmpty else { throw Error.empty }

        // Find first whitespace that separates name from value
        var nameEndIndex: Int?
        for (index, code) in codeArray.enumerated() {
            if code == ASCII.Code.space || code == ASCII.Code.htab {
                nameEndIndex = index
                break
            }
        }

        let name: String
        let value: String

        if let endIndex = nameEndIndex {
            name = String(decoding: codeArray[..<endIndex], as: UTF8.self)

            // Extract value after whitespace
            var valueStart = endIndex
            while valueStart < codeArray.count
                && (codeArray[valueStart] == ASCII.Code.space || codeArray[valueStart] == ASCII.Code.htab) {
                valueStart += 1
            }

            if valueStart < codeArray.count {
                value = String(decoding: codeArray[valueStart...], as: UTF8.self)
            } else {
                value = ""
            }
        } else {
            // No whitespace - entire input is the name
            name = String(decoding: codeArray, as: UTF8.self)
            value = ""
        }

        guard !name.isEmpty else { throw Error.empty }

        self.init(__unchecked: (), name: name, value: value)
    }
}

// MARK: - Protocol Conformances

extension RFC_2822.Message.Received.NameValuePair: Binary.ASCII.RawRepresentable {
    public typealias RawValue = String
}

extension RFC_2822.Message.Received.NameValuePair: CustomStringConvertible {}
