import Binary

extension String {

    public init<Encoding>(
        _ addrSpec: RFC_2822.AddrSpec,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](addrSpec), as: encoding)
    }
}

extension String {

    public init<Encoding>(
        _ mailbox: RFC_2822.Mailbox,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](mailbox), as: encoding)
    }
}

extension String {

    public init<Encoding>(
        _ address: RFC_2822.Address,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](address), as: encoding)
    }
}

extension String {

    public init<Encoding>(
        _ fields: RFC_2822.Fields,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](fields), as: encoding)
    }
}

extension String {

    public init<Encoding>(
        _ message: RFC_2822.Message,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](message), as: encoding)
    }
}

extension String {

    public init<Encoding>(
        _ body: RFC_2822.Message.Body,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](body), as: encoding)
    }
}

extension String {

    public init<Encoding>(
        _ timestamp: RFC_2822.Timestamp,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](timestamp), as: encoding)
    }
}

extension String {

    public init<Encoding>(
        _ messageID: RFC_2822.Message.ID,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](messageID), as: encoding)
    }
}

extension String {

    public init<Encoding>(
        _ path: RFC_2822.Message.Path,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](path), as: encoding)
    }
}

extension String {

    public init<Encoding>(
        _ pair: RFC_2822.Message.Received.NameValuePair,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](pair), as: encoding)
    }
}

extension String {

    public init<Encoding>(
        _ received: RFC_2822.Message.Received,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](received), as: encoding)
    }
}
