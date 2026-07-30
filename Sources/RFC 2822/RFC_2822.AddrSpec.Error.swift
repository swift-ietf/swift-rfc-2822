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

extension RFC_2822.AddrSpec {
    /// Errors that can occur during addr-spec parsing and validation
    ///
    /// RFC 2822 Section 3.4.1 defines addr-spec as local-part@domain
    public enum Error: Swift.Error, Sendable, Equatable {
        /// Input is empty
        case empty

        /// Missing @ separator between local-part and domain
        case missingAtSign(_ value: String)

        /// Local-part validation failed
        case invalidLocalPart(_ localPart: String)

        /// Domain validation failed
        case invalidDomain(_ domain: String)
    }
}

// MARK: - CustomStringConvertible

extension RFC_2822.AddrSpec.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .empty:
            return "Address specification cannot be empty"

        case .missingAtSign(let value):
            return "Missing '@' separator in '\(value)'"

        case .invalidLocalPart(let localPart):
            return
                "Invalid local-part '\(localPart)': must be dot-atom or quoted-string per RFC 2822"

        case .invalidDomain(let domain):
            return "Invalid domain '\(domain)': must be dot-atom or domain-literal per RFC 2822"
        }
    }
}
