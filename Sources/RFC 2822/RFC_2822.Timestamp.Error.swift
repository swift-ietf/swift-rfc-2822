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
    /// Errors during timestamp parsing
    public enum Error: Swift.Error, Sendable, Equatable, CustomStringConvertible {
        case empty
        case invalidFormat(_ value: String)
    }
}

extension RFC_2822.Timestamp.Error {
    public var description: String {
        switch self {
        case .empty:
            return "Timestamp cannot be empty"
        case .invalidFormat(let value):
            return "Invalid timestamp format: '\(value)'"
        }
    }
}
