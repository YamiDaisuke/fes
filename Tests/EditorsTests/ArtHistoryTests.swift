import Console
import Editors
import Storage
import Testing

private func art(_ step: Int) -> CartArt {
    var cart = Cart(name: "", mainLua: "")
    cart.mainPalette[0] = Color(red: UInt8(step % 256), green: UInt8(step / 256), blue: 0)
    return cart.art
}

@Test func undoingRestoresStepsNewestFirstAndRedoReplaysThemInOrder() {
    var history = ArtHistory()
    history.record("stroke", before: art(0), after: art(1))
    history.record("fill", before: art(1), after: art(2))

    let undoneFill = history.undo(current: art(2))
    #expect(undoneFill?.edit == "fill")
    #expect(undoneFill?.art == art(1))
    let undoneStroke = history.undo(current: art(1))
    #expect(undoneStroke?.edit == "stroke")
    #expect(undoneStroke?.art == art(0))

    let redoneStroke = history.redo(current: art(0))
    #expect(redoneStroke?.edit == "stroke")
    #expect(redoneStroke?.art == art(1))
    let redoneFill = history.redo(current: art(1))
    #expect(redoneFill?.edit == "fill")
    #expect(redoneFill?.art == art(2))
    #expect(history.nextRedo == nil)
    #expect(history.nextUndo == "fill")
}

@Test func aNewEditAfterUndoDropsTheRedoSteps() {
    var history = ArtHistory()
    history.record("stroke", before: art(0), after: art(1))
    _ = history.undo(current: art(1))
    history.record("paste", before: art(0), after: art(2))

    #expect(history.nextRedo == nil)
    #expect(history.redo(current: art(2)) == nil)
    #expect(history.undo(current: art(2))?.art == art(0))
}

@Test func anEditThatChangesNothingRecordsNoStep() {
    var history = ArtHistory()
    history.record("stroke", before: art(0), after: art(1))
    _ = history.undo(current: art(1))
    history.record("horizontal flip", before: art(0), after: art(0))

    #expect(history.nextUndo == nil)
    #expect(history.nextRedo == "stroke")
}

@Test func theStepPastTheLimitDropsTheOldest() {
    var history = ArtHistory()
    for step in 0...ArtHistory.stepLimit {
        history.record("stroke", before: art(step), after: art(step + 1))
    }
    var undone: CartArt?
    for _ in 0..<ArtHistory.stepLimit {
        undone = history.undo(current: art(0))?.art
    }

    #expect(undone == art(1))
    #expect(history.undo(current: art(0)) == nil)
}

@Test func mergingValuesOfTheSameEditMakeOneStepUntilMergingStops() {
    var history = ArtHistory()
    history.record("main color 3", before: art(0), after: art(1), merging: true)
    history.record("main color 3", before: art(1), after: art(2), merging: true)
    #expect(history.undo(current: art(2))?.art == art(0))
    #expect(history.nextUndo == nil)

    _ = history.redo(current: art(0))
    history.record("main color 3", before: art(2), after: art(3), merging: true)
    #expect(history.undo(current: art(3))?.art == art(2))
    _ = history.redo(current: art(2))

    history.stopMerging()
    history.record("main color 3", before: art(3), after: art(4), merging: true)
    history.record("palette color", before: art(4), after: art(5))
    history.record("main color 3", before: art(5), after: art(6), merging: true)
    history.record("main color 4", before: art(6), after: art(7), merging: true)
    #expect(history.undo(current: art(7))?.art == art(6))
    #expect(history.undo(current: art(6))?.art == art(5))
    #expect(history.undo(current: art(5))?.art == art(4))
    #expect(history.undo(current: art(4))?.art == art(3))
}

@Test func stopMergingMakesTheNextValueANewStep() {
    var history = ArtHistory()
    history.record("main color 3", before: art(3), after: art(4), merging: true)
    history.stopMerging()
    history.record("main color 3", before: art(4), after: art(5), merging: true)

    #expect(history.undo(current: art(5))?.art == art(4))
    #expect(history.undo(current: art(4))?.art == art(3))
}

@Test func undoStopsMergingSoTheNextValueDropsTheRedoSteps() {
    var history = ArtHistory()
    history.record("main color 3", before: art(0), after: art(1), merging: true)
    history.stopMerging()
    history.record("main color 3", before: art(1), after: art(2), merging: true)
    _ = history.undo(current: art(2))
    history.record("main color 3", before: art(1), after: art(3), merging: true)

    #expect(history.nextRedo == nil)
    #expect(history.undo(current: art(3))?.art == art(1))
    #expect(history.undo(current: art(1))?.art == art(0))
}

@Test func undoAndRedoOnAnEmptyHistoryReturnNothing() {
    var history = ArtHistory()
    #expect(history.undo(current: art(0)) == nil)
    #expect(history.redo(current: art(0)) == nil)
}
