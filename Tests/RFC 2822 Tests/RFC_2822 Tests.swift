//
//  RFC_2822 Tests.swift
//  swift-rfc-2822
//
//  Created by Coen ten Thije Boonkkamp on 26/12/2024.
//

import Foundation
import Testing

@testable import RFC_2822

// MARK: - AddrSpec Tests

extension RFC_2822.AddrSpec {
    @Suite("RFC 2822 AddrSpec Tests")
    struct Test {
        @Test
        func `Successfully creates valid addr-spec`() throws {
            let addr = try RFC_2822.AddrSpec(ascii: Array("user@example.com".utf8))
            #expect(addr.localPart == "user")
            #expect(addr.domain == "example.com")
        }

        @Test
        func `Successfully creates addr-spec with subdomain`() throws {
            let addr = try RFC_2822.AddrSpec(ascii: Array("user@mail.example.com".utf8))
            #expect(addr.localPart == "user")
            #expect(addr.domain == "mail.example.com")
        }

        @Test
        func `Successfully creates addr-spec with dots in local part`() throws {
            let addr = try RFC_2822.AddrSpec(ascii: Array("first.last@example.com".utf8))
            #expect(addr.localPart == "first.last")
        }

        @Test
        func `Successfully creates addr-spec with plus sign`() throws {
            let addr = try RFC_2822.AddrSpec(ascii: Array("user+tag@example.com".utf8))
            #expect(addr.localPart == "user+tag")
        }

        @Test
        func `Successfully creates addr-spec with hyphen`() throws {
            let addr = try RFC_2822.AddrSpec(ascii: Array("user-name@example.com".utf8))
            #expect(addr.localPart == "user-name")
        }

        @Test
        func `Successfully creates addr-spec with quoted local part`() throws {
            // Quoted string with valid qtext (no spaces - space requires FWS handling)
            let addr = try RFC_2822.AddrSpec(ascii: Array("\"user.name\"@example.com".utf8))
            #expect(addr.localPart == "\"user.name\"")
        }

        @Test
        func `Successfully creates addr-spec with domain literal`() throws {
            let addr = try RFC_2822.AddrSpec(ascii: Array("user@[192.168.1.1]".utf8))
            #expect(addr.domain == "[192.168.1.1]")
        }

        @Test
        func `Fails with empty input`() throws {
            #expect(throws: RFC_2822.AddrSpec.Error.empty) {
                _ = try RFC_2822.AddrSpec(ascii: Array("".utf8))
            }
        }

        @Test
        func `Fails with missing @ sign`() throws {
            #expect(throws: RFC_2822.AddrSpec.Error.self) {
                _ = try RFC_2822.AddrSpec(ascii: Array("userexample.com".utf8))
            }
        }

        @Test
        func `Fails with empty local part`() throws {
            #expect(throws: RFC_2822.AddrSpec.Error.self) {
                _ = try RFC_2822.AddrSpec(ascii: Array("@example.com".utf8))
            }
        }

        @Test
        func `Fails with empty domain`() throws {
            #expect(throws: RFC_2822.AddrSpec.Error.self) {
                _ = try RFC_2822.AddrSpec(ascii: Array("user@".utf8))
            }
        }

        @Test
        func `Fails with local part starting with dot`() throws {
            #expect(throws: RFC_2822.AddrSpec.Error.self) {
                _ = try RFC_2822.AddrSpec(ascii: Array(".user@example.com".utf8))
            }
        }

        @Test
        func `Fails with local part ending with dot`() throws {
            #expect(throws: RFC_2822.AddrSpec.Error.self) {
                _ = try RFC_2822.AddrSpec(ascii: Array("user.@example.com".utf8))
            }
        }

        @Test
        func `Fails with consecutive dots in local part`() throws {
            #expect(throws: RFC_2822.AddrSpec.Error.self) {
                _ = try RFC_2822.AddrSpec(ascii: Array("user..name@example.com".utf8))
            }
        }

        @Test
        func `Successfully tests equality`() throws {
            let addr1 = try RFC_2822.AddrSpec(ascii: Array("user@example.com".utf8))
            let addr2 = try RFC_2822.AddrSpec(ascii: Array("user@example.com".utf8))
            let addr3 = try RFC_2822.AddrSpec(ascii: Array("other@example.com".utf8))
            #expect(addr1 == addr2)
            #expect(addr1 != addr3)
        }

        @Test
        func `Successfully tests case-insensitive domain equality`() throws {
            let addr1 = try RFC_2822.AddrSpec(ascii: Array("user@EXAMPLE.COM".utf8))
            let addr2 = try RFC_2822.AddrSpec(ascii: Array("user@example.com".utf8))
            #expect(addr1 == addr2)
        }

        @Test
        func `Successfully tests hashable`() throws {
            var set: Set<RFC_2822.AddrSpec> = []
            set.insert(try RFC_2822.AddrSpec(ascii: Array("user@example.com".utf8)))
            set.insert(try RFC_2822.AddrSpec(ascii: Array("user@example.com".utf8)))  // Duplicate
            set.insert(try RFC_2822.AddrSpec(ascii: Array("other@example.com".utf8)))
            #expect(set.count == 2)
        }

        @Test
        func `Successfully encodes and decodes`() throws {
            let original = try RFC_2822.AddrSpec(ascii: Array("user@example.com".utf8))
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(RFC_2822.AddrSpec.self, from: encoded)
            #expect(original == decoded)
        }

        @Test
        func `Successfully serializes to string`() throws {
            let addr = try RFC_2822.AddrSpec(ascii: Array("user@example.com".utf8))
            #expect(String(addr) == "user@example.com")
        }
    }
}

extension RFC_2822.AddrSpec.Test {
    /// F-002 residual-bypass audit (revision 1): investigated whether
    /// `AddrSpec`'s Codable decode could bypass `validateLocalPart`/
    /// `validateDomain` the way the adversarial pre-review described for
    /// `Mailbox` (a compiler-synthesized, dictionary-shaped `init(from:)`
    /// assigning stored properties straight from untrusted JSON). It
    /// cannot: `AddrSpec` also conforms to `Swift.RawRepresentable`
    /// (`RawValue == String`), so its `Codable` conformance resolves to the
    /// Swift standard library's raw-value-based witness instead of
    /// per-property synthesis — CONFIRMED empirically
    /// (`JSONEncoder().encode(addrSpec)` produces a bare JSON string, not
    /// `{"localPart":...,"domain":...}`). Decoding a bare string routes
    /// through `init?(rawValue:)` -> `self.init(ascii:)`, which was ALREADY
    /// fully grammar-validating before this revision. These tests exercise
    /// the REAL decode path and pass both before and after this revision —
    /// recorded as a confirmed-safe finding, not a red -> green regression.
    @Suite
    struct `Edge Case` {
        @Test
        func `Rejects a Codable-decoded raw string carrying a CRLF header-injection payload`() throws {
            let json = Data(
                """
                "user\\r\\nBcc: attacker@evil.example@example.com"
                """.utf8
            )
            #expect(throws: (any Swift.Error).self) {
                _ = try JSONDecoder().decode(RFC_2822.AddrSpec.self, from: json)
            }
        }

        @Test
        func `Rejects a dictionary-shaped payload — never the real wire shape to begin with`() throws {
            // A `{"localPart":...,"domain":...}` object is what naive
            // per-property Codable synthesis would use, and what the
            // adversarial-review claim assumed. It is rejected here too,
            // but only because it doesn't match the actual (raw-string)
            // wire shape — not because validation caught anything.
            let json = Data(
                """
                {"localPart":"user","domain":"example.com"}
                """.utf8
            )
            #expect(throws: (any Swift.Error).self) {
                _ = try JSONDecoder().decode(RFC_2822.AddrSpec.self, from: json)
            }
        }

        @Test
        func `Still decodes a well-formed raw string via Codable`() throws {
            let json = Data(
                """
                "user@example.com"
                """.utf8
            )
            let addr = try JSONDecoder().decode(RFC_2822.AddrSpec.self, from: json)
            #expect(addr.localPart == "user")
            #expect(addr.domain == "example.com")
        }
    }
}

// MARK: - Mailbox Tests

extension RFC_2822.Mailbox {
    @Suite("RFC 2822 Mailbox Tests")
    struct Test {
        @Test
        func `Successfully creates mailbox with just addr-spec`() throws {
            let mailbox = try RFC_2822.Mailbox(ascii: Array("user@example.com".utf8))
            #expect(mailbox.displayName == nil)
            #expect(mailbox.emailAddress.localPart == "user")
            #expect(mailbox.emailAddress.domain == "example.com")
        }

        @Test
        func `Successfully creates mailbox with display name`() throws {
            let mailbox = try RFC_2822.Mailbox(ascii: Array("John Doe <john@example.com>".utf8))
            #expect(mailbox.displayName == "John Doe")
            #expect(mailbox.emailAddress.localPart == "john")
        }

        @Test
        func `Successfully creates mailbox with quoted display name`() throws {
            let mailbox = try RFC_2822.Mailbox(
                ascii: Array("\"John Q. Doe\" <john@example.com>".utf8))
            #expect(mailbox.displayName == "John Q. Doe")
        }

        @Test
        func `Fails with empty input`() throws {
            #expect(throws: RFC_2822.Mailbox.Error.empty) {
                _ = try RFC_2822.Mailbox(ascii: Array("".utf8))
            }
        }

        @Test
        func `Fails with missing closing angle bracket`() throws {
            #expect(throws: RFC_2822.Mailbox.Error.self) {
                _ = try RFC_2822.Mailbox(ascii: Array("John <john@example.com".utf8))
            }
        }

        @Test
        func `Successfully tests equality`() throws {
            let m1 = try RFC_2822.Mailbox(ascii: Array("John <john@example.com>".utf8))
            let m2 = try RFC_2822.Mailbox(ascii: Array("John <john@example.com>".utf8))
            let m3 = try RFC_2822.Mailbox(ascii: Array("Jane <jane@example.com>".utf8))
            #expect(m1 == m2)
            #expect(m1 != m3)
        }

        @Test
        func `Successfully tests hashable`() throws {
            var set: Set<RFC_2822.Mailbox> = []
            set.insert(try RFC_2822.Mailbox(ascii: Array("john@example.com".utf8)))
            set.insert(try RFC_2822.Mailbox(ascii: Array("john@example.com".utf8)))
            set.insert(try RFC_2822.Mailbox(ascii: Array("jane@example.com".utf8)))
            #expect(set.count == 2)
        }

        @Test
        func `Successfully encodes and decodes`() throws {
            let original = try RFC_2822.Mailbox(ascii: Array("John <john@example.com>".utf8))
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(RFC_2822.Mailbox.self, from: encoded)
            #expect(original == decoded)
        }

        @Test
        func `Successfully serializes to string`() throws {
            let mailbox = try RFC_2822.Mailbox(ascii: Array("John <john@example.com>".utf8))
            let serialized = String(mailbox)
            #expect(serialized.contains("john@example.com"))
        }
    }
}

extension RFC_2822.Mailbox.Test {
    /// F-002 regression coverage: display-name construction and parsing
    /// reject header injection (an embedded CR/LF that would let
    /// attacker-controlled input forge additional header lines), and the
    /// serializer quoted-pair escapes embedded `"` / `\` rather than
    /// emitting them bare inside the quoted-string.
    @Suite
    struct `Edge Case` {
        @Test
        func `Rejects a display name carrying a CRLF header-injection payload`() throws {
            #expect(throws: RFC_2822.Mailbox.Error.self) {
                _ = try RFC_2822.Mailbox(
                    displayName: "Evil\r\nBcc: attacker@evil.example",
                    emailAddress: try RFC_2822.AddrSpec(localPart: "user", domain: "example.com")
                )
            }
        }

        @Test
        func `Rejects a display name carrying a bare LF`() throws {
            #expect(throws: RFC_2822.Mailbox.Error.self) {
                _ = try RFC_2822.Mailbox(
                    displayName: "Evil\nHeader: injected",
                    emailAddress: try RFC_2822.AddrSpec(localPart: "user", domain: "example.com")
                )
            }
        }

        @Test
        func `Rejects a display name carrying a bare CR`() throws {
            #expect(throws: RFC_2822.Mailbox.Error.self) {
                _ = try RFC_2822.Mailbox(
                    displayName: "Evil\rHeader: injected",
                    emailAddress: try RFC_2822.AddrSpec(localPart: "user", domain: "example.com")
                )
            }
        }

        @Test
        func `Rejects a header-injection payload parsed from wire text too`() throws {
            // The same invariant holds on the ASCII.Parseable path, not just
            // the public initializer — a parse -> re-serialize round trip
            // must not be able to replay attacker-controlled bytes.
            let malicious = "Evil\r\nBcc: attacker@evil.example <john@example.com>"
            #expect(throws: RFC_2822.Mailbox.Error.self) {
                _ = try RFC_2822.Mailbox(ascii: Array(malicious.utf8))
            }
        }

        @Test
        func `Escapes embedded quote and backslash bytes when serializing a display name`() throws {
            let mailbox = try RFC_2822.Mailbox(
                displayName: "Say \"hi\" \\ folks",
                emailAddress: try RFC_2822.AddrSpec(localPart: "user", domain: "example.com")
            )
            #expect(
                String(mailbox)
                    == "\"Say \\\"hi\\\" \\\\ folks\" <user@example.com>"
            )
        }

        @Test
        func `A display name with embedded quotes still parses back after escaped serialization`() throws {
            let original = try RFC_2822.Mailbox(
                displayName: "Say \"hi\" \\ folks",
                emailAddress: try RFC_2822.AddrSpec(localPart: "user", domain: "example.com")
            )
            var ascii: [ASCII.Code] = []
            RFC_2822.Mailbox.serialize(original, into: &ascii)
            let reparsed = try RFC_2822.Mailbox(ascii: ascii.map(\.byte))
            #expect(reparsed.emailAddress == original.emailAddress)
        }

        // MARK: - F-002 residual-bypass audit (revision 1): the Codable
        // decode path
        //
        // An adversarial pre-review claimed `Mailbox`'s COMPILER-SYNTHESIZED
        // `init(from:)` assigned `displayName` directly from decoded
        // dictionary-shaped JSON (e.g. `{"displayName":"Evil\r\nBcc:
        // x@evil","emailAddress":{...}}`), never calling
        // `validateDisplayName`. Verifying this claim empirically (decoding
        // exactly that dictionary shape) shows it does NOT reproduce against
        // the actual branch: `Mailbox` also conforms to
        // `Swift.RawRepresentable` (`RawValue == String`, below), so its
        // real `Codable` conformance resolves to the Swift standard
        // library's raw-value-based witness instead of per-property
        // synthesis (CONFIRMED — `JSONEncoder().encode(mailbox)` produces a
        // bare string, e.g. `"John <john@example.com>"`, never the
        // dictionary shape). Decoding therefore already routes through
        // `init?(rawValue:)` -> `self.init(ascii:)`, the SAME wire-text
        // parser F-002 validated. These tests exercise the REAL decode path
        // (a bare JSON string) and the (never-real) dictionary shape, and
        // both pass before and after this revision — recorded as a
        // confirmed-safe finding, not a red -> green regression test.

        @Test
        func `Rejects a Codable-decoded raw string carrying a CRLF header-injection payload`() throws {
            let json = Data(
                """
                "Evil\\r\\nBcc: attacker@evil.example <john@example.com>"
                """.utf8
            )
            #expect(throws: (any Swift.Error).self) {
                _ = try JSONDecoder().decode(RFC_2822.Mailbox.self, from: json)
            }
        }

        @Test
        func `Rejects a Codable-decoded raw string carrying a bare LF`() throws {
            let json = Data(
                """
                "Evil\\nHeader: injected <john@example.com>"
                """.utf8
            )
            #expect(throws: (any Swift.Error).self) {
                _ = try JSONDecoder().decode(RFC_2822.Mailbox.self, from: json)
            }
        }

        @Test
        func `Rejects a Codable-decoded raw string carrying a bare CR`() throws {
            let json = Data(
                """
                "Evil\\rHeader: injected <john@example.com>"
                """.utf8
            )
            #expect(throws: (any Swift.Error).self) {
                _ = try JSONDecoder().decode(RFC_2822.Mailbox.self, from: json)
            }
        }

        @Test
        func `Rejects a dictionary-shaped payload — never the real wire shape to begin with`() throws {
            // The adversarial-review claim's exact hypothetical payload.
            // Rejected here too, but only because it doesn't match the
            // actual (raw-string) wire shape, not because validation caught
            // the embedded CRLF specifically.
            let json = Data(
                """
                {"displayName":"Evil\\r\\nBcc: attacker@evil.example","emailAddress":{"localPart":"user","domain":"example.com"}}
                """.utf8
            )
            #expect(throws: (any Swift.Error).self) {
                _ = try JSONDecoder().decode(RFC_2822.Mailbox.self, from: json)
            }
        }

        @Test
        func `Still decodes a well-formed raw string via Codable`() throws {
            let json = Data(
                """
                "John Doe <john@example.com>"
                """.utf8
            )
            let mailbox = try JSONDecoder().decode(RFC_2822.Mailbox.self, from: json)
            #expect(mailbox.displayName == "John Doe")
            #expect(mailbox.emailAddress.localPart == "john")
        }
    }
}

// MARK: - Address Tests

extension RFC_2822.Address {
    @Suite("RFC 2822 Address Tests")
    struct Test {
        @Test
        func `Successfully creates mailbox address`() throws {
            let address = try RFC_2822.Address(ascii: Array("user@example.com".utf8))
            if case .mailbox(let mailbox) = address.kind {
                #expect(mailbox.emailAddress.localPart == "user")
            } else {
                Issue.record("Expected mailbox address")
            }
        }

        @Test
        func `Successfully creates group address`() throws {
            let address = try RFC_2822.Address(
                ascii: Array("Team: john@example.com, jane@example.com;".utf8))
            if case .group(let name, let mailboxes) = address.kind {
                #expect(name == "Team")
                #expect(mailboxes.count == 2)
            } else {
                Issue.record("Expected group address")
            }
        }

        @Test
        func `Successfully creates empty group`() throws {
            let address = try RFC_2822.Address(ascii: Array("Empty Group:;".utf8))
            if case .group(let name, let mailboxes) = address.kind {
                #expect(name == "Empty Group")
                #expect(mailboxes.isEmpty)
            } else {
                Issue.record("Expected group address")
            }
        }

        @Test
        func `Fails with empty input`() throws {
            #expect(throws: RFC_2822.Address.Error.empty) {
                _ = try RFC_2822.Address(ascii: Array("".utf8))
            }
        }

        @Test
        func `Fails with missing group terminator`() throws {
            #expect(throws: RFC_2822.Address.Error.self) {
                _ = try RFC_2822.Address(ascii: Array("Team: john@example.com".utf8))
            }
        }

        @Test
        func `Successfully tests equality`() throws {
            let a1 = try RFC_2822.Address(ascii: Array("user@example.com".utf8))
            let a2 = try RFC_2822.Address(ascii: Array("user@example.com".utf8))
            let a3 = try RFC_2822.Address(ascii: Array("other@example.com".utf8))
            #expect(a1 == a2)
            #expect(a1 != a3)
        }

        @Test
        func `Successfully encodes and decodes`() throws {
            let original = try RFC_2822.Address(ascii: Array("user@example.com".utf8))
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(RFC_2822.Address.self, from: encoded)
            #expect(original == decoded)
        }
    }
}

extension RFC_2822.Address.Test {
    /// F-005 regression coverage: the group-vs-mailbox `":"` scan is
    /// quote-aware, so a colon embedded in a quoted display name is not
    /// mistaken for the `display-name ":" mailbox-list ";"` group separator.
    ///
    /// Also carries F-002 residual-bypass audit coverage: `Address.Kind`'s
    /// `group` case holds its own display-name `String`, independent of
    /// `Mailbox.displayName`, validated by neither the `ASCII.Parseable`
    /// wire parser nor the compiler-synthesized `Decodable` pre-fix — and
    /// `Address`'s serializers apply NO escaping to it at all (not even the
    /// quoted-pair escaping `Mailbox` applies). See the tests below this
    /// suite's F-005 cases.
    @Suite
    struct `Edge Case` {
        @Test
        func `Parses a bare mailbox whose quoted display name contains a colon`() throws {
            let address = try RFC_2822.Address(
                ascii: Array("\"Time: 5pm\" <john@example.com>".utf8)
            )
            guard case .mailbox(let mailbox) = address.kind else {
                Issue.record("Expected a mailbox address, got a group")
                return
            }
            #expect(mailbox.displayName == "Time: 5pm")
            #expect(mailbox.emailAddress.localPart == "john")
        }

        @Test
        func `Still parses a real group when the display name has no colon`() throws {
            let address = try RFC_2822.Address(
                ascii: Array("Team: john@example.com, jane@example.com;".utf8)
            )
            guard case .group(let name, let mailboxes) = address.kind else {
                Issue.record("Expected a group address, got a mailbox")
                return
            }
            #expect(name == "Team")
            #expect(mailboxes.count == 2)
        }

        // MARK: - F-002 residual-bypass audit (revision 1): Address.Kind
        // .group's own display name, on both the wire-parse and
        // Codable-decode paths.
        //
        // Two DIFFERENT decode surfaces exist here, and they needed two
        // different fixes:
        //  1. `RFC_2822.Address` itself is `Swift.RawRepresentable`
        //     (`RawValue == String`), so `JSONDecoder().decode(Address.self,
        //     from:)` decodes a bare JSON string and routes through
        //     `init?(rawValue:)` -> `self.init(ascii:)` — this is a REAL
        //     bypass this revision fixes: `init(ascii:)`'s group branch had
        //     NO display-name validation pre-revision (unrelated to F-002's
        //     original `Mailbox`-only scope). Tests below decode a bare
        //     string and assert rejection.
        //  2. `RFC_2822.Address.Kind` is NOT `RawRepresentable`, so a BARE
        //     `Kind` value (e.g. `JSONDecoder().decode(Kind.self, from:)`,
        //     reachable if `Kind` is used as a payload anywhere without the
        //     `Address` wrapper) decodes via ordinary compiler-synthesized
        //     enum Codable — CONFIRMED empirically to use a keyed container
        //     with positional keys `_0`/`_1` under the case name (e.g.
        //     `{"group":{"_0":"Team","_1":[]}}`), and pre-revision this had
        //     NO validation at all for the `group` case's display name —
        //     the genuinely reachable, previously-unidentified bypass this
        //     revision closes. Tests below use that real shape.

        @Test
        func `Rejects a group display name carrying a CRLF header-injection payload parsed from wire text`() throws {
            // The group-separator colon must appear exactly once, right
            // before a well-formed mailbox list — a colon inside the
            // injected payload itself would be picked up as (the wrong)
            // group separator and fail for an unrelated reason (a malformed
            // mailbox-list fragment), which wouldn't actually demonstrate
            // the missing display-name validation this fixes.
            let malicious = "Evil\r\nBcc-attacker-evil-example:john@example.com;"
            #expect(throws: RFC_2822.Address.Error.self) {
                _ = try RFC_2822.Address(ascii: Array(malicious.utf8))
            }
        }

        @Test
        func `Rejects a Codable-decoded Address raw string whose group display name carries CRLF`() throws {
            // Same single-colon shape as the wire-parse test above, for the
            // same reason (an ambiguous second colon would fail for an
            // unrelated malformed-mailbox-list reason instead).
            let json = Data(
                """
                "Evil\\r\\nBcc-attacker-evil-example:john@example.com;"
                """.utf8
            )
            #expect(throws: (any Swift.Error).self) {
                _ = try JSONDecoder().decode(RFC_2822.Address.self, from: json)
            }
        }

        @Test
        func `Still decodes a well-formed Address raw string via Codable`() throws {
            let json = Data(
                """
                "Team: john@example.com;"
                """.utf8
            )
            let address = try JSONDecoder().decode(RFC_2822.Address.self, from: json)
            guard case .group(let name, let mailboxes) = address.kind else {
                Issue.record("Expected a group address, got a mailbox")
                return
            }
            #expect(name == "Team")
            #expect(mailboxes.count == 1)
        }

        @Test
        func `Rejects a Codable-decoded bare Kind whose group display name carries a CRLF header-injection payload`() throws {
            let json = Data(
                """
                {"group":{"_0":"Evil\\r\\nBcc: attacker@evil.example","_1":[]}}
                """.utf8
            )
            #expect(throws: (any Swift.Error).self) {
                _ = try JSONDecoder().decode(RFC_2822.Address.Kind.self, from: json)
            }
        }

        @Test
        func `Rejects a Codable-decoded bare Kind whose group display name carries a bare LF`() throws {
            let json = Data(
                """
                {"group":{"_0":"Evil\\nHeader: injected","_1":[]}}
                """.utf8
            )
            #expect(throws: (any Swift.Error).self) {
                _ = try JSONDecoder().decode(RFC_2822.Address.Kind.self, from: json)
            }
        }

        @Test
        func `Rejects a Codable-decoded bare Kind whose group display name carries a bare CR`() throws {
            let json = Data(
                """
                {"group":{"_0":"Evil\\rHeader: injected","_1":[]}}
                """.utf8
            )
            #expect(throws: (any Swift.Error).self) {
                _ = try JSONDecoder().decode(RFC_2822.Address.Kind.self, from: json)
            }
        }

        @Test
        func `Still decodes a well-formed bare Kind group via Codable`() throws {
            let json = Data(
                """
                {"group":{"_0":"Team","_1":[]}}
                """.utf8
            )
            let kind = try JSONDecoder().decode(RFC_2822.Address.Kind.self, from: json)
            guard case .group(let name, let mailboxes) = kind else {
                Issue.record("Expected a group, got a mailbox")
                return
            }
            #expect(name == "Team")
            #expect(mailboxes.isEmpty)
        }

        @Test
        func `Still decodes a well-formed bare Kind mailbox via Codable`() throws {
            let json = Data(
                """
                {"mailbox":{"_0":"John <john@example.com>"}}
                """.utf8
            )
            let kind = try JSONDecoder().decode(RFC_2822.Address.Kind.self, from: json)
            guard case .mailbox(let mailbox) = kind else {
                Issue.record("Expected a mailbox, got a group")
                return
            }
            #expect(mailbox.displayName == "John")
        }
    }
}

// MARK: - Message.ID Tests

extension RFC_2822.Message.ID {
    @Suite("RFC 2822 Message.ID Tests")
    struct Test {
        // MARK: - [FAM-012] Format Sibling Tests (drain → flat siblings)

        @Test
        func `ASCII and Binary serialization are byte-equivalent`() throws {
            // Escape/encode drain conformer: the two format-sibling bodies — the
            // ASCII.Serializable text verb (ASCII.Code) and the Binary.Serializable
            // wire verb (Byte) — MUST produce byte-identical output. This guards the
            // two independent (no-`.serialized`-detour) bodies against drift.
            let ids = [
                try RFC_2822.Message.ID(ascii: Array("<unique-id@example.com>".utf8)),
                try RFC_2822.Message.ID(ascii: Array("<abc.def.123@mail.example.com>".utf8)),
                RFC_2822.Message.ID(idLeft: "plain", idRight: "host.example"),
            ]
            for id in ids {
                var ascii: [ASCII.Code] = []
                RFC_2822.Message.ID.serialize(id, into: &ascii)
                var wire: [Byte] = []
                RFC_2822.Message.ID.serialize(id, into: &wire)
                #expect(ascii.map(\.byte) == wire)
            }
        }

        @Test
        func `round-trips through the ASCII verb and the parse init`() throws {
            let original = RFC_2822.Message.ID(idLeft: "abc", idRight: "example.com")
            var ascii: [ASCII.Code] = []
            RFC_2822.Message.ID.serialize(original, into: &ascii)
            let reparsed = try RFC_2822.Message.ID(ascii: ascii.map(\.byte))
            #expect(reparsed == original)
            #expect(reparsed.description == "<abc@example.com>")
        }

        @Test
        func `Successfully creates valid message ID`() throws {
            let id = try RFC_2822.Message.ID(ascii: Array("<unique-id@example.com>".utf8))
            #expect(id.idLeft == "unique-id")
            #expect(id.idRight == "example.com")
        }

        @Test
        func `Successfully creates message ID with dots`() throws {
            let id = try RFC_2822.Message.ID(ascii: Array("<abc.def.123@mail.example.com>".utf8))
            #expect(id.idLeft == "abc.def.123")
            #expect(id.idRight == "mail.example.com")
        }

        @Test
        func `Successfully creates message ID with whitespace around it`() throws {
            let id = try RFC_2822.Message.ID(ascii: Array("  <id@example.com>  ".utf8))
            #expect(id.idLeft == "id")
            #expect(id.idRight == "example.com")
        }

        @Test
        func `Fails with empty input`() throws {
            #expect(throws: RFC_2822.Message.ID.Error.empty) {
                _ = try RFC_2822.Message.ID(ascii: Array("".utf8))
            }
        }

        @Test
        func `Fails with missing angle brackets`() throws {
            #expect(throws: RFC_2822.Message.ID.Error.self) {
                _ = try RFC_2822.Message.ID(ascii: Array("id@example.com".utf8))
            }
        }

        @Test
        func `Fails with missing @ sign`() throws {
            #expect(throws: RFC_2822.Message.ID.Error.self) {
                _ = try RFC_2822.Message.ID(ascii: Array("<idexample.com>".utf8))
            }
        }

        @Test
        func `Fails with empty id-left`() throws {
            #expect(throws: RFC_2822.Message.ID.Error.self) {
                _ = try RFC_2822.Message.ID(ascii: Array("<@example.com>".utf8))
            }
        }

        @Test
        func `Fails with empty id-right`() throws {
            #expect(throws: RFC_2822.Message.ID.Error.self) {
                _ = try RFC_2822.Message.ID(ascii: Array("<id@>".utf8))
            }
        }

        @Test
        func `Successfully tests equality`() throws {
            let id1 = try RFC_2822.Message.ID(ascii: Array("<id@example.com>".utf8))
            let id2 = try RFC_2822.Message.ID(ascii: Array("<id@example.com>".utf8))
            let id3 = try RFC_2822.Message.ID(ascii: Array("<other@example.com>".utf8))
            #expect(id1 == id2)
            #expect(id1 != id3)
        }

        @Test
        func `Successfully tests case-insensitive id-right`() throws {
            let id1 = try RFC_2822.Message.ID(ascii: Array("<id@EXAMPLE.COM>".utf8))
            let id2 = try RFC_2822.Message.ID(ascii: Array("<id@example.com>".utf8))
            #expect(id1 == id2)
        }

        @Test
        func `Successfully tests hashable`() throws {
            var set: Set<RFC_2822.Message.ID> = []
            set.insert(try RFC_2822.Message.ID(ascii: Array("<id@example.com>".utf8)))
            set.insert(try RFC_2822.Message.ID(ascii: Array("<id@example.com>".utf8)))
            set.insert(try RFC_2822.Message.ID(ascii: Array("<other@example.com>".utf8)))
            #expect(set.count == 2)
        }

        @Test
        func `Successfully encodes and decodes`() throws {
            let original = try RFC_2822.Message.ID(ascii: Array("<id@example.com>".utf8))
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(RFC_2822.Message.ID.self, from: encoded)
            #expect(original == decoded)
        }

        @Test
        func `Successfully serializes to string`() throws {
            let id = try RFC_2822.Message.ID(ascii: Array("<unique-id@example.com>".utf8))
            #expect(String(id) == "<unique-id@example.com>")
        }
    }
}

// MARK: - Timestamp Tests

extension RFC_2822.Timestamp {
    @Suite("RFC 2822 Timestamp Tests")
    struct Test {
        @Test
        func `Timestamp creation`() {
            let timestamp = RFC_2822.Timestamp(secondsSinceEpoch: 0.0)
            #expect(timestamp.secondsSinceEpoch == 0.0)
        }

        @Test
        func `Timestamp equality`() {
            let timestamp1 = RFC_2822.Timestamp(secondsSinceEpoch: 1000.0)
            let timestamp2 = RFC_2822.Timestamp(secondsSinceEpoch: 1000.0)
            let timestamp3 = RFC_2822.Timestamp(secondsSinceEpoch: 2000.0)

            #expect(timestamp1 == timestamp2)
            #expect(timestamp1 != timestamp3)
        }

        @Test
        func `Timestamp hashable`() {
            var set: Set<RFC_2822.Timestamp> = []

            set.insert(RFC_2822.Timestamp(secondsSinceEpoch: 1000.0))
            set.insert(RFC_2822.Timestamp(secondsSinceEpoch: 1000.0))  // Duplicate
            set.insert(RFC_2822.Timestamp(secondsSinceEpoch: 2000.0))

            #expect(set.count == 2)
        }

        @Test
        func `Successfully parses timestamp from bytes`() throws {
            let timestamp = try RFC_2822.Timestamp(
                ascii: Array("Fri, 13 Feb 2009 23:31:30 +0000".utf8)
            )
            #expect(timestamp.secondsSinceEpoch == 1234567890.0)
        }

        @Test
        func `Successfully parses timestamp with whitespace`() throws {
            let timestamp = try RFC_2822.Timestamp(
                ascii: Array("  Fri, 13 Feb 2009 23:31:30 +0000  ".utf8)
            )
            #expect(timestamp.secondsSinceEpoch == 1234567890.0)
        }

        @Test
        func `Fails with empty input`() throws {
            #expect(throws: RFC_2822.Timestamp.Error.empty) {
                _ = try RFC_2822.Timestamp(ascii: Array("".utf8))
            }
        }

        @Test
        func `Fails with invalid format`() throws {
            #expect(throws: RFC_2822.Timestamp.Error.self) {
                _ = try RFC_2822.Timestamp(ascii: Array("not-a-number".utf8))
            }
        }

        @Test
        func `Successfully encodes and decodes`() throws {
            let original = RFC_2822.Timestamp(secondsSinceEpoch: 1234567890.0)
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(RFC_2822.Timestamp.self, from: encoded)
            #expect(original == decoded)
        }
    }
}

extension RFC_2822.Timestamp.Test {
    /// F-001 regression coverage: the wire form is the full RFC 2822
    /// Section 3.3 `date-time` grammar (day-of-week, date, time-of-day,
    /// zone) — not a bare numeric epoch — with `obs-zone` leniency and
    /// `obs-year` century normalization on parse.
    @Suite
    struct `Edge Case` {
        @Test
        func `Parses the RFC 2822 example date-time and recovers the correct epoch and fields`()
            throws
        {
            let timestamp = try RFC_2822.Timestamp(
                ascii: Array("Fri, 21 Nov 1997 09:55:06 -0600".utf8)
            )
            #expect(timestamp.secondsSinceEpoch == 880127706.0)
            #expect(timestamp.dayOfWeek == .friday)
            #expect(timestamp.day == 21)
            #expect(timestamp.month == .november)
            #expect(timestamp.year == 1997)
            #expect(timestamp.hour == 9)
            #expect(timestamp.minute == 55)
            #expect(timestamp.second == 6)
            #expect(timestamp.zone == .offset(minutes: -360))
        }

        @Test
        func `Round-trips a generated timestamp through serialize and parse`() throws {
            let original = RFC_2822.Timestamp(secondsSinceEpoch: 1_234_567_890)
            var ascii: [ASCII.Code] = []
            RFC_2822.Timestamp.serialize(original, into: &ascii)
            #expect(
                String(decoding: ascii.map(\.byte), as: UTF8.self)
                    == "Fri, 13 Feb 2009 23:31:30 +0000"
            )
            let reparsed = try RFC_2822.Timestamp(ascii: ascii.map(\.byte))
            #expect(reparsed.secondsSinceEpoch == original.secondsSinceEpoch)
        }

        @Test
        func `Applies obs-year two-digit century normalization`() throws {
            let timestamp = try RFC_2822.Timestamp(ascii: Array("21 Nov 97 09:55:06 GMT".utf8))
            #expect(timestamp.year == 1997)
            #expect(timestamp.secondsSinceEpoch == 880106106.0)
        }

        @Test
        func `Treats an unrecognized single-letter obs-zone as unknown, equivalent to -0000`()
            throws
        {
            let timestamp = try RFC_2822.Timestamp(ascii: Array("21 Nov 1997 09:55:06 Z".utf8))
            #expect(timestamp.zone == .unknown)
        }

        @Test
        func `Treats -0000 as unknown but +0000 as a known UTC offset`() throws {
            let unknown = try RFC_2822.Timestamp(ascii: Array("21 Nov 1997 09:55:06 -0000".utf8))
            let known = try RFC_2822.Timestamp(ascii: Array("21 Nov 1997 09:55:06 +0000".utf8))
            #expect(unknown.zone == .unknown)
            #expect(known.zone == .offset(minutes: 0))
            // Both denote the same instant regardless of the zone-knowledge distinction.
            #expect(unknown.secondsSinceEpoch == known.secondsSinceEpoch)
        }

        @Test
        func `Rejects a bare numeric epoch string (the pre-fix wire form)`() throws {
            #expect(throws: RFC_2822.Timestamp.Error.self) {
                _ = try RFC_2822.Timestamp(ascii: Array("1234567890".utf8))
            }
        }
    }
}

extension RFC_2822.Timestamp.Test {
    /// B2-19 (url-routing-stack-first-principles-review): this type retires
    /// swift-mailgun-types' hand-rolled `rfc2822Formatter`
    /// (`DateFormatter` with `"EEE, dd MMM yyyy HH:mm:ss Z"`, en_US_POSIX,
    /// GMT). These tests pin the mailgun wire shape: parse and print must
    /// round-trip that fixed-format form byte-identically.
    @Suite
    struct Integration {
        @Test
        func `Mailgun canonical UTC form round-trips byte-identically`() throws {
            let wire = "Fri, 13 Feb 2009 23:31:30 +0000"
            let parsed = try RFC_2822.Timestamp(ascii: Array(wire.utf8))
            #expect(parsed.description == wire)
            var bytes: [Byte] = []
            RFC_2822.Timestamp.serialize(parsed, into: &bytes)
            #expect(String(decoding: bytes, as: UTF8.self) == wire)
        }

        @Test
        func `Mailgun-shaped non-UTC offset form round-trips byte-identically`() throws {
            let wire = "Thu, 13 Oct 2011 18:02:00 +0200"
            let parsed = try RFC_2822.Timestamp(ascii: Array(wire.utf8))
            #expect(parsed.description == wire)
            #expect(parsed.zone == .offset(minutes: 120))
            let reparsed = try RFC_2822.Timestamp(ascii: Array(parsed.description.utf8))
            #expect(reparsed == parsed)
        }

        @Test
        func `Epoch-constructed timestamp prints the exact mailgun formatter output`() {
            // rfc2822Formatter.string(from: Date(timeIntervalSince1970: 1234567890))
            // == "Fri, 13 Feb 2009 23:31:30 +0000" (en_US_POSIX, GMT).
            let timestamp = RFC_2822.Timestamp(secondsSinceEpoch: 1_234_567_890)
            #expect(timestamp.description == "Fri, 13 Feb 2009 23:31:30 +0000")
        }
    }
}

// MARK: - Fields Tests

extension RFC_2822.Fields {
    @Suite("RFC 2822 Fields Tests")
    struct Test {
        @Test
        func `Successfully creates fields with required fields`() throws {
            let fields = RFC_2822.Fields(
                originationDate: RFC_2822.Timestamp(secondsSinceEpoch: 1_234_567_890),
                from: [
                    try RFC_2822.Mailbox(
                        displayName: nil,
                        emailAddress: try RFC_2822.AddrSpec(
                            localPart: "sender",
                            domain: "example.com"
                        )
                    )
                ]
            )
            #expect(fields.from.count == 1)
            #expect(fields.originationDate.secondsSinceEpoch == 1_234_567_890)
        }

        @Test
        func `Successfully creates fields with optional fields`() throws {
            let fields = RFC_2822.Fields(
                originationDate: RFC_2822.Timestamp(secondsSinceEpoch: 1_234_567_890),
                from: [
                    try RFC_2822.Mailbox(
                        displayName: "Sender",
                        emailAddress: try RFC_2822.AddrSpec(
                            localPart: "sender",
                            domain: "example.com"
                        )
                    )
                ],
                messageID: RFC_2822.Message.ID(idLeft: "unique", idRight: "example.com"),
                subject: "Test Subject"
            )
            #expect(fields.subject == "Test Subject")
            #expect(fields.messageID?.idLeft == "unique")
        }

        @Test
        func `Successfully parses fields from bytes`() throws {
            let raw =
                "Date: Fri, 13 Feb 2009 23:31:30 +0000\r\nFrom: sender@example.com\r\nSubject: Test"
            let fields = try RFC_2822.Fields(ascii: Array(raw.utf8))
            #expect(fields.subject == "Test")
            #expect(fields.from.count == 1)
            #expect(fields.originationDate.secondsSinceEpoch == 1234567890.0)
        }

        @Test
        func `Fails with empty input`() throws {
            #expect(throws: RFC_2822.Fields.Error.empty) {
                _ = try RFC_2822.Fields(ascii: Array("".utf8))
            }
        }

        @Test
        func `Fails with missing Date field`() throws {
            let raw = "From: sender@example.com\r\n"
            #expect(throws: RFC_2822.Fields.Error.self) {
                _ = try RFC_2822.Fields(ascii: Array(raw.utf8))
            }
        }

        @Test
        func `Fails with missing From field`() throws {
            let raw = "Date: Fri, 13 Feb 2009 23:31:30 +0000\r\n"
            #expect(throws: RFC_2822.Fields.Error.self) {
                _ = try RFC_2822.Fields(ascii: Array(raw.utf8))
            }
        }

        @Test
        func `Successfully tests equality`() throws {
            let f1 = RFC_2822.Fields(
                originationDate: RFC_2822.Timestamp(secondsSinceEpoch: 1000),
                from: [
                    try RFC_2822.Mailbox(
                        displayName: nil,
                        emailAddress: try RFC_2822.AddrSpec(
                            localPart: "a",
                            domain: "b.com"
                        )
                    )
                ]
            )
            let f2 = RFC_2822.Fields(
                originationDate: RFC_2822.Timestamp(secondsSinceEpoch: 1000),
                from: [
                    try RFC_2822.Mailbox(
                        displayName: nil,
                        emailAddress: try RFC_2822.AddrSpec(
                            localPart: "a",
                            domain: "b.com"
                        )
                    )
                ]
            )
            #expect(f1 == f2)
        }

        @Test
        func `Successfully encodes and decodes`() throws {
            let original = RFC_2822.Fields(
                originationDate: RFC_2822.Timestamp(secondsSinceEpoch: 1_234_567_890),
                from: [
                    try RFC_2822.Mailbox(
                        displayName: nil,
                        emailAddress: try RFC_2822.AddrSpec(
                            localPart: "test",
                            domain: "example.com"
                        )
                    )
                ],
                subject: "Test"
            )
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(RFC_2822.Fields.self, from: encoded)
            #expect(original == decoded)
        }
    }
}

extension RFC_2822.Fields.Test {
    /// F-005 regression coverage: comma-splitting a `From`/`To`/`Cc`/`Bcc`
    /// mailbox-address list is quote- and angle-addr-aware, so a comma
    /// embedded in a quoted display name does not fracture one mailbox into
    /// two bogus fragments.
    @Suite
    struct `Edge Case` {
        @Test
        func `Parses a single From mailbox whose quoted display name contains a comma`() throws {
            let raw =
                "Date: Fri, 13 Feb 2009 23:31:30 +0000\r\nFrom: \"Doe, John\" <john@example.com>\r\n"
            let fields = try RFC_2822.Fields(ascii: Array(raw.utf8))
            #expect(fields.from.count == 1)
            #expect(fields.from.first?.displayName == "Doe, John")
            #expect(fields.from.first?.emailAddress.localPart == "john")
        }

        @Test
        func `Parses a To list with two comma-bearing quoted display names as two mailboxes`()
            throws
        {
            let raw =
                "Date: Fri, 13 Feb 2009 23:31:30 +0000\r\nFrom: sender@example.com\r\n"
                + "To: \"Doe, John\" <john@example.com>, \"Roe, Jane\" <jane@example.com>\r\n"
            let fields = try RFC_2822.Fields(ascii: Array(raw.utf8))
            #expect(fields.to?.count == 2)
        }
    }
}

// MARK: - Message Tests

extension RFC_2822.Message {
    @Suite("RFC 2822 Message Tests")
    struct Test {
        @Test
        func `Successfully creates message with fields only`() throws {
            let fields = RFC_2822.Fields(
                originationDate: RFC_2822.Timestamp(secondsSinceEpoch: 1_234_567_890),
                from: [
                    try RFC_2822.Mailbox(
                        displayName: nil,
                        emailAddress: try RFC_2822.AddrSpec(
                            localPart: "sender",
                            domain: "example.com"
                        )
                    )
                ]
            )
            let message = RFC_2822.Message(fields: fields)
            #expect(message.body == nil)
        }

        @Test
        func `Successfully creates message with body`() throws {
            let fields = RFC_2822.Fields(
                originationDate: RFC_2822.Timestamp(secondsSinceEpoch: 1_234_567_890),
                from: [
                    try RFC_2822.Mailbox(
                        displayName: nil,
                        emailAddress: try RFC_2822.AddrSpec(
                            localPart: "sender",
                            domain: "example.com"
                        )
                    )
                ]
            )
            let message = RFC_2822.Message(fields: fields, body: "Hello, World!")
            #expect(message.body != nil)
        }

        @Test
        func `Successfully parses message from bytes`() throws {
            let raw =
                "Date: Fri, 13 Feb 2009 23:31:30 +0000\r\nFrom: sender@example.com\r\nSubject: Test\r\n\r\nThis is the body."
            let message = try RFC_2822.Message(binary: Array(raw.utf8))
            #expect(message.fields.subject == "Test")
            #expect(message.body != nil)
        }

        @Test
        func `Successfully parses message without body`() throws {
            let raw = "Date: Fri, 13 Feb 2009 23:31:30 +0000\r\nFrom: sender@example.com"
            let message = try RFC_2822.Message(binary: Array(raw.utf8))
            #expect(message.body == nil)
        }

        @Test
        func `Fails with empty input`() throws {
            #expect(throws: RFC_2822.Message.Error.empty) {
                _ = try RFC_2822.Message(binary: Array("".utf8))
            }
        }

        @Test
        func `Successfully tests equality`() throws {
            let fields = RFC_2822.Fields(
                originationDate: RFC_2822.Timestamp(secondsSinceEpoch: 1000),
                from: [
                    try RFC_2822.Mailbox(
                        displayName: nil,
                        emailAddress: try RFC_2822.AddrSpec(
                            localPart: "a",
                            domain: "b.com"
                        )
                    )
                ]
            )
            let m1 = RFC_2822.Message(fields: fields, body: "test")
            let m2 = RFC_2822.Message(fields: fields, body: "test")
            #expect(m1 == m2)
        }

        @Test
        func `Successfully encodes and decodes`() throws {
            let fields = RFC_2822.Fields(
                originationDate: RFC_2822.Timestamp(secondsSinceEpoch: 1_234_567_890),
                from: [
                    try RFC_2822.Mailbox(
                        displayName: nil,
                        emailAddress: try RFC_2822.AddrSpec(
                            localPart: "test",
                            domain: "example.com"
                        )
                    )
                ]
            )
            let original = RFC_2822.Message(fields: fields)
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(RFC_2822.Message.self, from: encoded)
            #expect(original.fields.originationDate == decoded.fields.originationDate)
            #expect(original.fields.from.count == decoded.fields.from.count)
            #expect(decoded.body == nil)
        }
    }
}

// MARK: - Message.Body Tests

extension RFC_2822.Message.Body {
    @Suite("RFC 2822 Message.Body Tests")
    struct Test {
        @Test
        func `Successfully creates body from string`() {
            let body = RFC_2822.Message.Body("Hello, World!")
            #expect(String(body) == "Hello, World!")
        }

        @Test
        func `Successfully creates body from bytes`() {
            let bytes: [Byte] = [72, 101, 108, 108, 111]  // "Hello"
            let body = RFC_2822.Message.Body(bytes)
            #expect(body.bytes == bytes)
        }

        @Test
        func `Successfully creates body using string literal`() {
            let body: RFC_2822.Message.Body = "Test body"
            #expect(String(body) == "Test body")
        }

        @Test
        func `Successfully parses body from raw bytes`() {
            let body = RFC_2822.Message.Body(binary: Array("Test content".utf8))
            #expect(String(body) == "Test content")
        }

        @Test
        func `Successfully tests equality`() {
            let b1 = RFC_2822.Message.Body("Hello")
            let b2 = RFC_2822.Message.Body("Hello")
            let b3 = RFC_2822.Message.Body("World")
            #expect(b1 == b2)
            #expect(b1 != b3)
        }

        @Test
        func `Successfully tests hashable`() {
            var set: Set<RFC_2822.Message.Body> = []
            set.insert(RFC_2822.Message.Body("Hello"))
            set.insert(RFC_2822.Message.Body("Hello"))
            set.insert(RFC_2822.Message.Body("World"))
            #expect(set.count == 2)
        }

        @Test
        func `Successfully encodes and decodes`() throws {
            let original = RFC_2822.Message.Body("Test body content")
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(RFC_2822.Message.Body.self, from: encoded)
            #expect(original == decoded)
        }
    }
}

// MARK: - [FAM-012] ASCII==Binary Equivalence

/// Each dual-sibling conformer's `ASCII.Serializable` verb (emitting `ASCII.Code`)
/// and `Binary.Serializable` verb (emitting `Byte`) MUST produce byte-identical
/// output. With strict clause-9 composition, this holds through every nesting
/// level — the guard against the two independent bodies drifting apart. (`Body`
/// and `Message` are byte-domain / `Binary`-only, so they have no ASCII verb to
/// compare and are excluded by construction.)
@Suite("RFC 2822 [FAM-012] ASCII==Binary Equivalence")
struct ASCIIBinaryEquivalenceTests {
    private func addrSpec() throws -> RFC_2822.AddrSpec {
        try RFC_2822.AddrSpec(localPart: "john", domain: "example.com")
    }
    private func mailbox() throws -> RFC_2822.Mailbox {
        // Display name with a comma forces the quoting (escape) path.
        try RFC_2822.Mailbox(displayName: "Doe, John", emailAddress: try addrSpec())
    }

    @Test func `AddrSpec verbs agree`() throws {
        let value = try RFC_2822.AddrSpec(localPart: "user", domain: "example.com")
        var ascii: [ASCII.Code] = []
        RFC_2822.AddrSpec.serialize(value, into: &ascii)
        var wire: [Byte] = []
        RFC_2822.AddrSpec.serialize(value, into: &wire)
        #expect(ascii.map(\.byte) == wire)
    }

    @Test func `Timestamp verbs agree`() {
        let value = RFC_2822.Timestamp(secondsSinceEpoch: 1_234_567_890)
        var ascii: [ASCII.Code] = []
        RFC_2822.Timestamp.serialize(value, into: &ascii)
        var wire: [Byte] = []
        RFC_2822.Timestamp.serialize(value, into: &wire)
        #expect(ascii.map(\.byte) == wire)
    }

    @Test func `NameValuePair verbs agree`() {
        let value = RFC_2822.Message.Received.NameValuePair(name: "from", value: "mail.example.com")
        var ascii: [ASCII.Code] = []
        RFC_2822.Message.Received.NameValuePair.serialize(value, into: &ascii)
        var wire: [Byte] = []
        RFC_2822.Message.Received.NameValuePair.serialize(value, into: &wire)
        #expect(ascii.map(\.byte) == wire)
    }

    @Test func `Mailbox verbs agree (escaped display name)`() throws {
        let value = try mailbox()
        var ascii: [ASCII.Code] = []
        RFC_2822.Mailbox.serialize(value, into: &ascii)
        var wire: [Byte] = []
        RFC_2822.Mailbox.serialize(value, into: &wire)
        #expect(ascii.map(\.byte) == wire)
    }

    @Test func `Message.Path verbs agree`() throws {
        let value = RFC_2822.Message.Path(addrSpec: try addrSpec())
        var ascii: [ASCII.Code] = []
        RFC_2822.Message.Path.serialize(value, into: &ascii)
        var wire: [Byte] = []
        RFC_2822.Message.Path.serialize(value, into: &wire)
        #expect(ascii.map(\.byte) == wire)
    }

    @Test func `Address verbs agree (group)`() throws {
        let value = RFC_2822.Address(.group("Team", [try mailbox(), try mailbox()]))
        var ascii: [ASCII.Code] = []
        RFC_2822.Address.serialize(value, into: &ascii)
        var wire: [Byte] = []
        RFC_2822.Address.serialize(value, into: &wire)
        #expect(ascii.map(\.byte) == wire)
    }

    @Test func `Message.Received verbs agree`() throws {
        let value = RFC_2822.Message.Received(
            tokens: [
                RFC_2822.Message.Received.NameValuePair(name: "from", value: "mx.example.org")
            ],
            timestamp: RFC_2822.Timestamp(secondsSinceEpoch: 1_234_567_890)
        )
        var ascii: [ASCII.Code] = []
        RFC_2822.Message.Received.serialize(value, into: &ascii)
        var wire: [Byte] = []
        RFC_2822.Message.Received.serialize(value, into: &wire)
        #expect(ascii.map(\.byte) == wire)
    }

    @Test func `Message.ResentBlock verbs agree`() throws {
        let value = RFC_2822.Message.ResentBlock(
            timestamp: RFC_2822.Timestamp(secondsSinceEpoch: 1_234_567_890),
            from: [try mailbox()],
            to: [RFC_2822.Address(.mailbox(try mailbox()))]
        )
        var ascii: [ASCII.Code] = []
        RFC_2822.Message.ResentBlock.serialize(value, into: &ascii)
        var wire: [Byte] = []
        RFC_2822.Message.ResentBlock.serialize(value, into: &wire)
        #expect(ascii.map(\.byte) == wire)
    }

    @Test func `Fields verbs agree (deep composition)`() throws {
        let value = RFC_2822.Fields(
            originationDate: RFC_2822.Timestamp(secondsSinceEpoch: 1_234_567_890),
            from: [try mailbox()],
            sender: try mailbox(),
            to: [RFC_2822.Address(.mailbox(try mailbox()))],
            messageID: try RFC_2822.Message.ID(ascii: Array("<id@example.com>".utf8)),
            subject: "Re: hello"
        )
        var ascii: [ASCII.Code] = []
        RFC_2822.Fields.serialize(value, into: &ascii)
        var wire: [Byte] = []
        RFC_2822.Fields.serialize(value, into: &wire)
        #expect(ascii.map(\.byte) == wire)
    }
}




