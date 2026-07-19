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

extension RFC_2822.Timestamp {
    /// Errors during timestamp parsing and construction
    public enum Error: Swift.Error, Sendable, Equatable, CustomStringConvertible {
        case empty
        case invalidFormat(_ value: String)
        case invalidMonthName(_ value: String)
        case invalidZone(_ value: String)
        case invalidComponent(_ field: String, _ value: String)
    }
}

extension RFC_2822.Timestamp.Error {
    public var description: String {
        switch self {
        case .empty:
            return "Timestamp cannot be empty"
        case .invalidFormat(let value):
            return "Invalid RFC 2822 date-time format: '\(value)'"
        case .invalidMonthName(let value):
            return "Invalid RFC 2822 month name: '\(value)'"
        case .invalidZone(let value):
            return "Invalid RFC 2822 zone: '\(value)'"
        case .invalidComponent(let field, let value):
            return "Invalid \(field) value: '\(value)'"
        }
    }
}
