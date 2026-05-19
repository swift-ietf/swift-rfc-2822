//
//  RFC_2822.swift
//  swift-rfc-2822
//
//  RFC 2822 Internet Message Format namespace
//

import ASCII_Serializer_Primitives
import INCITS_4_1986

/// RFC 2822 Internet Message Format
///
/// This namespace contains types for working with RFC 2822 email messages.
///
/// ## Key Types
///
/// - `Message`: Complete RFC 2822 message (fields + body)
/// - `Fields`: Message header fields
/// - `Mailbox`: Email mailbox (name + address)
/// - `Address`: Email address (mailbox or group)
/// - `AddrSpec`: Address specification (local-part@domain)
/// - `Timestamp`: RFC 2822 timestamp
///
/// ## Canonical Architecture
///
/// All types follow canonical byte-based serialization:
/// - Storage: `[Byte]` for body content
/// - Serialization: Direct byte generation without intermediate allocations
/// - String: Derived through functor composition from bytes
public enum RFC_2822 {}

// MARK: - atext Character Set

extension RFC_2822 {
    /// ASCII symbol codes allowed in `atext` per RFC 2822 Section 3.2.4
    ///
    /// The `atext` rule defines printable US-ASCII characters that can appear in atoms:
    /// ```
    /// atext = ALPHA / DIGIT /    ; Any character except controls,
    ///         "!" / "#" /        ;  SP, and specials.
    ///         "$" / "%" /        ;  Used for atoms
    ///         "&" / "'" /
    ///         "*" / "+" /
    ///         "-" / "/" /
    ///         "=" / "?" /
    ///         "^" / "_" /
    ///         "`" / "{" /
    ///         "|" / "}" /
    ///         "~"
    /// ```
    ///
    /// This set contains only the special symbols; ALPHA and DIGIT should be checked
    /// separately using `code.isLetter` and `code.isDigit`.
    public static let atextSymbols: Set<ASCII.Code> = [
        ASCII.Code.exclamationPoint,  // ! (0x21)
        ASCII.Code.numberSign,  // # (0x23)
        ASCII.Code.dollarSign,  // $ (0x24)
        ASCII.Code.percentSign,  // % (0x25)
        ASCII.Code.ampersand,  // & (0x26)
        ASCII.Code.apostrophe,  // ' (0x27)
        ASCII.Code.asterisk,  // * (0x2A)
        ASCII.Code.plusSign,  // + (0x2B)
        ASCII.Code.hyphen,  // - (0x2D)
        ASCII.Code.solidus,  // / (0x2F)
        ASCII.Code.equalsSign,  // = (0x3D)
        ASCII.Code.questionMark,  // ? (0x3F)
        ASCII.Code.circumflexAccent,  // ^ (0x5E)
        ASCII.Code.underline,  // _ (0x5F)
        ASCII.Code.leftSingleQuotationMark,  // ` (0x60)
        ASCII.Code.leftBrace,  // { (0x7B)
        ASCII.Code.verticalLine,  // | (0x7C)
        ASCII.Code.rightBrace,  // } (0x7D)
        ASCII.Code.tilde,  // ~ (0x7E)
    ]

    /// Tests if an ASCII code is a valid `atext` character per RFC 2822 Section 3.2.4
    ///
    /// Returns `true` if the code is ALPHA, DIGIT, or one of the allowed symbols.
    ///
    /// - Parameter code: The ASCII code to test
    /// - Returns: `true` if the code is valid in an atom
    @inlinable
    public static func isAtext(_ code: ASCII.Code) -> Bool {
        code.isLetter || code.isDigit || atextSymbols.contains(code)
    }
}
