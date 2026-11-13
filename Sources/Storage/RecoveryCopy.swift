public struct RecoveryCopy: Equatable {
    public enum Edits: Equatable {
        case wholeCart(Cart)
        case codeOnly(name: String, mainLua: String)
    }

    public var folder: String?
    public var edits: Edits

    public var name: String {
        switch edits {
        case .wholeCart(let cart): cart.name
        case .codeOnly(let name, _): name
        }
    }

    public init(folder: String?, edits: Edits) {
        self.folder = folder
        self.edits = edits
    }

    public init?(text: String) {
        guard let fields = try? parseJSONObject(text) else {
            return nil
        }
        switch fields["folder"] {
        case nil: folder = nil
        case .string(let folder): self.folder = folder
        default: return nil
        }
        if case .object(let fileValues) = fields["files"] {
            let files = fileValues.compactMapValues { value in
                if case .string(let text) = value { text } else { nil }
            }
            guard let cart = try? Cart(files: files) else {
                return nil
            }
            edits = .wholeCart(cart)
        } else if case .string(let name) = fields["name"], nameProblem(name) == nil,
            case .string(let mainLua) = fields["mainLua"]
        {
            edits = .codeOnly(name: name, mainLua: mainLua)
        } else {
            return nil
        }
    }

    public static func text(folder: String?, cart: Cart) -> String {
        let files = cart.files
        let fileFields = Cart.fileNames.map { "\(jsonString($0)): \(jsonString(files[$0]!))" }
        var fields = ["\"files\": {" + fileFields.joined(separator: ", ") + "}"]
        if let folder {
            fields.insert("\"folder\": \(jsonString(folder))", at: 0)
        }
        return "{" + fields.joined(separator: ", ") + "}"
    }
}
