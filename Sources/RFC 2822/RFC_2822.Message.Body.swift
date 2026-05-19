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
    /// RFC 2822 message body
    ///
    /// ## Canonical Storage
    ///
    /// The body is stored as bytes (`[Byte]`), which is the most universal
    /// representation for email message bodies:
    ///
    /// ```
    /// Body → [Byte] (bytes) → String (UTF-8 interpretation)
    /// ```
    ///
    /// ## RFC 2822 Notes
    ///
    /// RFC 2822 Section 2.3 defines the body as:
    /// - Lines of characters with CRLF line terminators
    /// - ASCII text (with MIME extensions for other character sets)
    /// - May be encoded per MIME specifications
    ///
    /// This type stores the raw bytes without interpretation, allowing for:
    /// - ASCII text bodies
    /// - UTF-8 encoded bodies (via MIME)
    /// - Binary content (via MIME transfer encodings)
    public struct Body: Hashable, Sendable {
        /// Canonical byte storage
        public let bytes: [Byte]

        /// Creates a body WITHOUT validation
        init(__unchecked: Void, bytes: [Byte]) {
            self.bytes = bytes
        }

        /// Initialize from byte array
        ///
        /// This is the canonical initializer that directly accepts bytes.
        ///
        /// - Parameter bytes: The message body as bytes
        public init(_ bytes: [Byte]) {
            self.init(__unchecked: (), bytes: bytes)
        }
    }
}

// MARK: - Binary.ASCII.Serializable

extension RFC_2822.Message.Body: Binary.ASCII.Serializable {
    static public func serialize<Buffer>(
        ascii body: RFC_2822.Message.Body,
        into buffer: inout Buffer
    ) where Buffer: RangeReplaceableCollection, Buffer.Element == Byte {
        buffer.append(contentsOf: body.bytes)
    }

    /// Error type (body parsing never fails)
    public enum Error: Swift.Error, Sendable, Equatable, CustomStringConvertible {
        case never

        public var description: String {
            "Body parsing never fails"
        }
    }

    /// Parses a message body from ASCII bytes (AUTHORITATIVE IMPLEMENTATION)
    ///
    /// RFC 2822 body is simply a sequence of bytes. No validation is performed
    /// beyond accepting the raw bytes.
    ///
    /// - Parameter bytes: The body content as bytes
    public init<Bytes: Collection>(ascii bytes: Bytes, in context: Void = ()) throws(Error)
    where Bytes.Element == Byte {
        self.init(__unchecked: (), bytes: Array(bytes))
    }
}

// MARK: - Protocol Conformances

extension RFC_2822.Message.Body: Binary.ASCII.RawRepresentable {
    public typealias RawValue = String
}

extension RFC_2822.Message.Body {
    /// Initialize from string
    ///
    /// Convenience initializer that converts string to UTF-8 bytes.
    ///
    /// - Parameter string: The message body as string
    public init(_ string: String) {
        self.init(__unchecked: (), bytes: Array<Byte>(string.utf8))
    }
}

extension RFC_2822.Message.Body: CustomStringConvertible {}

extension RFC_2822.Message.Body: Codable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        // Encode as string for JSON compatibility
        try container.encode(String(self))
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        self.init(string)
    }
}

extension RFC_2822.Message.Body: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}
