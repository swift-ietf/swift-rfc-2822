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
    /// Message identifier as defined in RFC 2822 Section 3.6.4
    ///
    /// Per RFC 2822:
    /// ```
    /// msg-id = [CFWS] "<" id-left "@" id-right ">" [CFWS]
    /// id-left = dot-atom-text / no-fold-quote
    /// id-right = dot-atom-text / no-fold-literal
    /// ```
    ///
    /// ## Example
    ///
    /// ```swift
    /// let id = try RFC_2822.Message.ID(ascii: "<unique-id@example.com>".utf8)
    /// print(id.idLeft)  // "unique-id"
    /// print(id.idRight) // "example.com"
    /// ```
    public struct ID: Sendable, Codable {
        public let idLeft: String
        public let idRight: String

        /// Creates a message ID WITHOUT validation
        init(__unchecked: Void, idLeft: String, idRight: String) {
            self.idLeft = idLeft
            self.idRight = idRight
        }

        /// Creates a validated message ID
        public init(idLeft: String, idRight: String) {
            self.init(__unchecked: (), idLeft: idLeft, idRight: idRight)
        }
    }
}

// MARK: - Hashable

extension RFC_2822.Message.ID: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(idLeft)
        hasher.combine(idRight.lowercased())
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.idLeft == rhs.idLeft && lhs.idRight.lowercased() == rhs.idRight.lowercased()
    }
}

// MARK: - Binary.ASCII.Serializable

extension RFC_2822.Message.ID: Binary.ASCII.Serializable {
    static public func serialize<Buffer>(
        ascii id: RFC_2822.Message.ID,
        into buffer: inout Buffer
    ) where Buffer: RangeReplaceableCollection, Buffer.Element == Byte {
        buffer.reserveCapacity(id.idLeft.count + id.idRight.count + 3)

        buffer.append(ASCII.Code.lessThanSign)
        buffer.append(contentsOf: id.idLeft.utf8)
        buffer.append(ASCII.Code.commercialAt)
        buffer.append(contentsOf: id.idRight.utf8)
        buffer.append(ASCII.Code.greaterThanSign)
    }

    /// Parses a message ID from ASCII bytes (AUTHORITATIVE IMPLEMENTATION)
    ///
    /// ## RFC 2822 Section 3.6.4
    ///
    /// ```
    /// msg-id = [CFWS] "<" id-left "@" id-right ">" [CFWS]
    /// id-left = dot-atom-text / no-fold-quote
    /// id-right = dot-atom-text / no-fold-literal
    /// ```
    ///
    /// - Parameter bytes: The message ID as ASCII bytes
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

        // Extract content between < and >
        let contentCodes: [ASCII.Code] = Array(codeArray[1..<(codeArray.count - 1)])

        // Find @ separator
        guard let atIndex = contentCodes.firstIndex(of: ASCII.Code.commercialAt) else {
            throw Error.missingAtSign(String(decoding: bytes, as: UTF8.self))
        }

        let idLeftCodes: [ASCII.Code] = Array(contentCodes[..<atIndex])
        let idRightCodes: [ASCII.Code] = Array(contentCodes[(atIndex + 1)...])

        // ===== VALIDATE ID-LEFT =====
        // id-left = dot-atom-text / no-fold-quote

        guard !idLeftCodes.isEmpty else {
            throw Error.invalidIdLeft("")
        }

        let firstLeftCode = idLeftCodes[0]
        let lastLeftCode = idLeftCodes[idLeftCodes.count - 1]

        if firstLeftCode == ASCII.Code.quotationMark && lastLeftCode == ASCII.Code.quotationMark {
            // no-fold-quote: DQUOTE *(qtext / quoted-pair) DQUOTE
            var isEscaped = false
            for i in 1..<(idLeftCodes.count - 1) {
                let code = idLeftCodes[i]
                if isEscaped {
                    isEscaped = false
                } else if code == ASCII.Code.reverseSolidus {
                    isEscaped = true
                } else {
                    // qtext: printable ASCII except \ and "
                    let isValidQText =
                        (code >= 32 && code <= 126) && code != ASCII.Code.reverseSolidus
                        && code != ASCII.Code.quotationMark
                    guard isValidQText else {
                        throw Error.invalidIdLeft(String(decoding: idLeftCodes, as: UTF8.self))
                    }
                }
            }
            if isEscaped {
                throw Error.invalidIdLeft(String(decoding: idLeftCodes, as: UTF8.self))
            }
        } else {
            // dot-atom-text: 1*atext *("." 1*atext)
            guard firstLeftCode != ASCII.Code.period && lastLeftCode != ASCII.Code.period else {
                throw Error.invalidIdLeft(String(decoding: idLeftCodes, as: UTF8.self))
            }

            var previousCode: ASCII.Code = ASCII.Code(0)
            for code in idLeftCodes {
                if code == ASCII.Code.period && previousCode == ASCII.Code.period {
                    throw Error.invalidIdLeft(String(decoding: idLeftCodes, as: UTF8.self))
                }
                previousCode = code

                if code == ASCII.Code.period { continue }

                // atext per RFC 2822
                let isAtext =
                    code.isLetter || code.isDigit || code == 0x21  // ! exclamationMark
                    || code == ASCII.Code.numberSign  // #
                    || code == ASCII.Code.dollarSign  // $
                    || code == ASCII.Code.percentSign  // %
                    || code == ASCII.Code.ampersand  // &
                    || code == ASCII.Code.apostrophe  // '
                    || code == ASCII.Code.asterisk  // *
                    || code == ASCII.Code.plusSign  // +
                    || code == ASCII.Code.hyphen  // -
                    || code == ASCII.Code.solidus  // /
                    || code == ASCII.Code.equalsSign  // =
                    || code == ASCII.Code.questionMark  // ?
                    || code == ASCII.Code.circumflexAccent  // ^
                    || code == 0x5F  // _ lowLine
                    || code == 0x60  // ` graveAccent
                    || code == 0x7B  // { leftCurlyBracket
                    || code == ASCII.Code.verticalLine  // |
                    || code == 0x7D  // } rightCurlyBracket
                    || code == 0x7E  // ~ tilde

                guard isAtext else {
                    throw Error.invalidIdLeft(String(decoding: idLeftCodes, as: UTF8.self))
                }
            }
        }

        // ===== VALIDATE ID-RIGHT =====
        // id-right = dot-atom-text / no-fold-literal

        guard !idRightCodes.isEmpty else {
            throw Error.invalidIdRight("")
        }

        let firstRightCode = idRightCodes[0]
        let lastRightCode = idRightCodes[idRightCodes.count - 1]

        if firstRightCode == ASCII.Code.leftSquareBracket && lastRightCode == ASCII.Code.rightSquareBracket {
            // no-fold-literal: "[" *dtext "]"
            for i in 1..<(idRightCodes.count - 1) {
                let code = idRightCodes[i]
                // dtext: printable ASCII except [ ] \
                let isValidDText = (code >= 33 && code <= 90) || (code >= 94 && code <= 126)
                guard isValidDText else {
                    throw Error.invalidIdRight(String(decoding: idRightCodes, as: UTF8.self))
                }
            }
        } else {
            // dot-atom-text
            guard firstRightCode != ASCII.Code.period && lastRightCode != ASCII.Code.period else {
                throw Error.invalidIdRight(String(decoding: idRightCodes, as: UTF8.self))
            }

            var previousCode: ASCII.Code = ASCII.Code(0)
            for code in idRightCodes {
                if code == ASCII.Code.period && previousCode == ASCII.Code.period {
                    throw Error.invalidIdRight(String(decoding: idRightCodes, as: UTF8.self))
                }
                previousCode = code

                if code == ASCII.Code.period { continue }

                // atext per RFC 2822
                let isAtext =
                    code.isLetter || code.isDigit || code == 0x21  // ! exclamationMark
                    || code == ASCII.Code.numberSign  // #
                    || code == ASCII.Code.dollarSign  // $
                    || code == ASCII.Code.percentSign  // %
                    || code == ASCII.Code.ampersand  // &
                    || code == ASCII.Code.apostrophe  // '
                    || code == ASCII.Code.asterisk  // *
                    || code == ASCII.Code.plusSign  // +
                    || code == ASCII.Code.hyphen  // -
                    || code == ASCII.Code.solidus  // /
                    || code == ASCII.Code.equalsSign  // =
                    || code == ASCII.Code.questionMark  // ?
                    || code == ASCII.Code.circumflexAccent  // ^
                    || code == 0x5F  // _ lowLine
                    || code == 0x60  // ` graveAccent
                    || code == 0x7B  // { leftCurlyBracket
                    || code == ASCII.Code.verticalLine  // |
                    || code == 0x7D  // } rightCurlyBracket
                    || code == 0x7E  // ~ tilde

                guard isAtext else {
                    throw Error.invalidIdRight(String(decoding: idRightCodes, as: UTF8.self))
                }
            }
        }

        self.init(
            __unchecked: (),
            idLeft: String(decoding: idLeftCodes, as: UTF8.self),
            idRight: String(decoding: idRightCodes, as: UTF8.self)
        )
    }
}

// MARK: - Protocol Conformances

extension RFC_2822.Message.ID: Binary.ASCII.RawRepresentable {
    public typealias RawValue = String
}

extension RFC_2822.Message.ID: CustomStringConvertible {}
