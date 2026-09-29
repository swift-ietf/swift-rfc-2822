public import Parser

extension RFC_2822.Mailbox {

    public struct Parse<Input: Collection.Slice.`Protocol`>: Sendable
    where Input: Sendable, Input.Element == UInt8 {
        @inlinable
        public init() {}
    }
}

extension RFC_2822.Mailbox.Parse: Parsing {
    public typealias Failure = RFC_2822.Mailbox.Parse<Input>.Error
    public typealias Body = Never

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        guard input.startIndex < input.endIndex else { throw .empty }

        var openAngle: Input.Index? = nil
        var idx = input.startIndex
        while idx < input.endIndex {
            if input[idx] == 0x3C {
                openAngle = idx
                break
            }
            input.formIndex(after: &idx)
        }

        if let open = openAngle {

            let displayName: Input?
            if open > input.startIndex {
                displayName = input[input.startIndex..<open]
            } else {
                displayName = nil
            }

            let afterOpen = input.index(after: open)

            var close: Input.Index? = nil
            var scanIdx = afterOpen
            while scanIdx < input.endIndex {
                if input[scanIdx] == 0x3E {
                    close = scanIdx
                    break
                }
                input.formIndex(after: &scanIdx)
            }
            guard let closeIdx = close else { throw .unterminatedAngleBracket }

            let addrSlice = input[afterOpen..<closeIdx]
            var atIndex: Input.Index? = nil
            var atScan = addrSlice.startIndex
            while atScan < addrSlice.endIndex {
                if addrSlice[atScan] == 0x40 {
                    atIndex = atScan
                }
                addrSlice.formIndex(after: &atScan)
            }

            guard let at = atIndex else { throw .missingAtSign }
            guard at > addrSlice.startIndex else { throw .emptyLocalPart }
            let afterAt = addrSlice.index(after: at)
            guard afterAt < addrSlice.endIndex else { throw .emptyDomain }

            let localPart = addrSlice[addrSlice.startIndex..<at]
            let domain = addrSlice[afterAt..<addrSlice.endIndex]

            input = input[input.index(after: closeIdx)...]
            return Output(displayName: displayName, localPart: localPart, domain: domain)
        } else {

            var atIndex: Input.Index? = nil
            var endIdx = input.startIndex
            while endIdx < input.endIndex {
                let byte = input[endIdx]
                if byte == 0x40 { atIndex = endIdx }

                if byte == 0x2C || byte == 0x0D || byte == 0x0A { break }
                input.formIndex(after: &endIdx)
            }

            guard let at = atIndex else { throw .missingAtSign }
            guard at > input.startIndex else { throw .emptyLocalPart }
            let afterAt = input.index(after: at)
            guard afterAt < endIdx else { throw .emptyDomain }

            let localPart = input[input.startIndex..<at]
            let domain = input[afterAt..<endIdx]

            input = input[endIdx...]
            return Output(displayName: nil, localPart: localPart, domain: domain)
        }
    }
}
