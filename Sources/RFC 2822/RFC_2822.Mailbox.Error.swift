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

extension RFC_2822.Mailbox {
    /// Errors that can occur during mailbox parsing and validation
    ///
    /// RFC 2822 Section 3.4 defines mailbox as name-addr or addr-spec
    public enum Error: Swift.Error, Sendable, Equatable {
        /// Input is empty
        case empty

        /// Invalid mailbox format
        case invalidFormat(_ value: String)

        /// Missing closing angle bracket
        case missingClosingAngleBracket(_ value: String)

        /// Invalid addr-spec within the mailbox
        case invalidAddrSpec(RFC_2822.AddrSpec.Error)

        /// Display name contains a CR/LF (or other control byte) — the
        /// header-injection vector — or a non-ASCII byte.
        case invalidDisplayName(_ value: String)
    }
}

// MARK: - CustomStringConvertible

extension RFC_2822.Mailbox.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .empty:
            return "Mailbox cannot be empty"
        case .invalidFormat(let value):
            return "Invalid mailbox format '\(value)'"
        case .missingClosingAngleBracket(let value):
            return "Missing closing '>' in '\(value)'"
        case .invalidAddrSpec(let error):
            return "Invalid address: \(error)"
        case .invalidDisplayName(let value):
            return "Invalid display name (control byte or non-ASCII): '\(value)'"
        }
    }
}
