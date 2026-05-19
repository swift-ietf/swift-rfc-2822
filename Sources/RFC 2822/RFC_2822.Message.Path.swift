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

// MARK: - Binary.ASCII.Serializable

extension RFC_2822.Message.Path: Binary.ASCII.Serializable {
    static public func serialize<Buffer>(
        ascii path: RFC_2822.Message.Path,
        into buffer: inout Buffer
    ) where Buffer: RangeReplaceableCollection, Buffer.Element == Byte {
        buffer.append(ASCII.Code.lessThanSign)
        if let addrSpec = path.addrSpec {
            buffer.append(contentsOf: Array<Byte>(ascii: addrSpec))
        }
        buffer.append(ASCII.Code.greaterThanSign)
    }

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
    public init<Bytes: Collection>(ascii bytes: Bytes, in context: Void = ()) throws(Error)
    where Bytes.Element == Byte {
        guard !bytes.isEmpty else { throw Error.empty }

        // Type-up: lift to ASCII.Code at the entry boundary so the body works
        // against ASCII.Code constants directly (RFC 2822 grammar is strict ASCII).
        var codeArray = Array<ASCII.Code>(bytes)

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

// MARK: - Protocol Conformances

extension RFC_2822.Message.Path: Binary.ASCII.RawRepresentable {
    public typealias RawValue = String
}

extension RFC_2822.Message.Path: CustomStringConvertible {}
