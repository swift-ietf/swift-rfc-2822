//
//  RFC_2822.AddrSpec.Parse.swift
//  swift-rfc-2822
//
//  RFC 2822 addr-spec: local-part "@" domain
//

public import Parser_Primitives

extension RFC_2822.AddrSpec {
    /// Parses an RFC 2822 addr-spec.
    ///
    /// `addr-spec = local-part "@" domain`
    ///
    /// Where:
    /// - `local-part = dot-atom / quoted-string`
    /// - `domain = dot-atom / domain-literal`
    ///
    /// Returns raw byte slices for local-part and domain.
    public struct Parse<Input: Collection.Slice.`Protocol`>: Sendable
    where Input: Sendable, Input.Element == UInt8 {
        @inlinable
        public init() {}
    }
}

extension RFC_2822.AddrSpec.Parse: Parser.`Protocol` {
    public typealias Failure = RFC_2822.AddrSpec.Parse<Input>.Error
    public typealias Body = Never

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        guard input.startIndex < input.endIndex else { throw .empty }

        // Handle quoted local-part
        var localEnd: Input.Index
        if input[input.startIndex] == 0x22 {  // "
            // Scan past quoted-string
            var idx = input.index(after: input.startIndex)
            var escaped = false
            while idx < input.endIndex {
                let byte = input[idx]
                if escaped {
                    escaped = false
                } else if byte == 0x5C {
                    escaped = true
                } else if byte == 0x22 {  // closing "
                    input.formIndex(after: &idx)
                    break
                }
                input.formIndex(after: &idx)
            }
            localEnd = idx
        } else {
            // dot-atom: scan until '@'
            localEnd = input.startIndex
            while localEnd < input.endIndex && input[localEnd] != 0x40 {
                input.formIndex(after: &localEnd)
            }
        }

        guard localEnd > input.startIndex else { throw .emptyLocalPart }

        // Expect '@'
        guard localEnd < input.endIndex, input[localEnd] == 0x40 else {
            throw .missingAtSign
        }

        let localPart = input[input.startIndex..<localEnd]
        let afterAt = input.index(after: localEnd)

        // Domain is the rest (until whitespace, comma, '>', or end)
        var domainEnd = afterAt
        while domainEnd < input.endIndex {
            let byte = input[domainEnd]
            if byte == 0x20 || byte == 0x09 || byte == 0x2C
                || byte == 0x3E || byte == 0x0D || byte == 0x0A
            {
                break
            }
            input.formIndex(after: &domainEnd)
        }

        guard domainEnd > afterAt else { throw .emptyDomain }

        let domain = input[afterAt..<domainEnd]
        input = input[domainEnd...]

        return Output(localPart: localPart, domain: domain)
    }
}
