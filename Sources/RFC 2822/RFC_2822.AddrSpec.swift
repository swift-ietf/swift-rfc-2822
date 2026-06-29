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

import ASCII_Serializer_Primitives
import INCITS_4_1986

extension RFC_2822 {
    /// RFC 2822 addr-spec (local-part@domain)
    ///
    /// Per RFC 2822 Section 3.4.1:
    /// ```
    /// addr-spec = local-part "@" domain
    /// local-part = dot-atom / quoted-string
    /// domain = dot-atom / domain-literal
    /// ```
    ///
    /// ## Example
    ///
    /// ```swift
    /// let addr = try RFC_2822.AddrSpec("user@example.com")
    /// ```
    ///
    /// ## See Also
    ///
    /// - [RFC 2822 Section 3.4.1](https://www.rfc-editor.org/rfc/rfc2822#section-3.4.1)
    public struct AddrSpec: Sendable, Codable {
        public let localPart: String
        public let domain: String

        /// Creates an addr-spec WITHOUT validation
        ///
        /// Private to ensure all public construction goes through validation.
        private init(
            __unchecked: Void,
            localPart: String,
            domain: String
        ) {
            self.localPart = localPart
            self.domain = domain
        }

        /// Creates an addr-spec with validation
        ///
        /// - Parameters:
        ///   - localPart: The local part (before @)
        ///   - domain: The domain part (after @)
        /// - Throws: `Error` if validation fails
        public init(
            localPart: String,
            domain: String
        ) throws(Error) {
            // Validate local-part
            guard !localPart.isEmpty else {
                throw Error.invalidLocalPart("")
            }
            let localCodes: [ASCII.Code]
            do {
                localCodes = try Array<ASCII.Code>(localPart.utf8)
            } catch {
                throw Error.invalidLocalPart(localPart)
            }
            try Self.validateLocalPart(localCodes)

            // Validate domain
            guard !domain.isEmpty else {
                throw Error.invalidDomain("")
            }
            let domainCodes: [ASCII.Code]
            do {
                domainCodes = try Array<ASCII.Code>(domain.utf8)
            } catch {
                throw Error.invalidDomain(domain)
            }
            try Self.validateDomain(domainCodes)

            self.init(__unchecked: (), localPart: localPart, domain: domain)
        }
    }
}

// MARK: - Hashable

extension RFC_2822.AddrSpec: Hashable {
    public func hash(into hasher: inout Hasher) {
        // RFC 2822 local-part is case-sensitive, domain is case-insensitive
        hasher.combine(localPart)
        hasher.combine(domain.lowercased())
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.localPart == rhs.localPart && lhs.domain.lowercased() == rhs.domain.lowercased()
    }
}

// MARK: - Binary.ASCII.Serializable

extension RFC_2822.AddrSpec: Binary.ASCII.Serializable {

    public static func serialize<Buffer>(
        ascii addrSpec: RFC_2822.AddrSpec,
        into buffer: inout Buffer
    ) where Buffer: RangeReplaceableCollection, Buffer.Element == Byte {
        buffer.reserveCapacity(
            buffer.count + addrSpec.localPart.utf8.count + 1 + addrSpec.domain.utf8.count)

        // local-part
        buffer.append(contentsOf: addrSpec.localPart.utf8)

        // @
        buffer.append(ASCII.Code.commercialAt)

        // domain
        buffer.append(contentsOf: addrSpec.domain.utf8)
    }

    /// Parses an addr-spec from ASCII bytes
    ///
    /// ## Category Theory
    ///
    /// Parsing transformation:
    /// - **Domain**: [Byte] (ASCII bytes)
    /// - **Codomain**: RFC_2822.AddrSpec (structured data)
    ///
    /// String parsing is derived composition:
    /// ```
    /// String → [Byte] (UTF-8) → AddrSpec
    /// ```
    ///
    /// ## RFC 2822 Section 3.4.1
    ///
    /// ```
    /// addr-spec = local-part "@" domain
    /// local-part = dot-atom / quoted-string
    /// domain = dot-atom / domain-literal
    /// ```
    ///
    /// - Parameter bytes: The addr-spec as ASCII bytes
    /// - Throws: `Error` if parsing or validation fails
    public init<Bytes: Collection>(ascii bytes: Bytes, in context: Void = ()) throws(Error)
    where Bytes.Element == Byte {
        guard !bytes.isEmpty else { throw Error.empty }

        // Find the @ separator (use last @ to handle quoted local-parts with @)
        var atIndex: Bytes.Index?
        for index in bytes.indices {
            if (try? ASCII.Code(bytes[index])) == ASCII.Code.commercialAt {
                atIndex = index
            }
        }

        guard let at = atIndex else {
            throw Error.missingAtSign(String(decoding: bytes, as: UTF8.self))
        }

        // Extract local-part and domain as slices (zero-copy)
        let localPartBytes = bytes[..<at]
        let domainBytes = bytes[bytes.index(after: at)...]

        guard !localPartBytes.isEmpty else {
            throw Error.invalidLocalPart("")
        }

        guard !domainBytes.isEmpty else {
            throw Error.invalidDomain("")
        }

        // Delegate to public validating init
        try self.init(
            localPart: String(decoding: localPartBytes, as: UTF8.self),
            domain: String(decoding: domainBytes, as: UTF8.self)
        )
    }
}

// MARK: - Validation Helpers

extension RFC_2822.AddrSpec {
    /// Validates a local-part per RFC 2822
    ///
    /// local-part = dot-atom / quoted-string
    private static func validateLocalPart<Codes: Collection>(
        _ codes: Codes
    ) throws(Error) where Codes.Element == ASCII.Code {
        guard let firstCode = codes.first else {
            throw Error.invalidLocalPart("")
        }

        // Get last code by iteration (avoids Array allocation)
        var lastCode = firstCode
        for code in codes { lastCode = code }

        if firstCode == ASCII.Code.quotationMark && lastCode == ASCII.Code.quotationMark {
            // Quoted-string format
            try validateQuotedString(codes, for: .localPart)
        } else {
            // Dot-atom format
            try validateDotAtom(codes, for: .localPart)
        }
    }

    /// Validates a domain per RFC 2822
    ///
    /// domain = dot-atom / domain-literal
    private static func validateDomain<Codes: Collection>(
        _ codes: Codes
    ) throws(Error) where Codes.Element == ASCII.Code {
        guard let firstCode = codes.first else {
            throw Error.invalidDomain("")
        }

        // Get last code by iteration (avoids Array allocation)
        var lastCode = firstCode
        for code in codes { lastCode = code }

        if firstCode == ASCII.Code.leftSquareBracket && lastCode == ASCII.Code.rightSquareBracket {
            // Domain-literal format
            try validateDomainLiteral(codes)
        } else {
            // Dot-atom format
            try validateDotAtom(codes, for: .domain)
        }
    }

    /// Part being validated (for error context)
    private enum Part {
        case localPart
        case domain
    }

    /// Validates a dot-atom
    ///
    /// dot-atom-text = 1*atext *("." 1*atext)
    private static func validateDotAtom<Codes: Collection>(
        _ codes: Codes,
        for part: Part
    ) throws(Error) where Codes.Element == ASCII.Code {
        guard let firstCode = codes.first else {
            throw errorFor(part, String(decoding: codes, as: UTF8.self))
        }

        // Get last code
        var lastCode = firstCode
        for code in codes { lastCode = code }

        // Cannot start or end with dot
        guard firstCode != ASCII.Code.period && lastCode != ASCII.Code.period else {
            throw errorFor(part, String(decoding: codes, as: UTF8.self))
        }

        // Validate each code
        var previousCode: ASCII.Code = ASCII.Code(0)
        for code in codes {
            // Check for consecutive dots
            if code == ASCII.Code.period && previousCode == ASCII.Code.period {
                throw errorFor(part, String(decoding: codes, as: UTF8.self))
            }
            previousCode = code

            // Period is allowed as separator
            if code == ASCII.Code.period { continue }

            // Must be atext
            guard RFC_2822.isAtext(code) else {
                throw errorFor(part, String(decoding: codes, as: UTF8.self))
            }
        }
    }

    /// Validates a quoted-string
    ///
    /// quoted-string = DQUOTE *qcontent DQUOTE
    /// qcontent = qtext / quoted-pair
    /// qtext = NO-WS-CTL / %d33 / %d35-91 / %d93-126
    private static func validateQuotedString<Codes: Collection>(
        _ codes: Codes,
        for part: Part
    ) throws(Error) where Codes.Element == ASCII.Code {
        var isEscaped = false
        var isFirst = true
        var codeCount = 0
        let totalCount = codes.count

        for code in codes {
            codeCount += 1

            // Skip first and last quotes
            if isFirst {
                isFirst = false
                continue
            }
            if codeCount == totalCount { continue }

            if isEscaped {
                isEscaped = false
            } else if code == ASCII.Code.reverseSolidus {
                isEscaped = true
            } else {
                // qtext validation: NO-WS-CTL / %d33 / %d35-91 / %d93-126
                let isValidQText =
                    (code >= 1 && code <= 8) || code == 11 || code == 12
                    || (code >= 14 && code <= 31) || code == 33 || (code >= 35 && code <= 91)
                    || (code >= 93 && code <= 126)
                guard isValidQText else {
                    throw errorFor(part, String(decoding: codes, as: UTF8.self))
                }
            }
        }

        if isEscaped {
            throw errorFor(part, String(decoding: codes, as: UTF8.self))
        }
    }

    /// Validates a domain-literal
    ///
    /// domain-literal = "[" *dcontent "]"
    /// dcontent = dtext / quoted-pair
    /// dtext = NO-WS-CTL / %d33-90 / %d94-126
    private static func validateDomainLiteral<Codes: Collection>(
        _ codes: Codes
    ) throws(Error) where Codes.Element == ASCII.Code {
        var isEscaped = false
        var isFirst = true
        var codeCount = 0
        let totalCount = codes.count

        for code in codes {
            codeCount += 1

            // Skip first and last brackets
            if isFirst {
                isFirst = false
                continue
            }
            if codeCount == totalCount { continue }

            if isEscaped {
                // Only certain characters can follow backslash
                guard
                    code == ASCII.Code.leftSquareBracket
                        || code == ASCII.Code.rightSquareBracket
                        || code == ASCII.Code.reverseSolidus
                else {
                    throw Error.invalidDomain(String(decoding: codes, as: UTF8.self))
                }
                isEscaped = false
            } else if code == ASCII.Code.reverseSolidus {
                isEscaped = true
            } else {
                // dtext validation: NO-WS-CTL / %d33-90 / %d94-126
                let isValidDText =
                    (code >= 1 && code <= 8) || code == 11 || code == 12
                    || (code >= 14 && code <= 31) || (code >= 33 && code <= 90)
                    || (code >= 94 && code <= 126)
                guard isValidDText else {
                    throw Error.invalidDomain(String(decoding: codes, as: UTF8.self))
                }
            }
        }

        if isEscaped {
            throw Error.invalidDomain(String(decoding: codes, as: UTF8.self))
        }
    }

    /// Returns the appropriate error for the part being validated
    private static func errorFor(_ part: Part, _ value: String) -> Error {
        switch part {
        case .localPart: return Error.invalidLocalPart(value)
        case .domain: return Error.invalidDomain(value)
        }
    }
}

// MARK: - Protocol Conformances

extension RFC_2822.AddrSpec: Binary.ASCII.RawRepresentable {
    public typealias RawValue = String
}

extension RFC_2822.AddrSpec: CustomStringConvertible {}
