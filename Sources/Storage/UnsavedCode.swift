public struct UnsavedCode: Equatable {
    public var folder: String?
    public var name: String
    public var mainLua: String

    public init(folder: String?, name: String, mainLua: String) {
        self.folder = folder
        self.name = name
        self.mainLua = mainLua
    }

    public init?(text: String) {
        guard let fields = try? parseJSONObject(text),
            case .string(let name) = fields["name"], nameProblem(name) == nil,
            case .string(let mainLua) = fields["mainLua"]
        else {
            return nil
        }
        switch fields["folder"] {
        case nil: folder = nil
        case .string(let folder): self.folder = folder
        default: return nil
        }
        self.name = name
        self.mainLua = mainLua
    }

    public var text: String {
        var fields = ["\"name\": \(jsonString(name))", "\"mainLua\": \(jsonString(mainLua))"]
        if let folder {
            fields.append("\"folder\": \(jsonString(folder))")
        }
        return "{" + fields.joined(separator: ", ") + "}"
    }
}
