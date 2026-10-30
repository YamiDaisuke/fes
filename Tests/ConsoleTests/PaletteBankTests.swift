import Console
import Testing

@Test func defaultPalettesSpreadTheMasterPaletteInOrder() {
    let bank = PaletteBank()
    #expect(bank.color(palette: 0, index: 0) == MasterPalette.colors[0])
    #expect(bank.color(palette: 2, index: 5) == MasterPalette.colors[21])
    #expect(bank.color(palette: 7, index: 7) == MasterPalette.colors[63])
}

@Test func settingAnEntryChangesOnlyThatEntry() {
    var bank = PaletteBank()
    bank.setMasterIndex(10, palette: 3, index: 4)
    #expect(bank.color(palette: 3, index: 4) == MasterPalette.colors[10])
    #expect(bank.color(palette: 3, index: 5) == MasterPalette.colors[29])
    #expect(bank.color(palette: 4, index: 4) == MasterPalette.colors[36])
}

@Test func paletteAndIndexWrapToThreeBits() {
    let bank = PaletteBank()
    #expect(bank.color(palette: 8, index: 9) == bank.color(palette: 0, index: 1))
    #expect(bank.color(palette: -1, index: -1) == bank.color(palette: 7, index: 7))
}

@Test func masterIndexWrapsToSixBits() {
    var bank = PaletteBank()
    bank.setMasterIndex(70, palette: 0, index: 0)
    #expect(bank.color(palette: 0, index: 0) == MasterPalette.colors[6])
    bank.setMasterIndex(-1, palette: 0, index: 0)
    #expect(bank.color(palette: 0, index: 0) == MasterPalette.colors[63])
}

@Test func masterPaletteHasSixtyFourDistinctColors() {
    #expect(MasterPalette.colors.count == 64)
    #expect(Set(MasterPalette.colors).count == 64)
}
