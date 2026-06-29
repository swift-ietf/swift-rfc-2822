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
    /// let message = try RFC_2822.Message(ascii: rawMessageBytes)
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

// MARK: - Binary.ASCII.Serializable

extension RFC_2822.Message: Binary.ASCII.Serializable {

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

    static public func serialize<Buffer>(
        ascii message: RFC_2822.Message,
        into buffer: inout Buffer
    ) where Buffer: RangeReplaceableCollection, Buffer.Element == Byte {

        // Serialize fields
        buffer.append(ascii: message.fields)

        // Add body if present
        if let body = message.body {
            // CRLF CRLF separator between headers and body
            buffer.append(ASCII.Code.cr)
            buffer.append(ASCII.Code.lf)
            buffer.append(ASCII.Code.cr)
            buffer.append(ASCII.Code.lf)

            // Body bytes
            buffer.append(contentsOf: body.bytes)
        }
    }

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
    public init<Bytes: Collection>(ascii bytes: Bytes, in context: Void = ()) throws(Error)
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

// MARK: - Protocol Conformances

extension RFC_2822.Message: Binary.ASCII.RawRepresentable {
    public typealias RawValue = String
}

// MARK: - CustomStringConvertible

extension RFC_2822.Message: CustomStringConvertible {}
