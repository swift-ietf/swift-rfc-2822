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
import INCITS_4_1986

extension RFC_2822 {
    /// RFC 2822 compliant message
    ///
    /// Per RFC 2822 Section 3:
    /// ```
    /// message = (fields / obs-fields) [CRLF body]
    /// body = *(*998text CRLF) *998text
    /// ```
    ///
    /// ## Example
    ///
    /// ```swift
    /// let message = try RFC_2822.Message(binary: rawMessageBytes)
    /// print(message.fields.subject)
    /// print(message.body)
    /// ```
    public struct Message: Sendable, Codable {
        public let fields: Fields
        public let body: Body?

        /// Creates a message WITHOUT validation
        init(__unchecked: Void, fields: Fields, body: Body?) {
            self.fields = fields
            self.body = body
        }

        /// Canonical initializer
        public init(fields: Fields, body: Body? = nil) {
            self.init(__unchecked: (), fields: fields, body: body)
        }
    }
}

// MARK: - Hashable

extension RFC_2822.Message: Hashable {}

// MARK: - Convenience Initializers

extension RFC_2822.Message {
    /// Convenience initializer with string body
    public init(
        fields: RFC_2822.Fields,
        body: String?
    ) {
        self.init(__unchecked: (), fields: fields, body: body.map { Body($0) })
    }
}

// MARK: - Errors

extension RFC_2822.Message {
    /// Errors during message parsing
    public enum Error: Swift.Error, Sendable, Equatable, CustomStringConvertible {
        case empty
        case invalidFields(RFC_2822.Fields.Error)

        public var description: String {
            switch self {
            case .empty:
                return "Message cannot be empty"
            case .invalidFields(let error):
                return "Invalid fields: \(error)"
            }
        }
    }
}

// MARK: - Binary.Serializable ([FAM-012] — Message is byte-domain, Binary-only)

extension RFC_2822.Message: Binary.Serializable {
    /// Serializes the whole message (`fields CRLF CRLF body`) as wire bytes.
    ///
    /// [FAM-012] Message is byte-domain (the body may be binary / MIME-encoded),
    /// so it conforms to `Binary.Serializable` ONLY. Clause-9: composes `Fields`'
    /// Byte verb + `Body`'s Byte verb directly — never a `.serialized` detour.
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ message: RFC_2822.Message,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        RFC_2822.Fields.serialize(message.fields, into: &buffer)
        if let body = message.body {
            // CRLF CRLF separator between headers and body
            buffer.append(ASCII.Code.cr.byte)
            buffer.append(ASCII.Code.lf.byte)
            buffer.append(ASCII.Code.cr.byte)
            buffer.append(ASCII.Code.lf.byte)
            RFC_2822.Message.Body.serialize(body, into: &buffer)
        }
    }
}

// MARK: - Byte-domain parse ([FAM-012] free-standing init; Binary.Parseable marker seal-last)

extension RFC_2822.Message {

    /// Parses a message from ASCII bytes (AUTHORITATIVE IMPLEMENTATION)
    ///
    /// ## RFC 2822 Section 3
    ///
    /// ```
    /// message = (fields / obs-fields) [CRLF body]
    /// ```
    ///
    /// Headers and body are separated by a blank line (CRLF CRLF).
    ///
    /// - Parameter bytes: The message as ASCII bytes
    /// - Throws: `Error` if parsing fails
    public init<Bytes: Collection>(binary bytes: Bytes) throws(Error)
    where Bytes.Element == Byte {
        guard !bytes.isEmpty else { throw Error.empty }

        // Type-up: lift to ASCII.Code at the entry boundary for grammar parsing,
        // but keep a [Byte] copy for body/field byte-domain consumption.
        let byteArray = Array<Byte>(bytes)
        let codeArray = byteArray.map { (try? ASCII.Code($0)) ?? ASCII.Code(unchecked: 0) }

        // Find the blank line (CRLF CRLF) that separates headers from body
        var headerEndIndex: Int?
        var bodyStartIndex: Int?

        // Look for CRLF CRLF
        if codeArray.count >= 4 {
            for i in 0..<(codeArray.count - 3) {
                if codeArray[i] == ASCII.Code.cr && codeArray[i + 1] == ASCII.Code.lf
                    && codeArray[i + 2] == ASCII.Code.cr && codeArray[i + 3] == ASCII.Code.lf {
                    headerEndIndex = i
                    bodyStartIndex = i + 4
                    break
                }
            }
        }

        // If not found, try LF LF (lenient)
        if headerEndIndex == nil && codeArray.count >= 2 {
            for i in 0..<(codeArray.count - 1) {
                if codeArray[i] == ASCII.Code.lf && codeArray[i + 1] == ASCII.Code.lf {
                    headerEndIndex = i
                    bodyStartIndex = i + 2
                    break
                }
            }
        }

        // Parse fields
        let fieldsBytes: [Byte]
        let bodyBytes: [Byte]?

        if let headerEnd = headerEndIndex, let bodyStart = bodyStartIndex {
            fieldsBytes = Array(byteArray[..<headerEnd])
            if bodyStart < byteArray.count {
                bodyBytes = Array(byteArray[bodyStart...])
            } else {
                bodyBytes = nil
            }
        } else {
            // No blank line - treat entire input as headers
            fieldsBytes = byteArray
            bodyBytes = nil
        }

        let fields: RFC_2822.Fields
        do {
            fields = try RFC_2822.Fields(ascii: fieldsBytes)
        } catch {
            throw Error.invalidFields(error)
        }

        let body: Body? = bodyBytes.flatMap { bytes in
            bytes.isEmpty ? nil : Body(bytes)
        }

        self.init(__unchecked: (), fields: fields, body: body)
    }
}

// MARK: - RawRepresentable / CustomStringConvertible

extension RFC_2822.Message: Swift.RawRepresentable {
    /// The whole message decoded as a UTF-8 string (lossy for binary bodies).
    ///
    /// Re-provides `Swift.RawRepresentable` directly — the retired
    /// `Binary.ASCII.RawRepresentable` no longer synthesizes it.
    public var rawValue: String { description }

    /// Creates a message by parsing `rawValue`'s UTF-8 bytes, or `nil` if malformed.
    public init?(rawValue: String) {
        try? self.init(binary: rawValue.utf8.map { Byte($0) })
    }
}

extension RFC_2822.Message: CustomStringConvertible {
    /// The whole message as `fields CRLF CRLF body` text — derived from the
    /// `Binary.Serializable` verb (the retired `Binary.ASCII` tier formerly
    /// synthesized this from the serialized form).
    public var description: String {
        var out: [Byte] = []
        RFC_2822.Message.serialize(self, into: &out)
        return String(decoding: out, as: UTF8.self)
    }
}
