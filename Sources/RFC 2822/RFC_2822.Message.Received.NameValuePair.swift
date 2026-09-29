public import ASCII
public import Binary
import INCITS_4_1986

extension RFC_2822.Message.Received {

    public struct NameValuePair: Hashable, Sendable, Codable {
        public let name: String
        public let value: String

        init(__unchecked: Void, name: String, value: String) {
            self.name = name
            self.value = value
        }

        public init(name: String, value: String) {
            self.init(__unchecked: (), name: name, value: value)
        }
    }
}

extension RFC_2822.Message.Received.NameValuePair: ASCII.Serializable, Binary.Serializable {

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ pair: RFC_2822.Message.Received.NameValuePair,
        into buffer: inout Buffer
    ) where Buffer.Element == ASCII.Code {
        buffer.reserveCapacity(pair.name.count + 1 + pair.value.count)
        for byte in pair.name.utf8 { buffer.append(ASCII.Code(byte)) }
        if !pair.value.isEmpty {
            buffer.append(ASCII.Code.space)
            for byte in pair.value.utf8 { buffer.append(ASCII.Code(byte)) }
        }
    }

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ pair: RFC_2822.Message.Received.NameValuePair,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        buffer.reserveCapacity(pair.name.count + 1 + pair.value.count)
        for byte in pair.name.utf8 { buffer.append(Byte(byte)) }
        if !pair.value.isEmpty {
            buffer.append(ASCII.Code.space.byte)
            for byte in pair.value.utf8 { buffer.append(Byte(byte)) }
        }
    }
}

extension RFC_2822.Message.Received.NameValuePair: ASCII.Parseable {

    public init<Bytes: Swift.Collection>(ascii bytes: Bytes) throws(Error)
    where Bytes.Element == Byte {
        guard !bytes.isEmpty else { throw Error.empty }

        var codeArray: [ASCII.Code]
        do throws(ASCII.Code.Error) {
            codeArray = try bytes.map { byte throws(ASCII.Code.Error) in try ASCII.Code(byte) }
        } catch {
            throw Error.invalidName(String(decoding: bytes, as: UTF8.self))
        }

        while !codeArray.isEmpty
            && (codeArray.first == ASCII.Code.space || codeArray.first == ASCII.Code.htab)
        {
            codeArray.removeFirst()
        }
        while !codeArray.isEmpty
            && (codeArray.last == ASCII.Code.space || codeArray.last == ASCII.Code.htab)
        {
            codeArray.removeLast()
        }

        guard !codeArray.isEmpty else { throw Error.empty }

        var nameEndIndex: Int?
        for (index, code) in codeArray.enumerated() {
            if code == ASCII.Code.space || code == ASCII.Code.htab {
                nameEndIndex = index
                break
            }
        }

        let name: String
        let value: String

        if let endIndex = nameEndIndex {
            name = String(ascii: codeArray[..<endIndex])

            var valueStart = endIndex
            while valueStart < codeArray.count
                && (codeArray[valueStart] == ASCII.Code.space
                    || codeArray[valueStart] == ASCII.Code.htab)
            {
                valueStart += 1
            }

            if valueStart < codeArray.count {
                value = String(ascii: codeArray[valueStart...])
            } else {
                value = ""
            }
        } else {

            name = String(ascii: codeArray)
            value = ""
        }

        guard !name.isEmpty else { throw Error.empty }

        self.init(__unchecked: (), name: name, value: value)
    }
}

extension RFC_2822.Message.Received.NameValuePair: Swift.RawRepresentable {

    public var rawValue: String { description }

    public init?(rawValue: String) {
        do throws(RFC_2822.Message.Received.NameValuePair.Error) {
            try self.init(ascii: rawValue.utf8.map { Byte($0) })
        } catch {
            return nil
        }
    }
}

extension RFC_2822.Message.Received.NameValuePair: CustomStringConvertible {

    public var description: String {
        value.isEmpty ? name : "\(name) \(value)"
    }
}
