enum JSONValue {
    case string(String)
    case number(String)
    case otherValue
}

struct JSONError: Error {
    var reason: String

    static let notValid = JSONError(reason: "not valid JSON")
}

// Bounds recursion so a hostile file can't overflow the 1 MB wasm stack.
private let deepestNesting = 64

func parseJSONObject(_ text: String) throws(JSONError) -> [String: JSONValue] {
    var reader = JSONReader(scalars: Array(text.unicodeScalars))
    guard reader.consumeAfterWhitespace("{") else {
        _ = try reader.value(depth: 0)
        try reader.expectEnd()
        throw JSONError(reason: "expected a JSON object")
    }
    let fields = try reader.objectFields(depth: 0)
    try reader.expectEnd()
    return fields
}

func jsonString(_ string: String) -> String {
    var quoted = "\""
    for scalar in string.unicodeScalars {
        switch scalar {
        case "\"": quoted += "\\\""
        case "\\": quoted += "\\\\"
        case "\u{8}": quoted += "\\b"
        case "\u{c}": quoted += "\\f"
        case "\n": quoted += "\\n"
        case "\r": quoted += "\\r"
        case "\t": quoted += "\\t"
        case let control where control.value < 0x20:
            let hex = String(control.value, radix: 16)
            quoted += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
        default: quoted.unicodeScalars.append(scalar)
        }
    }
    return quoted + "\""
}

private struct JSONReader {
    let scalars: [Unicode.Scalar]
    var index = 0

    var isAtEnd: Bool { index == scalars.count }

    mutating func skipWhitespace() {
        while !isAtEnd, [" ", "\t", "\n", "\r"].contains(scalars[index]) {
            index += 1
        }
    }

    mutating func expectEnd() throws(JSONError) {
        skipWhitespace()
        guard isAtEnd else {
            throw .notValid
        }
    }

    mutating func next() throws(JSONError) -> Unicode.Scalar {
        guard !isAtEnd else {
            throw .notValid
        }
        index += 1
        return scalars[index - 1]
    }

    mutating func consume(_ expected: Unicode.Scalar) -> Bool {
        guard !isAtEnd, scalars[index] == expected else {
            return false
        }
        index += 1
        return true
    }

    mutating func consumeAfterWhitespace(_ expected: Unicode.Scalar) -> Bool {
        skipWhitespace()
        return consume(expected)
    }

    mutating func expectAfterWhitespace(_ expected: Unicode.Scalar) throws(JSONError) {
        guard consumeAfterWhitespace(expected) else {
            throw .notValid
        }
    }

    mutating func value(depth: Int) throws(JSONError) -> JSONValue {
        guard depth < deepestNesting else {
            throw .notValid
        }
        skipWhitespace()
        if consume("{") {
            _ = try objectFields(depth: depth)
            return .otherValue
        }
        if consume("[") {
            try arrayElements(depth: depth)
            return .otherValue
        }
        if consume("\"") {
            return .string(try stringRest())
        }
        for word in ["true", "false", "null"] where scalars[index...].starts(with: word.unicodeScalars) {
            index += word.unicodeScalars.count
            return .otherValue
        }
        return .number(try number())
    }

    mutating func objectFields(depth: Int) throws(JSONError) -> [String: JSONValue] {
        var fields: [String: JSONValue] = [:]
        if consumeAfterWhitespace("}") {
            return fields
        }
        repeat {
            try expectAfterWhitespace("\"")
            let key = try stringRest()
            guard fields[key] == nil else {
                throw JSONError(reason: "\"\(key)\" appears twice")
            }
            try expectAfterWhitespace(":")
            fields[key] = try value(depth: depth + 1)
        } while consumeAfterWhitespace(",")
        try expectAfterWhitespace("}")
        return fields
    }

    mutating func arrayElements(depth: Int) throws(JSONError) {
        if consumeAfterWhitespace("]") {
            return
        }
        repeat {
            _ = try value(depth: depth + 1)
        } while consumeAfterWhitespace(",")
        try expectAfterWhitespace("]")
    }

    mutating func stringRest() throws(JSONError) -> String {
        var string = String.UnicodeScalarView()
        while true {
            switch try next() {
            case "\"": return String(string)
            case "\\": string.append(try escapedScalar())
            case let control where control.value < 0x20: throw .notValid
            case let scalar: string.append(scalar)
            }
        }
    }

    mutating func escapedScalar() throws(JSONError) -> Unicode.Scalar {
        switch try next() {
        case "\"": return "\""
        case "\\": return "\\"
        case "/": return "/"
        case "b": return "\u{8}"
        case "f": return "\u{c}"
        case "n": return "\n"
        case "r": return "\r"
        case "t": return "\t"
        case "u":
            let unit = try hexCodeUnit()
            guard UTF16.isLeadSurrogate(unit) else {
                guard let scalar = Unicode.Scalar(unit) else {
                    throw .notValid
                }
                return scalar
            }
            guard try next() == "\\", try next() == "u" else {
                throw .notValid
            }
            let trail = try hexCodeUnit()
            guard UTF16.isTrailSurrogate(trail) else {
                throw .notValid
            }
            return Unicode.Scalar(0x10000 + (UInt32(unit - 0xD800) << 10) + UInt32(trail - 0xDC00))!
        default: throw .notValid
        }
    }

    mutating func hexCodeUnit() throws(JSONError) -> UInt16 {
        var unit: UInt16 = 0
        for _ in 0..<4 {
            guard let digit = UInt16(String(try next()), radix: 16) else {
                throw .notValid
            }
            unit = unit * 16 + digit
        }
        return unit
    }

    mutating func number() throws(JSONError) -> String {
        let start = index
        _ = consume("-")
        if !consume("0") {
            try digits()
        }
        if consume(".") {
            try digits()
        }
        if consume("e") || consume("E") {
            _ = consume("+") || consume("-")
            try digits()
        }
        return String(String.UnicodeScalarView(scalars[start..<index]))
    }

    mutating func digits() throws(JSONError) {
        let start = index
        while !isAtEnd, ("0"..."9").contains(scalars[index]) {
            index += 1
        }
        guard index > start else {
            throw .notValid
        }
    }
}
