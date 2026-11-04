# swift-rfc-2822

Use this package when you read or write Internet messages in the RFC 2822 format: addresses, the date-time, message IDs, the header fields and the body. Start from `RFC_2822.Message` for a whole message, `RFC_2822.Fields` for the header block, `RFC_2822.Mailbox` or `RFC_2822.Address` for one address, and `RFC_2822.Timestamp` for a date. RFC 5322 replaced RFC 2822; for that format use swift-rfc-5322.

## Laws

- Header values are ASCII. Parsing refuses a byte above 127, and a display name may not contain control characters, so CR and LF can't reach a header through a mailbox or group name.
- With `Codable`, a value encodes as its wire text, as one string, and decoding parses that string with the same checks as reading wire text. `RFC_2822.Message.Body` encodes as its UTF-8 text.
- An addr-spec splits at its last `@`, so a quoted local part may contain one. The local part must be a dot-atom or a quoted string, and the domain a dot-atom or a domain literal.
- Two addr-specs are equal when their local parts match exactly and their domains match ignoring case. Message IDs compare the same way, with the left part exact and the right part ignoring case.
- A mailbox writes its display name bare only when it has nothing but letters, digits and spaces. Otherwise it is quoted, with `"` and `\` escaped.
- In address text, a colon outside quotes and angle brackets starts a group, which must end with `;`. A quoted display name may contain a colon or a comma. Address lists split on commas outside quotes and angle brackets.
- Two timestamps are equal when they name the same instant, whatever their zones. A zone of `-0000`, or a zone name the parser doesn't know, means the zone is unknown. The instant is then read as UTC, and the zone is written back as `-0000`.
- A zone offset with more than 59 minutes is refused. A two-digit year below 50 is in the 2000s, and from 50 up it is in the 1900s.
- `RFC_2822.Timestamp.init(secondsSinceEpoch:)` rounds down to the second, uses UTC and fills in the day of the week.
- Parsing header fields needs a `Date` and a `From` field and matches field names ignoring case. It ignores `Received`, `Return-Path` and `Resent-` lines, so those fields are written out but not read back.
- A message splits into header and body at the first empty line, written as CRLF CRLF or as LF LF. An empty body is nil, and the body's bytes are kept as they are.
