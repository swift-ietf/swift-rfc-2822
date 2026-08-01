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

extension RFC_2822.Address {
    /// Errors during address parsing
    public enum Error: Swift.Error, Sendable, Equatable, CustomStringConvertible {
        case empty
        case invalidMailbox(RFC_2822.Mailbox.Error)
        case invalidGroup(_ value: String)
        case missingGroupTerminator(_ value: String)

        /// Group display name contains a CR/LF (or other control byte) — the
        /// header-injection vector — or a non-ASCII byte. Mirrors
        /// `RFC_2822.Mailbox.Error.invalidDisplayName`; a group's
        /// display-name is the same RFC 2822 §3.4 grammar production as a
        /// mailbox's.
        case invalidDisplayName(_ value: String)
    }
}

extension RFC_2822.Address.Error {
    public var description: String {
        switch self {
        case .empty:
            return "Address cannot be empty"

        case .invalidMailbox(let error):
            return "Invalid mailbox: \(error)"

        case .invalidGroup(let value):
            return "Invalid group format: '\(value)'"

        case .missingGroupTerminator(let value):
            return "Missing ';' terminator in group: '\(value)'"

        case .invalidDisplayName(let value):
            return "Invalid group display name (control byte or non-ASCII): '\(value)'"
        }
    }
}
