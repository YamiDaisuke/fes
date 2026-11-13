public struct ArtHistory {
    public static let stepLimit = 100

    private struct Step {
        let edit: String
        let art: CartArt
    }

    private var undoSteps: [Step] = []
    private var redoSteps: [Step] = []
    private var isMerging = false

    public init() {}

    public var nextUndo: String? { undoSteps.last?.edit }
    public var nextRedo: String? { redoSteps.last?.edit }

    public mutating func record(_ edit: String, before: CartArt, after: CartArt, merging: Bool = false) {
        guard before != after else { return }
        if merging && isMerging && undoSteps.last?.edit == edit {
            return
        }
        undoSteps.append(Step(edit: edit, art: before))
        redoSteps = []
        if undoSteps.count > Self.stepLimit {
            undoSteps.removeFirst()
        }
        isMerging = merging
    }

    public mutating func stopMerging() {
        isMerging = false
    }

    public mutating func undo(current: CartArt) -> (edit: String, art: CartArt)? {
        guard let step = undoSteps.popLast() else { return nil }
        redoSteps.append(Step(edit: step.edit, art: current))
        isMerging = false
        return (step.edit, step.art)
    }

    public mutating func redo(current: CartArt) -> (edit: String, art: CartArt)? {
        guard let step = redoSteps.popLast() else { return nil }
        undoSteps.append(Step(edit: step.edit, art: current))
        return (step.edit, step.art)
    }
}
