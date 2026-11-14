import Console
@testable import Editors
import Testing

private func colors(_ values: ClosedRange<Int>) -> [Color] {
    values.map(Color.init(rgb:))
}

@Test func aTileWhoseColorsAreInsideAnotherTilesSetSharesItsPalette() {
    #expect(packSubPalettes([colors(1...2), colors(1...3)], capacity: 8) == [colors(1...3)])
}

@Test func aSetJoinsThePaletteNeedingTheFewestNewColorsAfterLargerSetsArePlaced() {
    let small = [Color(rgb: 1), Color(rgb: 7), Color(rgb: 8)]

    #expect(packSubPalettes([small, colors(7...11), colors(1...6)], capacity: 8)
        == [colors(1...6), colors(7...11) + [Color(rgb: 1)]])
}

@Test func emptySetsAndSetsOverTheCapacityGetNoPalette() {
    #expect(packSubPalettes([[], colors(1...8), colors(9...9)], capacity: 7) == [colors(9...9)])
}

@Test func aSetThatFitsNowhereIsLeftOutOnceThereAre8Palettes() {
    let sets = (0..<9).map { colors($0 * 10 + 1...$0 * 10 + 5) }

    #expect(packSubPalettes(sets, capacity: 8) == Array(sets.prefix(8)))
}
