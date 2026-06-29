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
    /// RFC 2822 timestamp
    ///
    /// Per RFC 2822 Section 3.3:
    /// ```
    /// date-time = [ day-of-week "," ] date FWS time [CFWS]
    /// date = day month year
    /// time = time-of-day FWS zone
    /// ```
    ///
    /// This type stores timestamp as seconds since epoch for simplicity.
    /// Full RFC 2822 date-time formatting requires additional Date/Calendar APIs.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let timestamp = RFC_2822.Timestamp(secondsSinceEpoch: 1234567890)
    /// ```
    public struct Timestamp: Sendable, Codable {
        public let secondsSinceEpoch: Double

        /// Creates a timestamp WITHOUT validation
        init(__unchecked: Void, secondsSinceEpoch: Double) {
            self.secondsSinceEpoch = secondsSinceEpoch
        }

        /// Creates a timestamp with the given seconds since epoch
        public init(secondsSinceEpoch: Double) {
            self.init(__unchecked: (), secondsSinceEpoch: secondsSinceEpoch)
        }
    }
}

// MARK: - Hashable

extension RFC_2822.Timestamp: Hashable {}

// MARK: - Binary.ASCII.Serializable

extension RFC_2822.Timestamp: Binary.ASCII.Serializable {
    static public func serialize<Buffer>(
        ascii timestamp: RFC_2822.Timestamp,
        into buffer: inout Buffer
    ) where Buffer: RangeReplaceableCollection, Buffer.Element == Byte {
        buffer.append(contentsOf: "\(timestamp.secondsSinceEpoch)".utf8)
    }

    /// Parses a timestamp from ASCII bytes (AUTHORITATIVE IMPLEMENTATION)
    ///
    /// This implementation parses a simple numeric seconds-since-epoch format.
    /// Full RFC 2822 date-time parsing would require additional complexity.
    ///
    /// - Parameter bytes: The timestamp as ASCII bytes
    /// - Throws: `Error` if parsing fails
    public init<Bytes: Collection>(ascii bytes: Bytes, in context: Void = ()) throws(Error)
    where Bytes.Element == Byte {
        guard !bytes.isEmpty else { throw Error.empty }

        // Type-up: lift to ASCII.Code at the entry boundary so the body works
        // against ASCII.Code constants directly (RFC 2822 timestamp grammar is
        // strict ASCII).
        var codeArray: [ASCII.Code]
        do {
            codeArray = try Array<ASCII.Code>(bytes)
        } catch {
            throw Error.invalidFormat(String(decoding: bytes, as: UTF8.self))
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

        // Parse as numeric value
        let string = String(decoding: codeArray, as: UTF8.self)
        guard let value = Double(string) else {
            throw Error.invalidFormat(string)
        }

        self.init(__unchecked: (), secondsSinceEpoch: value)
    }
}

// MARK: - Protocol Conformances

extension RFC_2822.Timestamp: Binary.ASCII.RawRepresentable {
    public typealias RawValue = String
}

extension RFC_2822.Timestamp: CustomStringConvertible {}
