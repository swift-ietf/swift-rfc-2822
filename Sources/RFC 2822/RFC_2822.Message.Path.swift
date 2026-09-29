public import ASCII
public import Binary
import INCITS_4_1986

extension RFC_2822.Message {

    public struct Path: Hashable, Sendable, Codable {
        public let addrSpec: RFC_2822.AddrSpec?

        init(__unchecked: Void, addrSpec: RFC_2822.AddrSpec?) {
            self.addrSpec = addrSpec
        }

        public init(addrSpec: RFC_2822.AddrSpec? = nil) {
            self.init(__unchecked: (), addrSpec: addrSpec)
        }
    }
}

extension RFC_2822.Message.Path: ASCII.Serializable, Binary.Serializable {

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ path: RFC_2822.Message.Path,
        into buffer: inout Buffer
    ) where Buffer.Element == ASCII.Code {
        buffer.append(ASCII.Code.lessThanSign)
        if let addrSpec = path.addrSpec {
            RFC_2822.AddrSpec.serialize(addrSpec, into: &buffer)
        }
        buffer.append(ASCII.Code.greaterThanSign)
    }

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ path: RFC_2822.Message.Path,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        buffer.append(ASCII.Code.lessThanSign.byte)
        if let addrSpec = path.addrSpec {
            RFC_2822.AddrSpec.serialize(addrSpec, into: &buffer)
        }
        buffer.append(ASCII.Code.greaterThanSign.byte)
    }
}

extension RFC_2822.Message.Path: ASCII.Parseable {

    public init<Bytes: Swift.Collection>(ascii bytes: Bytes) throws(Error)
    where Bytes.Element == Byte {
        guard !bytes.isEmpty else { throw Error.empty }

        var codeArray: [ASCII.Code]
        do throws(ASCII.Code.Error) {
            codeArray = try [ASCII.Code](bytes)
        } catch {
            throw Error.missingAngleBrackets(String(decoding: bytes, as: UTF8.self))
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

        guard
            codeArray.first == ASCII.Code.lessThanSign
                && codeArray.last == ASCII.Code.greaterThanSign
        else {
            throw Error.missingAngleBrackets(String(decoding: bytes, as: UTF8.self))
        }

        let contentBytes = [Byte](codeArray.dropFirst().dropLast())

        if contentBytes.isEmpty {
            self.init(__unchecked: (), addrSpec: nil)
            return
        }

        let addrSpec: RFC_2822.AddrSpec
        do throws(RFC_2822.AddrSpec.Error) {
            addrSpec = try RFC_2822.AddrSpec(ascii: contentBytes)
        } catch {
            throw Error.invalidAddrSpec(error)
        }

        self.init(__unchecked: (), addrSpec: addrSpec)
    }
}

extension RFC_2822.Message.Path: Swift.RawRepresentable {

    public var rawValue: String { description }

    public init?(rawValue: String) {
        do throws(RFC_2822.Message.Path.Error) {
            try self.init(ascii: rawValue.utf8.map { Byte($0) })
        } catch {
            return nil
        }
    }
}

extension RFC_2822.Message.Path: CustomStringConvertible {

    public var description: String {
        "<\(addrSpec?.description ?? "")>"
    }
}
