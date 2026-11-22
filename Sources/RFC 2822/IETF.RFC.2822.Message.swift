public import Binary
import INCITS_4_1986

extension IETF.RFC.`2822` {

    public struct Message: Sendable {
        public let fields: Fields
        public let body: Body?

        init(__unchecked: Void, fields: Fields, body: Body?) {
            self.fields = fields
            self.body = body
        }

        public init(fields: Fields, body: Body? = nil) {
            self.init(__unchecked: (), fields: fields, body: body)
        }
    }
}

extension IETF.RFC.`2822`.Message: Hashable {}

extension IETF.RFC.`2822`.Message {

    public init(
        fields: IETF.RFC.`2822`.Fields,
        body: String?
    ) {
        self.init(__unchecked: (), fields: fields, body: body.map { Body($0) })
    }
}

extension IETF.RFC.`2822`.Message: Binary.Serializable {

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ message: IETF.RFC.`2822`.Message,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        IETF.RFC.`2822`.Fields.serialize(message.fields, into: &buffer)
        if let body = message.body {

            buffer.append(ASCII.Code.cr.byte)
            buffer.append(ASCII.Code.lf.byte)
            buffer.append(ASCII.Code.cr.byte)
            buffer.append(ASCII.Code.lf.byte)
            IETF.RFC.`2822`.Message.Body.serialize(body, into: &buffer)
        }
    }
}

extension IETF.RFC.`2822`.Message {

    public init<Bytes: Swift::Collection>(binary bytes: Bytes) throws(Error)
    where Bytes.Element == Byte {
        guard !bytes.isEmpty else { throw Error.empty }

        let byteArray = [Byte](bytes)
        let codeArray = byteArray.map { byte -> ASCII.Code in
            do throws(ASCII.Code.Error) {
                return try ASCII.Code(byte)
            } catch {

                return ASCII.Code.zero
            }
        }

        var headerEndIndex: Int?
        var bodyStartIndex: Int?

        if codeArray.count >= 4 {
            for i in 0..<(codeArray.count - 3) {
                if codeArray[i] == ASCII.Code.cr && codeArray[i + 1] == ASCII.Code.lf
                    && codeArray[i + 2] == ASCII.Code.cr && codeArray[i + 3] == ASCII.Code.lf
                {
                    headerEndIndex = i
                    bodyStartIndex = i + 4
                    break
                }
            }
        }

        if headerEndIndex == nil && codeArray.count >= 2 {
            for i in 0..<(codeArray.count - 1) {
                if codeArray[i] == ASCII.Code.lf && codeArray[i + 1] == ASCII.Code.lf {
                    headerEndIndex = i
                    bodyStartIndex = i + 2
                    break
                }
            }
        }

        let fieldsBytes: [Byte]
        let bodyBytes: [Byte]?

        if let headerEnd = headerEndIndex, let bodyStart = bodyStartIndex {
            fieldsBytes = Array(byteArray[..<headerEnd])
            bodyBytes =
                if bodyStart < byteArray.count {
                    Array(byteArray[bodyStart...])
                } else {
                    nil
                }
        } else {

            fieldsBytes = byteArray
            bodyBytes = nil
        }

        let fields: IETF.RFC.`2822`.Fields
        do throws(IETF.RFC.`2822`.Fields.Error) {
            fields = try IETF.RFC.`2822`.Fields(ascii: fieldsBytes)
        } catch {
            throw Error.invalidFields(error)
        }

        let body: Body? = bodyBytes.flatMap { bytes in
            bytes.isEmpty ? nil : Body(bytes)
        }

        self.init(__unchecked: (), fields: fields, body: body)
    }
}

extension IETF.RFC.`2822`.Message: Swift::RawRepresentable {

    public var rawValue: String { description }

    public init?(rawValue: String) {
        do throws(IETF.RFC.`2822`.Message.Error) {
            try self.init(binary: rawValue.utf8.map { Byte($0) })
        } catch {
            return nil
        }
    }
}

extension IETF.RFC.`2822`.Message: CustomStringConvertible {

    public var description: String {
        var out: [Byte] = []
        IETF.RFC.`2822`.Message.serialize(self, into: &out)
        return String(decoding: out, as: UTF8.self)
    }
}

#if !hasFeature(Embedded)
    extension IETF.RFC.`2822`.Message: Codable {}
#endif
