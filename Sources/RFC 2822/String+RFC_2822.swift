//
//  String+RFC_2822.swift
//  swift-rfc-2822
//
//  String representations for RFC 2822 types
//
//  ## Architecture
//
//  String extensions compose through canonical byte representation:
//  ```
//  Type → [UInt8] (canonical) → String (UTF-8/other encoding)
//  ```
//
//  This is functor composition - String is derived from the universal
//  `[UInt8]` representation. All String inits are the authoritative
//  implementation for string serialization.

import Binary_Serializable_Primitives

// MARK: - AddrSpec

extension String {
    /// Creates string representation of RFC 2822 AddrSpec
    ///
    /// Composes through canonical byte representation.
    public init<Encoding>(
        _ addrSpec: RFC_2822.AddrSpec,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](addrSpec), as: encoding)
    }
}

// MARK: - Mailbox

extension String {
    /// Creates string representation of RFC 2822 Mailbox
    ///
    /// Composes through canonical byte representation.
    public init<Encoding>(
        _ mailbox: RFC_2822.Mailbox,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](mailbox), as: encoding)
    }
}

// MARK: - Address

extension String {
    /// Creates string representation of RFC 2822 Address
    ///
    /// Composes through canonical byte representation.
    public init<Encoding>(
        _ address: RFC_2822.Address,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](address), as: encoding)
    }
}

// MARK: - Fields

extension String {
    /// Creates string representation of RFC 2822 Fields
    ///
    /// Composes through canonical byte representation.
    public init<Encoding>(
        _ fields: RFC_2822.Fields,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](fields), as: encoding)
    }
}

// MARK: - Message

extension String {
    /// Creates string representation of RFC 2822 Message
    ///
    /// Composes through canonical byte representation.
    ///
    /// - Parameter message: The message to represent
    public init<Encoding>(
        _ message: RFC_2822.Message,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](message), as: encoding)
    }
}

// MARK: - Message.Body

extension String {
    /// Creates string representation of RFC 2822 message body
    ///
    /// Composes through canonical byte representation.
    ///
    /// - Parameter body: The message body to represent
    public init<Encoding>(
        _ body: RFC_2822.Message.Body,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](body), as: encoding)
    }
}

// MARK: - Timestamp

extension String {
    /// Creates string representation of RFC 2822 Timestamp
    ///
    /// Composes through canonical byte representation.
    ///
    /// - Parameter timestamp: The timestamp to represent
    public init<Encoding>(
        _ timestamp: RFC_2822.Timestamp,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](timestamp), as: encoding)
    }
}

// MARK: - Message.ID

extension String {
    /// Creates string representation of RFC 2822 Message ID
    ///
    /// Composes through canonical byte representation.
    ///
    /// - Parameter messageID: The message ID to represent
    public init<Encoding>(
        _ messageID: RFC_2822.Message.ID,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](messageID), as: encoding)
    }
}

// MARK: - Message.Path

extension String {
    /// Creates string representation of RFC 2822 Return Path
    ///
    /// Composes through canonical byte representation.
    ///
    /// - Parameter path: The return path to represent
    public init<Encoding>(
        _ path: RFC_2822.Message.Path,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](path), as: encoding)
    }
}

// MARK: - Message.Received.NameValuePair

extension String {
    /// Creates string representation of Received field name-value pair
    ///
    /// Composes through canonical byte representation.
    ///
    /// - Parameter pair: The name-value pair to represent
    public init<Encoding>(
        _ pair: RFC_2822.Message.Received.NameValuePair,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](pair), as: encoding)
    }
}

// MARK: - Message.Received

extension String {
    /// Creates string representation of RFC 2822 Received field
    ///
    /// Composes through canonical byte representation.
    ///
    /// - Parameter received: The received field to represent
    public init<Encoding>(
        _ received: RFC_2822.Message.Received,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](received), as: encoding)
    }
}
