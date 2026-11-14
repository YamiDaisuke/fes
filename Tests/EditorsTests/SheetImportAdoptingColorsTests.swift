import Console
@testable import Editors
import Storage
import Testing

private func colors(_ values: Range<Int>) -> [Color] {
    values.map { Color(rgb: 0x100000 + $0) }
}

private func sheet(tiles: [[Color]]) -> TestSheet {
    var sheet = TestSheet(width: tiles.count * 8, height: 8)
    for (tile, tileColors) in tiles.enumerated() {
        for pixel in 0..<64 {
            sheet.set(x: tile * 8 + pixel % 8, y: pixel / 8, color: tileColors[pixel % tileColors.count])
        }
    }
    return sheet
}

private func adopting(_ sheet: TestSheet, into bank: Bank, cart: Cart = Cart(name: "Adopt", mainLua: "")) -> SheetImport {
    cart.sheetImportAdoptingColors(width: sheet.width, height: sheet.height, rgba: sheet.rgba, bank: bank)
}

private func cartAfterAdopting(_ sheet: TestSheet, into bank: Bank, cart: Cart = Cart(name: "Adopt", mainLua: "")) -> Cart? {
    guard case .imported(let art) = adopting(sheet, into: bank, cart: cart) else { return nil }
    var adopted = cart
    adopted.art = art
    return adopted
}

private func shownColor(of sheet: TestSheet, x: Int, y: Int) -> Color? {
    let offset = (y * sheet.width + x) * 4
    guard sheet.rgba[offset + 3] == 255 else { return nil }
    return Color(red: sheet.rgba[offset], green: sheet.rgba[offset + 1], blue: sheet.rgba[offset + 2])
}

private func paletteShowingEachTile(of sheet: TestSheet, in cart: Cart, bank: Bank) -> [Int?] {
    let tiles = cart.tiles(in: bank)
    return (0..<(sheet.width / 8)).map { tile in
        (0..<PaletteBank.paletteCount).first { palette in
            let shown = cart.previewColors(bank: bank, palette: palette)
            return (0..<64).allSatisfy { pixel in
                let index = tiles.colorIndex(tile: tile, x: pixel % 8, y: pixel / 8)
                return shown[index] == shownColor(of: sheet, x: tile * 8 + pixel % 8, y: pixel / 8)
            }
        }
    }
}

private func refusal(_ rule: SheetRule, column: Int) -> SheetImport {
    .refused([SheetProblem(rule: rule, tile: SheetTile(column: column, row: 0))])
}

@Test func theImageColorsBecomeTheFirstMainColorsInReadingOrderAndTheRestStay() {
    var cart = Cart(name: "Adopt", mainLua: "")
    cart.mainPalette[63] = Color(rgb: 0x123456)
    var sheet = TestSheet(width: 16, height: 8, color: Color(rgb: 0xaa0000))
    sheet.set(x: 0, y: 1, color: Color(rgb: 0x00bb00))
    sheet.set(x: 8, y: 0, color: Color(rgb: 0x0000cc))

    let adopted = cartAfterAdopting(sheet, into: .background, cart: cart)

    #expect((0..<3).map { adopted?.mainPalette[$0] } == [0xaa0000, 0x0000cc, 0x00bb00].map(Color.init(rgb:)))
    #expect((3..<64).allSatisfy { adopted?.mainPalette[$0] == cart.mainPalette[$0] })
}

@Test func backgroundTilesSharingColorsShareAPaletteAndShowTheImageExactly() {
    let sheet = sheet(tiles: [colors(0..<5), colors(5..<10), colors(1..<3)])

    guard let adopted = cartAfterAdopting(sheet, into: .background) else {
        Issue.record("refused")
        return
    }
    let palettes = paletteShowingEachTile(of: sheet, in: adopted, bank: .background)
    #expect(!palettes.contains(nil))
    #expect(palettes[0] == palettes[2])
    #expect(palettes[0] != palettes[1])
    let entries = (0..<8).flatMap { palette in (0..<8).map { adopted.backgroundPalettes.mainPaletteIndex(palette: palette, index: $0) } }
    #expect(entries.filter { $0 != 0 }.count == 9)
}

@Test func spriteTransparencyStaysIndex0AndItsRGBIsNotAdopted() {
    let hiddenRGB = Color(rgb: 0x0f0f0f)
    var sheet = sheet(tiles: [colors(0..<7)])
    sheet.set(x: 7, y: 7, color: hiddenRGB, alpha: 0)
    sheet.set(x: 0, y: 3, color: hiddenRGB, alpha: 0)

    guard let adopted = cartAfterAdopting(sheet, into: .sprite) else {
        Issue.record("refused")
        return
    }
    #expect(!paletteShowingEachTile(of: sheet, in: adopted, bank: .sprite).contains(nil))
    #expect(!(0..<64).contains { adopted.mainPalette[$0] == hiddenRGB })
}

@Test func an65ColorImageIsRefusedAsAWholeAnd64ColorsImport() {
    let eightTiles = (0..<8).map { colors($0 * 8..<($0 + 1) * 8) }

    #expect(cartAfterAdopting(sheet(tiles: eightTiles + [colors(0..<1)]), into: .background) != nil)
    #expect(adopting(sheet(tiles: eightTiles + [colors(64..<65)]), into: .background)
        == .refused([SheetProblem(rule: .tooManyImageColors(count: 65), tile: nil)]))
}

@Test func aNinthTileNeedingItsOwnPaletteIsRefusedInBothBanks() {
    let spriteTiles = (0..<9).map { colors($0 * 4..<($0 + 1) * 4) }
    let backgroundTiles = (0..<9).map { colors($0 * 5..<($0 + 1) * 5) }

    #expect(adopting(sheet(tiles: spriteTiles), into: .sprite) == refusal(.needsMorePalettes(bank: .sprite), column: 8))
    #expect(adopting(sheet(tiles: backgroundTiles), into: .background) == refusal(.needsMorePalettes(bank: .background), column: 8))
}

@Test func aTileWithTooManyColorsIsReportedAloneAndTakesNoPalette() {
    let fittingTiles = (0..<8).map { colors(10 + $0 * 5..<10 + ($0 + 1) * 5) }

    #expect(adopting(sheet(tiles: [colors(0..<9)] + fittingTiles), into: .background)
        == refusal(.tooManyColors(count: 9, bank: .background), column: 0))
}

@Test func adoptingIntoSpritesLeavesTheBackgroundBankAlone() {
    var cart = cartWithPatternTiles()
    cart.backgroundPalettes.setMainPaletteIndex(40, palette: 2, index: 3)

    guard case .imported(let art) = adopting(sheet(tiles: [colors(0..<3)]), into: .sprite, cart: cart) else {
        Issue.record("refused")
        return
    }
    #expect(art.backgroundTiles == cart.backgroundTiles)
    #expect(art.backgroundPalettes == cart.backgroundPalettes)
}
