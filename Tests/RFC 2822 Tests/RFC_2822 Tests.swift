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

@Suite("RFC 2822 AddrSpec Tests")
struct AddrSpecTests {
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

// MARK: - Mailbox Tests

@Suite("RFC 2822 Mailbox Tests")
struct MailboxTests {
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
        let mailbox = try RFC_2822.Mailbox(ascii: Array("\"John Q. Doe\" <john@example.com>".utf8))
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

// MARK: - Address Tests

@Suite("RFC 2822 Address Tests")
struct AddressTests {
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
        let address = try RFC_2822.Address(ascii: Array("Team: john@example.com, jane@example.com;".utf8))
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

// MARK: - Message.ID Tests

@Suite("RFC 2822 Message.ID Tests")
struct MessageIDTests {
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

// MARK: - Timestamp Tests

@Suite("RFC 2822 Timestamp Tests")
struct TimestampTests {
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
        let timestamp = try RFC_2822.Timestamp(ascii: Array("1234567890".utf8))
        #expect(timestamp.secondsSinceEpoch == 1234567890.0)
    }

    @Test
    func `Successfully parses timestamp with whitespace`() throws {
        let timestamp = try RFC_2822.Timestamp(ascii: Array("  1234567890  ".utf8))
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

// MARK: - Fields Tests

@Suite("RFC 2822 Fields Tests")
struct FieldsTests {
    @Test
    func `Successfully creates fields with required fields`() throws {
        let fields = RFC_2822.Fields(
            originationDate: RFC_2822.Timestamp(secondsSinceEpoch: 1_234_567_890),
            from: [
                RFC_2822.Mailbox(
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
                RFC_2822.Mailbox(
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
        let raw = "Date: 1234567890\r\nFrom: sender@example.com\r\nSubject: Test"
        let fields = try RFC_2822.Fields(ascii: Array(raw.utf8))
        #expect(fields.subject == "Test")
        #expect(fields.from.count == 1)
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
        let raw = "Date: 1234567890\r\n"
        #expect(throws: RFC_2822.Fields.Error.self) {
            _ = try RFC_2822.Fields(ascii: Array(raw.utf8))
        }
    }

    @Test
    func `Successfully tests equality`() throws {
        let f1 = RFC_2822.Fields(
            originationDate: RFC_2822.Timestamp(secondsSinceEpoch: 1000),
            from: [
                RFC_2822.Mailbox(
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
                RFC_2822.Mailbox(
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
                RFC_2822.Mailbox(
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

// MARK: - Message Tests

@Suite("RFC 2822 Message Tests")
struct MessageTests {
    @Test
    func `Successfully creates message with fields only`() throws {
        let fields = RFC_2822.Fields(
            originationDate: RFC_2822.Timestamp(secondsSinceEpoch: 1_234_567_890),
            from: [
                RFC_2822.Mailbox(
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
                RFC_2822.Mailbox(
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
            "Date: 1234567890\r\nFrom: sender@example.com\r\nSubject: Test\r\n\r\nThis is the body."
        let message = try RFC_2822.Message(ascii: Array(raw.utf8))
        #expect(message.fields.subject == "Test")
        #expect(message.body != nil)
    }

    @Test
    func `Successfully parses message without body`() throws {
        let raw = "Date: 1234567890\r\nFrom: sender@example.com"
        let message = try RFC_2822.Message(ascii: Array(raw.utf8))
        #expect(message.body == nil)
    }

    @Test
    func `Fails with empty input`() throws {
        #expect(throws: RFC_2822.Message.Error.empty) {
            _ = try RFC_2822.Message(ascii: Array("".utf8))
        }
    }

    @Test
    func `Successfully tests equality`() throws {
        let fields = RFC_2822.Fields(
            originationDate: RFC_2822.Timestamp(secondsSinceEpoch: 1000),
            from: [
                RFC_2822.Mailbox(
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
                RFC_2822.Mailbox(
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

// MARK: - Message.Body Tests

@Suite("RFC 2822 Message.Body Tests")
struct MessageBodyTests {
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
    func `Successfully parses body from ASCII bytes`() throws {
        let body = try RFC_2822.Message.Body(ascii: Array("Test content".utf8))
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
