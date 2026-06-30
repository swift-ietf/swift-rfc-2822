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

public import Binary_Serializable_Primitives

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

// MARK: - Binary.Serializable ([FAM-012] — Body is byte-domain, Binary-only)

extension RFC_2822.Message.Body: Binary.Serializable {
    /// Serializes the body as its raw wire bytes.
    ///
    /// [FAM-012] Body is byte-domain — it may carry binary / MIME-encoded
    /// content — so it conforms to `Binary.Serializable` ONLY. There is no
    /// `ASCII.Serializable` sibling: arbitrary bytes have no ASCII-text form.
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ body: RFC_2822.Message.Body,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        buffer.append(contentsOf: body.bytes)
    }
}

extension RFC_2822.Message.Body {
    /// Error type (body parsing never fails).
    public enum Error: Swift.Error, Sendable, Equatable, CustomStringConvertible {
        case never

        public var description: String {
            "Body parsing never fails"
        }
    }

    /// Creates a body from raw wire bytes — the byte-domain parse entry.
    ///
    /// RFC 2822 §2.3: the body is a sequence of bytes; no validation beyond
    /// accepting the raw bytes (hence non-throwing).
    public init<Bytes: Collection>(binary bytes: Bytes) where Bytes.Element == Byte {
        self.init(__unchecked: (), bytes: Array(bytes))
    }
}

// MARK: - Protocol Conformances

extension RFC_2822.Message.Body: Swift.RawRepresentable {
    /// The body decoded as a UTF-8 string (lossy for non-UTF-8 byte content).
    ///
    /// Re-provides `Swift.RawRepresentable` directly — the retired
    /// `Binary.ASCII.RawRepresentable` no longer synthesizes it.
    public var rawValue: String { description }

    /// Creates a body from `rawValue`'s UTF-8 bytes.
    public init?(rawValue: String) { self.init(rawValue) }
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

extension RFC_2822.Message.Body: CustomStringConvertible {
    /// The body decoded as UTF-8 text.
    public var description: String {
        String(decoding: bytes, as: UTF8.self)
    }
}

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
