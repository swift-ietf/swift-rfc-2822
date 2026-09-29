public import ASCII
public import Binary
import INCITS_4_1986

extension RFC_2822.Message {

    public struct Received: Hashable, Sendable, Codable {
        public let tokens: [NameValuePair]
        public let timestamp: RFC_2822.Timestamp

        init(__unchecked: Void, tokens: [NameValuePair], timestamp: RFC_2822.Timestamp) {
            self.tokens = tokens
            self.timestamp = timestamp
        }

        public init(tokens: [NameValuePair], timestamp: RFC_2822.Timestamp) {
            self.init(__unchecked: (), tokens: tokens, timestamp: timestamp)
        }
    }
}

extension RFC_2822.Message.Received: ASCII.Serializable, Binary.Serializable {

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ received: RFC_2822.Message.Received,
        into buffer: inout Buffer
    ) where Buffer.Element == ASCII.Code {
        for (index, token) in received.tokens.enumerated() {
            if index > 0 { buffer.append(ASCII.Code.space) }
            NameValuePair.serialize(token, into: &buffer)
        }
        buffer.append(ASCII.Code.semicolon)
        buffer.append(ASCII.Code.space)
        RFC_2822.Timestamp.serialize(received.timestamp, into: &buffer)
    }

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ received: RFC_2822.Message.Received,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        for (index, token) in received.tokens.enumerated() {
            if index > 0 { buffer.append(ASCII.Code.space.byte) }
            NameValuePair.serialize(token, into: &buffer)
        }
        buffer.append(ASCII.Code.semicolon.byte)
        buffer.append(ASCII.Code.space.byte)
        RFC_2822.Timestamp.serialize(received.timestamp, into: &buffer)
    }
}

extension RFC_2822.Message.Received: ASCII.Parseable {

    public init<Bytes: Swift.Collection>(ascii bytes: Bytes) throws(Error)
    where Bytes.Element == Byte {
        guard !bytes.isEmpty else { throw Error.empty }

        let codeArray: [ASCII.Code]
        do throws(ASCII.Code.Error) {
            codeArray = try bytes.map { byte throws(ASCII.Code.Error) in try ASCII.Code(byte) }
        } catch {
            throw Error.missingSemicolon(String(decoding: bytes, as: UTF8.self))
        }

        guard let semicolonIndex = codeArray.lastIndex(of: ASCII.Code.semicolon) else {
            throw Error.missingSemicolon(String(decoding: bytes, as: UTF8.self))
        }

        let timestampStart = codeArray.index(after: semicolonIndex)
        guard timestampStart < codeArray.endIndex else {
            throw Error.missingTimestamp(String(decoding: bytes, as: UTF8.self))
        }

        var timestampCodes = Array(codeArray[timestampStart...])

        while !timestampCodes.isEmpty
            && (timestampCodes.first == ASCII.Code.space || timestampCodes.first == ASCII.Code.htab)
        {
            timestampCodes.removeFirst()
        }

        guard !timestampCodes.isEmpty else {
            throw Error.missingTimestamp(String(decoding: bytes, as: UTF8.self))
        }

        let timestamp: RFC_2822.Timestamp
        do throws(RFC_2822.Timestamp.Error) {
            timestamp = try RFC_2822.Timestamp(ascii: timestampCodes.map(\.byte))
        } catch {
            throw Error.invalidTimestamp(error)
        }

        let nameValCodes = Array(codeArray[..<semicolonIndex])
        var tokens: [NameValuePair] = []

        var currentName: String?
        var currentToken: [ASCII.Code] = []

        for code in nameValCodes {
            if code == ASCII.Code.space || code == ASCII.Code.htab {
                if !currentToken.isEmpty {
                    let tokenString = String(ascii: currentToken)
                    if let name = currentName {
                        tokens.append(
                            NameValuePair(__unchecked: (), name: name, value: tokenString)
                        )
                        currentName = nil
                    } else {
                        currentName = tokenString
                    }
                    currentToken = []
                }
            } else {
                currentToken.append(code)
            }
        }

        if !currentToken.isEmpty {
            let tokenString = String(ascii: currentToken)
            if let name = currentName {
                tokens.append(NameValuePair(__unchecked: (), name: name, value: tokenString))
            } else if !tokenString.isEmpty {

                tokens.append(NameValuePair(__unchecked: (), name: tokenString, value: ""))
            }
        }

        self.init(__unchecked: (), tokens: tokens, timestamp: timestamp)
    }
}

extension RFC_2822.Message.Received: Swift.RawRepresentable {

    public var rawValue: String { description }

    public init?(rawValue: String) {
        do throws(RFC_2822.Message.Received.Error) {
            try self.init(ascii: rawValue.utf8.map { Byte($0) })
        } catch {
            return nil
        }
    }
}

extension RFC_2822.Message.Received: CustomStringConvertible {

    public var description: String {
        let pairs = tokens.map(\.description).joined(separator: " ")
        return "\(pairs); \(timestamp)"
    }
}
