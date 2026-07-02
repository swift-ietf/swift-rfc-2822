# Swift RFC 2822

[![CI](https://github.com/swift-ietf/swift-rfc-2822/workflows/CI/badge.svg)](https://github.com/swift-ietf/swift-rfc-2822/actions/workflows/ci.yml)
![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Swift implementation of RFC 2822: Internet Message Format standard.

## Overview

RFC 2822 defines the standard format for Internet email messages, including headers, addresses, and message structure. This package provides a pure Swift implementation for formatting and parsing RFC 2822 compliant date/time values, as well as types representing email message structure, addresses, and fields.

The package includes date formatting utilities compatible with Swift's `FormatStyle` API, and comprehensive types for representing RFC 2822 message components with full validation.

## Features

- **RFC 2822 Date Formatting**: Format and parse dates in RFC 2822 format (e.g., "Thu, 01 Jan 1970 00:00:00 +0000")
- **FormatStyle Integration**: Native Swift `FormatStyle` support for RFC 2822 dates
- **Message Structure**: Complete types for RFC 2822 message fields and structure
- **Email Address Validation**: Full validation of email addresses per RFC 2822 Section 3.4
- **Mailbox Support**: Represents mailboxes with display names and email addresses
- **Message Fields**: All standard RFC 2822 fields including origination, destination, and identification fields
- **Type-Safe API**: Swift types with comprehensive validation

## Installation

Add swift-rfc-2822 to your package dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/swift-ietf/swift-rfc-2822.git", from: "0.5.5")
]
```

Then add it to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "RFC 2822", package: "swift-rfc-2822")
    ]
)
```

## Quick Start

### Formatting Dates

```swift
import RFC_2822

let date = Date(timeIntervalSince1970: 0)

// Format using RFC 2822 formatter
let formatted = RFC_2822.Date.string(from: date)
// Result: "Thu, 01 Jan 1970 00:00:00 +0000"
```

### Parsing Dates

```swift
let dateString = "Thu, 01 Jan 1970 00:00:00 +0000"

// Parse RFC 2822 date string
if let date = RFC_2822.Date.date(from: dateString) {
    print(date) // Jan 1, 1970, 00:00:00 UTC
}
```

### Using FormatStyle

```swift
let date = Date(timeIntervalSince1970: 0)
let formatter = Date.FormatStyle.rfc2822

// Format with FormatStyle
let formatted = formatter.format(date)
// Result: "Thu, 01 Jan 1970 00:00:00 +0000"
```

## Usage

### Date Formatting

The `RFC_2822.Date` type provides static methods for formatting and parsing:

```swift
extension RFC_2822.Date {
    static func string(from date: Foundation.Date) -> String
    static func date(from string: String) -> Foundation.Date?
}
```

### FormatStyle Extension

```swift
extension FormatStyle where Self == Foundation.Date.FormatStyle {
    public static var rfc2822: RFC2822DateStyle { get }
}
```

### Message Structure Types

**Message:**
```swift
let message = RFC_2822.Message(
    fields: fields,
    body: "Email body content"
)
```

**Email Address:**
```swift
let addrSpec = try RFC_2822.AddrSpec(
    localPart: "user",
    domain: "example.com"
)

let mailbox = RFC_2822.Mailbox(
    displayName: "John Doe",
    emailAddress: addrSpec
)
```

**Message Fields:**
```swift
let fields = RFC_2822.Fields(
    originationDate: Date(),
    from: [mailbox],
    to: [.mailbox(recipientMailbox)],
    subject: "Hello, World!"
)
```

### Advanced Examples

**Creating a complete message:**

```swift
let sender = try RFC_2822.AddrSpec(localPart: "sender", domain: "example.com")
let senderMailbox = RFC_2822.Mailbox(
    displayName: "Sender Name",
    emailAddress: sender
)

let recipient = try RFC_2822.AddrSpec(localPart: "recipient", domain: "example.com")
let recipientMailbox = RFC_2822.Mailbox(
    displayName: "Recipient Name",
    emailAddress: recipient
)

let fields = RFC_2822.Fields(
    originationDate: Date(),
    from: [senderMailbox],
    to: [.mailbox(recipientMailbox)],
    subject: "Important Message",
    messageID: RFC_2822.MessageID(
        idLeft: "unique123",
        idRight: "example.com"
    )
)

let message = RFC_2822.Message(
    fields: fields,
    body: "This is the message body."
)
```

**Validating email addresses:**

```swift
// Valid email address
let valid = try? RFC_2822.AddrSpec(
    localPart: "user.name",
    domain: "example.com"
)

// Invalid local part (will throw)
do {
    let invalid = try RFC_2822.AddrSpec(
        localPart: "user..name",  // consecutive dots not allowed
        domain: "example.com"
    )
} catch {
    print("Validation failed: \(error)")
}
```

**Working with message IDs:**

```swift
let messageID = RFC_2822.MessageID(
    idLeft: "abc123",
    idRight: "mail.example.com"
)

print(messageID.stringValue)
// Result: "<abc123@mail.example.com>"
```

## Related Packages

### Related Standards
- [swift-rfc-2045](https://github.com/swift-ietf/swift-rfc-2045) - MIME Part One: Format of Internet Message Bodies
- [swift-rfc-2046](https://github.com/swift-ietf/swift-rfc-2046) - MIME Part Two: Media Types

## Requirements

- Swift 6.0+
- macOS 13.0+ / iOS 16.0+

## License

This library is released under the Apache License 2.0. See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
