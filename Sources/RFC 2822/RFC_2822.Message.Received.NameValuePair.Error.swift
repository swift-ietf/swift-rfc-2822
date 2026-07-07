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

extension RFC_2822.Message.Received.NameValuePair {
    /// Errors during name-value pair parsing
    public enum Error: Swift.Error, Sendable, Equatable, CustomStringConvertible {
        case empty
        case missingValue(_ name: String)
        case invalidName(_ value: String)
    }
}

extension RFC_2822.Message.Received.NameValuePair.Error {
    public var description: String {
        switch self {
        case .empty:
            return "Name-value pair cannot be empty"
        case .missingValue(let name):
            return "Name-value pair missing value for name: '\(name)'"
        case .invalidName(let value):
            return "Invalid name in name-value pair: '\(value)'"
        }
    }
}
