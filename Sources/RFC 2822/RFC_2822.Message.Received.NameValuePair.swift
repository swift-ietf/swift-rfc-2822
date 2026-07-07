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

// MARK: - ASCII.Serializable / Binary.Serializable ([FAM-012] format siblings)

extension RFC_2822.Message.Received.NameValuePair: ASCII.Serializable, Binary.Serializable {
    /// Serializes the pair as `name value` ASCII text (value omitted when empty).
    ///
    /// [FAM-012] text sibling — emits the typed text substrate `ASCII.Code`.
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ pair: RFC_2822.Message.Received.NameValuePair,
        into buffer: inout Buffer
    ) where Buffer.Element == ASCII.Code {
        buffer.reserveCapacity(pair.name.count + 1 + pair.value.count)
        for byte in pair.name.utf8 { buffer.append(ASCII.Code(byte)) }
        if !pair.value.isEmpty {
            buffer.append(ASCII.Code.space)
            for byte in pair.value.utf8 { buffer.append(ASCII.Code(byte)) }
        }
    }

    /// Serializes the pair as `name value` wire bytes (value omitted when empty).
    ///
    /// [FAM-012] binary sibling. Clause-9: an independent body re-emitting the
    /// grammar directly into the `Byte` domain — byte-equivalent to the text
    /// form; the ASCII==Binary equivalence test guards the two against drift.
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ pair: RFC_2822.Message.Received.NameValuePair,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        buffer.reserveCapacity(pair.name.count + 1 + pair.value.count)
        for byte in pair.name.utf8 { buffer.append(Byte(byte)) }
        if !pair.value.isEmpty {
            buffer.append(ASCII.Code.space.byte)
            for byte in pair.value.utf8 { buffer.append(Byte(byte)) }
        }
    }
}

// MARK: - ASCII.Parseable ([FAM-012] parse — free-standing init; marker requirement seal-last)

extension RFC_2822.Message.Received.NameValuePair: ASCII.Parseable {

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
    /// let pair = try RFC_2822.Message.Received.NameValuePair(ascii: [Byte]("from mail.example.com".utf8))
    /// ```
    ///
    /// - Parameter bytes: The name-value pair as ASCII bytes
    /// - Throws: `Error` if parsing fails
    public init<Bytes: Collection>(ascii bytes: Bytes) throws(Error)
    where Bytes.Element == Byte {
        guard !bytes.isEmpty else { throw Error.empty }

        // Type-up: lift to ASCII.Code at the entry boundary so the body works
        // against ASCII.Code constants directly (RFC 2822 grammar is strict ASCII).
        var codeArray: [ASCII.Code]
        do {
            codeArray = try [ASCII.Code](bytes)
        } catch {
            throw Error.invalidName(String(decoding: bytes, as: UTF8.self))
        }

        // Strip leading/trailing whitespace
        while !codeArray.isEmpty
            && (codeArray.first == ASCII.Code.space || codeArray.first == ASCII.Code.htab)
        {
            codeArray.removeFirst()
        }
        while !codeArray.isEmpty
            && (codeArray.last == ASCII.Code.space || codeArray.last == ASCII.Code.htab)
        {
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
                && (codeArray[valueStart] == ASCII.Code.space
                    || codeArray[valueStart] == ASCII.Code.htab)
            {
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

// MARK: - RawRepresentable / CustomStringConvertible

extension RFC_2822.Message.Received.NameValuePair: Swift.RawRepresentable {
    /// The canonical `name value` string form.
    ///
    /// Re-provides `Swift.RawRepresentable` directly — the retired
    /// `Binary.ASCII.RawRepresentable` no longer synthesizes it.
    public var rawValue: String { description }

    /// Creates a pair by parsing `rawValue`, or `nil` if it is malformed.
    public init?(rawValue: String) {
        try? self.init(ascii: rawValue.utf8.map { Byte($0) })
    }
}

extension RFC_2822.Message.Received.NameValuePair: CustomStringConvertible {
    /// The pair in `name value` form (value omitted when empty) — the same
    /// grammar the `ASCII.Serializable` / `Binary.Serializable` verbs emit.
    public var description: String {
        value.isEmpty ? name : "\(name) \(value)"
    }
}
