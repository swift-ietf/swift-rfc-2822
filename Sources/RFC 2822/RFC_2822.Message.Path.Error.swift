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

extension RFC_2822.Message.Path {
    /// Errors during path parsing
    public enum Error: Swift.Error, Sendable, Equatable, CustomStringConvertible {
        case empty
        case missingAngleBrackets(_ value: String)
        case invalidAddrSpec(_ underlying: RFC_2822.AddrSpec.Error)
    }
}

extension RFC_2822.Message.Path.Error {
    public var description: String {
        switch self {
        case .empty:
            return "Path cannot be empty"
        case .missingAngleBrackets(let value):
            return "Path must be enclosed in angle brackets: '\(value)'"
        case .invalidAddrSpec(let error):
            return "Invalid addr-spec in path: \(error)"
        }
    }
}
