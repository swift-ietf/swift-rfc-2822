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

// MARK: - ASCII.Serializable / Binary.Serializable ([FAM-012] format siblings)

extension RFC_2822.Timestamp: ASCII.Serializable, Binary.Serializable {
    /// Serializes the timestamp as its numeric seconds-since-epoch ASCII text.
    ///
    /// [FAM-012] text sibling — emits the typed text substrate `ASCII.Code`.
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ timestamp: RFC_2822.Timestamp,
        into buffer: inout Buffer
    ) where Buffer.Element == ASCII.Code {
        for byte in "\(timestamp.secondsSinceEpoch)".utf8 { buffer.append(ASCII.Code(byte)) }
    }

    /// Serializes the timestamp as its numeric seconds-since-epoch wire bytes.
    ///
    /// [FAM-012] binary sibling. Clause-9: an independent body re-emitting the
    /// value directly into the `Byte` domain — byte-equivalent to the text form
    /// (the timestamp renders as ASCII digits); the ASCII==Binary equivalence
    /// test guards the two bodies against drift.
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ timestamp: RFC_2822.Timestamp,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        for byte in "\(timestamp.secondsSinceEpoch)".utf8 { buffer.append(Byte(byte)) }
    }
}

// MARK: - ASCII.Parseable ([FAM-012] parse — free-standing init; marker requirement seal-last)

extension RFC_2822.Timestamp: ASCII.Parseable {

    /// Parses a timestamp from ASCII bytes (AUTHORITATIVE IMPLEMENTATION)
    ///
    /// This implementation parses a simple numeric seconds-since-epoch format.
    /// Full RFC 2822 date-time parsing would require additional complexity.
    ///
    /// - Parameter bytes: The timestamp as ASCII bytes
    /// - Throws: `Error` if parsing fails
    public init<Bytes: Collection>(ascii bytes: Bytes) throws(Error)
    where Bytes.Element == Byte {
        guard !bytes.isEmpty else { throw Error.empty }

        // Type-up: lift to ASCII.Code at the entry boundary so the body works
        // against ASCII.Code constants directly (RFC 2822 timestamp grammar is
        // strict ASCII).
        var codeArray: [ASCII.Code]
        do {
            codeArray = try [ASCII.Code](bytes)
        } catch {
            throw Error.invalidFormat(String(decoding: bytes, as: UTF8.self))
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

        // Parse as numeric value
        let string = String(decoding: codeArray, as: UTF8.self)
        guard let value = Double(string) else {
            throw Error.invalidFormat(string)
        }

        self.init(__unchecked: (), secondsSinceEpoch: value)
    }
}

// MARK: - RawRepresentable / CustomStringConvertible

extension RFC_2822.Timestamp: Swift.RawRepresentable {
    /// The canonical numeric seconds-since-epoch string form.
    ///
    /// Re-provides `Swift.RawRepresentable` directly — the retired
    /// `Binary.ASCII.RawRepresentable` no longer synthesizes it.
    public var rawValue: String { description }

    /// Creates a timestamp by parsing `rawValue`, or `nil` if it is malformed.
    public init?(rawValue: String) {
        try? self.init(ascii: rawValue.utf8.map { Byte($0) })
    }
}

extension RFC_2822.Timestamp: CustomStringConvertible {
    /// The timestamp's numeric seconds-since-epoch text — the same form the
    /// `ASCII.Serializable` / `Binary.Serializable` verbs emit.
    public var description: String {
        "\(secondsSinceEpoch)"
    }
}
