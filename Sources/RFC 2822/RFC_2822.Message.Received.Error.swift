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

extension RFC_2822.Message.Received {
    /// Errors during received field parsing
    public enum Error: Swift.Error, Sendable, Equatable, CustomStringConvertible {
        case empty
        case missingSemicolon(_ value: String)
        case missingTimestamp(_ value: String)
        case invalidTimestamp(_ underlying: RFC_2822.Timestamp.Error)
        case invalidNameValuePair(_ underlying: NameValuePair.Error)
    }
}

extension RFC_2822.Message.Received.Error {
    public var description: String {
        switch self {
        case .empty:
            return "Received field cannot be empty"
        case .missingSemicolon(let value):
            return "Received field must contain semicolon before timestamp: '\(value)'"
        case .missingTimestamp(let value):
            return "Received field must contain timestamp after semicolon: '\(value)'"
        case .invalidTimestamp(let error):
            return "Invalid timestamp in received field: \(error)"
        case .invalidNameValuePair(let error):
            return "Invalid name-value pair: \(error)"
        }
    }
}
