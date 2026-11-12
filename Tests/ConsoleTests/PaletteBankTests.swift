import Console
import Testing

@Test func defaultPalettesSpreadTheMainPaletteInOrder() {
    let bank = PaletteBank()
    #expect(bank.mainPaletteIndex(palette: 0, index: 0) == 0)
    #expect(bank.mainPaletteIndex(palette: 2, index: 5) == 21)
    #expect(bank.mainPaletteIndex(palette: 7, index: 7) == 63)
}

@Test func settingAnEntryChangesOnlyThatEntry() {
    var bank = PaletteBank()
    bank.setMainPaletteIndex(10, palette: 3, index: 4)
    #expect(bank.mainPaletteIndex(palette: 3, index: 4) == 10)
    #expect(bank.mainPaletteIndex(palette: 3, index: 5) == 29)
    #expect(bank.mainPaletteIndex(palette: 4, index: 4) == 36)
}

@Test func paletteAndIndexWrapToThreeBits() {
    let bank = PaletteBank()
    #expect(bank.mainPaletteIndex(palette: 8, index: 9) == bank.mainPaletteIndex(palette: 0, index: 1))
    #expect(bank.mainPaletteIndex(palette: -1, index: -1) == bank.mainPaletteIndex(palette: 7, index: 7))
}

@Test func mainPaletteIndexWrapsToSixBits() {
    var bank = PaletteBank()
    bank.setMainPaletteIndex(70, palette: 0, index: 0)
    #expect(bank.mainPaletteIndex(palette: 0, index: 0) == 6)
    bank.setMainPaletteIndex(-1, palette: 0, index: 0)
    #expect(bank.mainPaletteIndex(palette: 0, index: 0) == 63)
}
