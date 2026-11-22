import Binary

extension String {

    public init<Encoding>(
        _ addrSpec: IETF.RFC.`2822`.AddrSpec,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](addrSpec), as: encoding)
    }
}

extension String {

    public init<Encoding>(
        _ mailbox: IETF.RFC.`2822`.Mailbox,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](mailbox), as: encoding)
    }
}

extension String {

    public init<Encoding>(
        _ address: IETF.RFC.`2822`.Address,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](address), as: encoding)
    }
}

extension String {

    public init<Encoding>(
        _ fields: IETF.RFC.`2822`.Fields,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](fields), as: encoding)
    }
}

extension String {

    public init<Encoding>(
        _ message: IETF.RFC.`2822`.Message,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](message), as: encoding)
    }
}

extension String {

    public init<Encoding>(
        _ body: IETF.RFC.`2822`.Message.Body,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](body), as: encoding)
    }
}

extension String {

    public init<Encoding>(
        _ timestamp: IETF.RFC.`2822`.Timestamp,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](timestamp), as: encoding)
    }
}

extension String {

    public init<Encoding>(
        _ messageID: IETF.RFC.`2822`.Message.ID,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](messageID), as: encoding)
    }
}

extension String {

    public init<Encoding>(
        _ path: IETF.RFC.`2822`.Message.Path,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](path), as: encoding)
    }
}

extension String {

    public init<Encoding>(
        _ pair: IETF.RFC.`2822`.Message.Received.NameValuePair,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](pair), as: encoding)
    }
}

extension String {

    public init<Encoding>(
        _ received: IETF.RFC.`2822`.Message.Received,
        as encoding: Encoding.Type = UTF8.self
    ) where Encoding: _UnicodeEncoding, Encoding.CodeUnit == UInt8 {
        self = String(decoding: [UInt8](received), as: encoding)
    }
}
