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
public import Parseable_ASCII_Primitives
import INCITS_4_1986

extension RFC_2822.Message {
    /// Return path for trace fields
    ///
    /// Per RFC 2822 Section 3.6.7:
    /// ```
    /// return = "Return-Path:" path CRLF
    /// path = ([CFWS] "<" ([CFWS] / addr-spec) ">" [CFWS]) / obs-path
    /// ```
    ///
    /// ## Example
    ///
    /// ```swift
    /// let path = try RFC_2822.Message.Path(ascii: "<user@example.com>".utf8)
    /// let emptyPath = try RFC_2822.Message.Path(ascii: "<>".utf8)
    /// ```
    public struct Path: Hashable, Sendable, Codable {
        public let addrSpec: RFC_2822.AddrSpec?

        /// Creates a path WITHOUT validation
        init(__unchecked: Void, addrSpec: RFC_2822.AddrSpec?) {
            self.addrSpec = addrSpec
        }

        /// Creates a path with optional address specification
        public init(addrSpec: RFC_2822.AddrSpec? = nil) {
            self.init(__unchecked: (), addrSpec: addrSpec)
        }
    }
}

// MARK: - ASCII.Serializable / Binary.Serializable ([FAM-012] format siblings)

extension RFC_2822.Message.Path: ASCII.Serializable, Binary.Serializable {
    /// Serializes the path as `<addr-spec>` (or `<>`) ASCII text.
    ///
    /// [FAM-012] text sibling — composes `AddrSpec`'s ASCII verb directly
    /// (clause-9: ASCII verb → sub-part ASCII verb).
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ path: RFC_2822.Message.Path,
        into buffer: inout Buffer
    ) where Buffer.Element == ASCII.Code {
        buffer.append(ASCII.Code.lessThanSign)
        if let addrSpec = path.addrSpec {
            RFC_2822.AddrSpec.serialize(addrSpec, into: &buffer)
        }
        buffer.append(ASCII.Code.greaterThanSign)
    }

    /// Serializes the path as `<addr-spec>` (or `<>`) wire bytes.
    ///
    /// [FAM-012] binary sibling. Clause-9: composes `AddrSpec`'s Byte verb
    /// directly (Byte verb → sub-part Byte verb) — never a `.serialized` detour.
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ path: RFC_2822.Message.Path,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        buffer.append(ASCII.Code.lessThanSign.byte)
        if let addrSpec = path.addrSpec {
            RFC_2822.AddrSpec.serialize(addrSpec, into: &buffer)
        }
        buffer.append(ASCII.Code.greaterThanSign.byte)
    }
}

// MARK: - ASCII.Parseable ([FAM-012] parse — free-standing init; marker requirement seal-last)

extension RFC_2822.Message.Path: ASCII.Parseable {

    /// Parses a return path from ASCII bytes (AUTHORITATIVE IMPLEMENTATION)
    ///
    /// ## RFC 2822 Section 3.6.7
    ///
    /// ```
    /// path = ([CFWS] "<" ([CFWS] / addr-spec) ">" [CFWS]) / obs-path
    /// ```
    ///
    /// ## Category Theory
    ///
    /// Parsing transformation:
    /// - **Domain**: [Byte] (ASCII bytes)
    /// - **Codomain**: RFC_2822.Message.Path (structured data)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let path = try RFC_2822.Message.Path(ascii: Array<Byte>("<user@example.com>".utf8))
    /// ```
    ///
    /// - Parameter bytes: The path as ASCII bytes
    /// - Throws: `Error` if parsing fails
    public init<Bytes: Collection>(ascii bytes: Bytes) throws(Error)
    where Bytes.Element == Byte {
        guard !bytes.isEmpty else { throw Error.empty }

        // Type-up: lift to ASCII.Code at the entry boundary so the body works
        // against ASCII.Code constants directly (RFC 2822 grammar is strict ASCII).
        var codeArray: [ASCII.Code]
        do {
            codeArray = try Array<ASCII.Code>(bytes)
        } catch {
            throw Error.missingAngleBrackets(String(decoding: bytes, as: UTF8.self))
        }

        // Strip leading/trailing whitespace (CFWS)
        while !codeArray.isEmpty
            && (codeArray.first == ASCII.Code.space || codeArray.first == ASCII.Code.htab) {
            codeArray.removeFirst()
        }
        while !codeArray.isEmpty
            && (codeArray.last == ASCII.Code.space || codeArray.last == ASCII.Code.htab) {
            codeArray.removeLast()
        }

        guard !codeArray.isEmpty else { throw Error.empty }

        // Must be enclosed in angle brackets
        guard codeArray.first == ASCII.Code.lessThanSign && codeArray.last == ASCII.Code.greaterThanSign
        else {
            throw Error.missingAngleBrackets(String(decoding: bytes, as: UTF8.self))
        }

        // Extract content between < and > (as Byte for downstream AddrSpec init)
        let contentBytes = Array<Byte>(codeArray[1..<(codeArray.count - 1)])

        // Empty path <> is valid
        if contentBytes.isEmpty {
            self.init(__unchecked: (), addrSpec: nil)
            return
        }

        // Parse addr-spec
        let addrSpec: RFC_2822.AddrSpec
        do {
            addrSpec = try RFC_2822.AddrSpec(ascii: contentBytes)
        } catch {
            throw Error.invalidAddrSpec(error)
        }

        self.init(__unchecked: (), addrSpec: addrSpec)
    }
}

// MARK: - RawRepresentable / CustomStringConvertible

extension RFC_2822.Message.Path: Swift.RawRepresentable {
    /// The canonical `<addr-spec>` / `<>` string form.
    ///
    /// Re-provides `Swift.RawRepresentable` directly — the retired
    /// `Binary.ASCII.RawRepresentable` no longer synthesizes it.
    public var rawValue: String { description }

    /// Creates a path by parsing `rawValue`, or `nil` if it is malformed.
    public init?(rawValue: String) {
        try? self.init(ascii: rawValue.utf8.map { Byte($0) })
    }
}

extension RFC_2822.Message.Path: CustomStringConvertible {
    /// The path in `<addr-spec>` (or `<>`) form — the same grammar the
    /// `ASCII.Serializable` / `Binary.Serializable` verbs emit.
    public var description: String {
        "<\(addrSpec?.description ?? "")>"
    }
}
