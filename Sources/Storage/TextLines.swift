func textLines(_ text: String, count: Int, file: String) throws(CartFileError) -> [Substring] {
    var lines = text.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" || $0 == "\r\n" })
    if lines.last == "" {
        lines.removeLast()
    }
    guard lines.count == count else {
        throw CartFileError(
            file: file, line: min(lines.count, count) + 1, reason: "expected \(count) lines, found \(lines.count)")
    }
    return lines
}

func spaceSeparatedFields(
    _ line: Substring, count: Int, file: String, lineNumber: Int, what: String
) throws(CartFileError) -> [Substring] {
    let fields = line.split(separator: " ", omittingEmptySubsequences: false)
    guard fields.count == count else {
        throw CartFileError(file: file, line: lineNumber, reason: "expected \(count) \(what), found \(fields.count)")
    }
    return fields
}

func hexValue(_ text: Substring) -> Int? {
    guard text.allSatisfy({ $0.isASCII && $0.isHexDigit }) else { return nil }
    return Int(text, radix: 16)
}

public func lowercaseHex(_ value: Int, digits: Int) -> String {
    let hex = String(value, radix: 16)
    return String(repeating: "0", count: digits - hex.count) + hex
}
