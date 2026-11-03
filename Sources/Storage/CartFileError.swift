public struct CartFileError: Error, CustomStringConvertible {
    public var file: String
    public var line: Int?
    public var reason: String

    public var description: String {
        if let line {
            "\(file) line \(line): \(reason)"
        } else {
            "\(file): \(reason)"
        }
    }
}
