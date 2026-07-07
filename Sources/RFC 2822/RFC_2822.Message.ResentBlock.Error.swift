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

extension RFC_2822.Message.ResentBlock {
    /// Errors during resent block parsing
    public enum Error: Swift.Error, Sendable, Equatable, CustomStringConvertible {
        case empty
        case missingResentDate(_ value: String)
        case missingResentFrom(_ value: String)
        case invalidTimestamp(_ underlying: RFC_2822.Timestamp.Error)
        case invalidMailbox(_ underlying: RFC_2822.Mailbox.Error)
        case invalidAddress(_ field: String, value: String)
        case invalidMessageID(_ underlying: RFC_2822.Message.ID.Error)
    }
}

extension RFC_2822.Message.ResentBlock.Error {
    public var description: String {
        switch self {
        case .empty:
            return "Resent block cannot be empty"
        case .missingResentDate(let value):
            return "Resent block must contain Resent-Date: '\(value)'"
        case .missingResentFrom(let value):
            return "Resent block must contain Resent-From: '\(value)'"
        case .invalidTimestamp(let error):
            return "Invalid timestamp in resent block: \(error)"
        case .invalidMailbox(let error):
            return "Invalid mailbox in resent block: \(error)"
        case .invalidAddress(let field, let value):
            return "Invalid address in \(field): '\(value)'"
        case .invalidMessageID(let error):
            return "Invalid message ID in resent block: \(error)"
        }
    }
}
