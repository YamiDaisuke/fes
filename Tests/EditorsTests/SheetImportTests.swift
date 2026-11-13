import Console
@testable import Editors
import Storage
import Testing

private struct TestSheet {
    let width: Int
    let height: Int
    var rgba: [UInt8]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        rgba = [UInt8](repeating: 0, count: width * height * 4)
    }

    init(width: Int, height: Int, color: Color) {
        self.init(width: width, height: height)
        for y in 0..<height {
            for x in 0..<width {
                set(x: x, y: y, color: color)
            }
        }
    }

    mutating func set(x: Int, y: Int, color: Color, alpha: UInt8 = 255) {
        let offset = (y * width + x) * 4
        rgba[offset..<(offset + 4)] = [color.red, color.green, color.blue, alpha]
    }
}

private func defaultColor(palette: Int, index: Int) -> Color {
    MainPalette()[palette * 8 + index]
}

private func importing(_ sheet: TestSheet, into bank: Bank, cart: Cart = Cart(name: "Import", mainLua: ""), preferredPalette: Int = 0) -> SheetImport {
    cart.sheetImport(width: sheet.width, height: sheet.height, rgba: sheet.rgba, bank: bank, preferredPalette: preferredPalette)
}

private func problem(_ rule: SheetRule, column: Int, row: Int) -> SheetProblem {
    SheetProblem(rule: rule, tile: SheetTile(column: column, row: row))
}

private func imageProblem(_ rule: SheetRule) -> SheetImport {
    .refused([SheetProblem(rule: rule, tile: nil)])
}

@Test func aFullSheetImportsEveryPixelExactlyInBothBanks() {
    for bank in Bank.allCases {
        #expect(importing(patternSheet(for: bank), into: bank) == .imported(cartWithPatternTiles().tiles(in: bank)))
    }
}

private func patternSheet(for bank: Bank) -> TestSheet {
    var sheet = TestSheet(width: 128, height: 128)
    for tile in 0..<TileBank.tileCount {
        for y in 0..<8 {
            for x in 0..<8 {
                let index = (tile + x + y) % 8
                let color = defaultColor(palette: tile % 8, index: index)
                let isTransparent = bank.isTransparent(colorIndex: index)
                sheet.set(x: tile % 16 * 8 + x, y: tile / 16 * 8 + y, color: color, alpha: isTransparent ? 0 : 255)
            }
        }
    }
    return sheet
}

@Test func aSmallImageKeepsTilePositionsAndClearsTheRest() {
    var sheet = TestSheet(width: 64, height: 16, color: defaultColor(palette: 0, index: 1))
    sheet.set(x: 7 * 8 + 2, y: 8 + 3, color: defaultColor(palette: 0, index: 5))

    guard case .imported(let tiles) = importing(sheet, into: .background, cart: cartWithPatternTiles()) else {
        Issue.record("refused")
        return
    }
    #expect(tiles.colorIndex(tile: 23, x: 2, y: 3) == 5)
    #expect(tiles.colorIndex(tile: 23, x: 0, y: 0) == 1)
    #expect(tiles.colorIndex(tile: 0, x: 0, y: 0) == 1)
    for tile in [8, 255] {
        #expect((0..<8).allSatisfy { y in tiles.colorIndices(tile: tile, y: y) == Array(repeating: 0, count: 8) })
    }
}

@Test func anImageWithoutPixelsIsRefused() {
    let cart = Cart(name: "Import", mainLua: "")
    #expect(cart.sheetImport(width: 0, height: 8, rgba: [], bank: .sprite, preferredPalette: 0) == imageProblem(.noPixels))
    #expect(cart.sheetImport(width: -8, height: -8, rgba: [], bank: .sprite, preferredPalette: 0) == imageProblem(.noPixels))
}

@Test func aSizeNotMultipleOf8IsRefusedBeforeAnyPixelIsRead() {
    var sheet = TestSheet(width: 12, height: 8)
    sheet.set(x: 0, y: 0, color: Color(rgb: 0x123456), alpha: 7)

    #expect(importing(sheet, into: .background) == imageProblem(.sizeNotMultipleOf8(width: 12, height: 8)))
}

@Test func aSheetOver128IsRefusedAlongWithABadMultiple() {
    #expect(importing(TestSheet(width: 8, height: 136), into: .sprite) == imageProblem(.tooLarge(width: 8, height: 136)))
    #expect(
        importing(TestSheet(width: 130, height: 8), into: .sprite)
            == .refused([
                SheetProblem(rule: .sizeNotMultipleOf8(width: 130, height: 8), tile: nil),
                SheetProblem(rule: .tooLarge(width: 130, height: 8), tile: nil),
            ]))
}

@Test func pixelDataOfTheWrongLengthIsRefused() {
    let cart = Cart(name: "Import", mainLua: "")
    let short = [UInt8](repeating: 0, count: 8 * 8 * 4 - 1)
    let long = [UInt8](repeating: 0, count: 8 * 8 * 4 + 4)

    #expect(cart.sheetImport(width: 8, height: 8, rgba: short, bank: .sprite, preferredPalette: 0)
        == imageProblem(.wrongByteCount(width: 8, height: 8, actual: 255)))
    #expect(cart.sheetImport(width: 8, height: 8, rgba: long, bank: .sprite, preferredPalette: 0)
        == imageProblem(.wrongByteCount(width: 8, height: 8, actual: 260)))
}

@Test func halfTransparentPixelsAreRefused() {
    var sheet = TestSheet(width: 16, height: 8)
    sheet.set(x: 9, y: 4, color: defaultColor(palette: 0, index: 1), alpha: 128)

    #expect(importing(sheet, into: .sprite) == .refused([problem(.halfTransparent, column: 1, row: 0)]))
}

@Test func transparentPixelsAreRefusedOnlyInTheBackgroundBank() {
    var sheet = TestSheet(width: 8, height: 16, color: defaultColor(palette: 0, index: 1))
    sheet.set(x: 3, y: 12, color: Color(rgb: 0xffffff), alpha: 0)

    #expect(importing(sheet, into: .background) == .refused([problem(.transparentInBackground, column: 0, row: 1)]))
    guard case .imported(let tiles) = importing(sheet, into: .sprite) else {
        Issue.record("refused")
        return
    }
    #expect(tiles.colorIndex(tile: 16, x: 3, y: 4) == 0)
}

@Test func colorsMissingFromTheMainPaletteAreListedOnceInOrderOfAppearance() {
    var sheet = TestSheet(width: 8, height: 8, color: defaultColor(palette: 0, index: 1))
    sheet.set(x: 0, y: 1, color: Color(rgb: 0x000001))
    sheet.set(x: 0, y: 2, color: Color(rgb: 0x12ab34))
    sheet.set(x: 0, y: 3, color: Color(rgb: 0x000001))

    #expect(importing(sheet, into: .background)
        == .refused([problem(.colorsNotInMainPalette([Color(rgb: 0x000001), Color(rgb: 0x12ab34)]), column: 0, row: 0)]))
}

@Test func aBackgroundTileMayUse8ColorsAndASpriteTile7PlusTransparent() {
    var nine = TestSheet(width: 8, height: 8)
    var eight = TestSheet(width: 8, height: 8)
    for x in 0..<8 {
        nine.set(x: x, y: 0, color: MainPalette()[x])
        nine.set(x: x, y: 1, color: MainPalette()[x])
        eight.set(x: x, y: 0, color: MainPalette()[x])
    }
    nine.set(x: 0, y: 2, color: MainPalette()[8])
    for y in 2..<8 {
        for x in 0..<8 where !(x == 0 && y == 2) {
            nine.set(x: x, y: y, color: MainPalette()[0])
        }
    }

    #expect(importing(nine, into: .background) == .refused([problem(.tooManyColors(count: 9, bank: .background), column: 0, row: 0)]))
    #expect(importing(eight, into: .sprite) == .refused([problem(.tooManyColors(count: 8, bank: .sprite), column: 0, row: 0)]))

    eight.set(x: 0, y: 0, color: MainPalette()[0], alpha: 0)
    guard case .imported(let tiles) = importing(eight, into: .sprite) else {
        Issue.record("refused")
        return
    }
    #expect(tiles.colorIndices(tile: 0, y: 0) == Array(0..<8))
}

@Test func aTileMixingTwoPalettesFitsNone() {
    var sheet = TestSheet(width: 8, height: 8, color: defaultColor(palette: 0, index: 3))
    sheet.set(x: 7, y: 7, color: defaultColor(palette: 1, index: 3))

    #expect(importing(sheet, into: .background) == .refused([problem(.fitsNoSubPalette(bank: .background), column: 0, row: 0)]))
}

@Test func aSpriteColorFoundOnlyAtEntry0FitsNoPalette() {
    let sheet = TestSheet(width: 8, height: 8, color: defaultColor(palette: 2, index: 0))

    #expect(importing(sheet, into: .sprite) == .refused([problem(.fitsNoSubPalette(bank: .sprite), column: 0, row: 0)]))
    #expect(importing(sheet, into: .background) == .imported(TileBank()))
}

@Test func thePreferredPaletteWinsATieElseTheLowestThatFits() {
    var cart = Cart(name: "Import", mainLua: "")
    cart.backgroundPalettes.setMainPaletteIndex(2, palette: 3, index: 6)
    let sheet = TestSheet(width: 8, height: 8, color: defaultColor(palette: 0, index: 2))

    func importedIndex(preferredPalette: Int) -> Int? {
        guard case .imported(let tiles) = importing(sheet, into: .background, cart: cart, preferredPalette: preferredPalette) else { return nil }
        return tiles.colorIndex(tile: 0, x: 0, y: 0)
    }
    #expect(importedIndex(preferredPalette: 3) == 6)
    #expect(importedIndex(preferredPalette: 5) == 2)
}

@Test func aColorRepeatedInOnePaletteTakesItsLowestPosition() {
    var cart = Cart(name: "Import", mainLua: "")
    cart.spritePalettes.setMainPaletteIndex(4 * 8 + 6, palette: 4, index: 2)
    let sheet = TestSheet(width: 8, height: 8, color: defaultColor(palette: 4, index: 6))

    guard case .imported(let tiles) = importing(sheet, into: .sprite, cart: cart, preferredPalette: 4) else {
        Issue.record("refused")
        return
    }
    #expect(tiles.colorIndex(tile: 0, x: 0, y: 0) == 2)
}

@Test func theReportListsEveryBrokenTileInRowOrderWithCausesOnly() {
    var sheet = TestSheet(width: 128, height: 128, color: defaultColor(palette: 0, index: 1))
    sheet.set(x: 15 * 8, y: 15 * 8, color: defaultColor(palette: 0, index: 1), alpha: 9)
    sheet.set(x: 0, y: 5 * 8, color: defaultColor(palette: 1, index: 1))
    for x in 0..<8 {
        sheet.set(x: 3 * 8 + x, y: 0, color: Color(rgb: 0x010100 + x))
    }
    sheet.set(x: 3 * 8, y: 1, color: defaultColor(palette: 0, index: 2))

    let missing = (0..<8).map { Color(rgb: 0x010100 + $0) }
    #expect(importing(sheet, into: .background) == .refused([
        problem(.colorsNotInMainPalette(missing), column: 3, row: 0),
        problem(.tooManyColors(count: 10, bank: .background), column: 3, row: 0),
        problem(.fitsNoSubPalette(bank: .background), column: 0, row: 5),
        problem(.halfTransparent, column: 15, row: 15),
    ]))
}

@Test func aLongMissingColorListNamesFourAndCountsTheRest() {
    let colors = [0x12ab34, 0xfffffe, 0x000001, 0x808080, 0x010101, 0x020202, 0x030303].map(Color.init(rgb:))
    let report = problem(.colorsNotInMainPalette(colors), column: 2, row: 0)

    #expect(report.message == "Tile at column 2, row 0 (from pixel 16, 0): colors not in the main palette: #12ab34, #fffffe, #000001, #808080 and 3 more.")
}
