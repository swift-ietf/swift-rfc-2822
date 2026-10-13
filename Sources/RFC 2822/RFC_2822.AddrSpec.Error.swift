extension RFC_2822.AddrSpec {

    public enum Error: Swift::Error, Sendable, Equatable {

        case empty

        case missingAtSign(_ value: String)

        case invalidLocalPart(_ localPart: String)

        case invalidDomain(_ domain: String)
    }
}

extension RFC_2822.AddrSpec.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .empty:
            return "Address specification cannot be empty"

        case .missingAtSign(let value):
            return "Missing '@' separator in '\(value)'"

        case .invalidLocalPart(let localPart):
            return
                "Invalid local-part '\(localPart)': must be dot-atom or quoted-string per RFC 2822"

        case .invalidDomain(let domain):
            return "Invalid domain '\(domain)': must be dot-atom or domain-literal per RFC 2822"
        }
    }
}
