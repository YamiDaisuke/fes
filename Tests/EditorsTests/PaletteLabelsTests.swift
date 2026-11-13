import Console
import Editors
import Storage
import Testing

@Test func spriteColorZeroIsLabelledTransparentWhateverItStores() {
    var cart = Cart(name: "Labels", mainLua: "")
    cart.spritePalettes.setMainPaletteIndex(9, palette: 1, index: 0)

    #expect(cart.paletteEntryLabel(bank: .sprite, palette: 1, index: 0) == "Sprite palette 1, color 0: transparent")
}

@Test func backgroundColorZeroNamesItsMainColor() {
    let cart = Cart(name: "Labels", mainLua: "")

    #expect(cart.paletteEntryLabel(bank: .background, palette: 2, index: 0) == "Background palette 2, color 0: main color 16, #614035")
}

@Test func anAssignedEntryNamesItsNewMainColor() {
    var cart = Cart(name: "Labels", mainLua: "")
    var palettes = cart.palettes(in: .background)
    palettes.setMainPaletteIndex(42, palette: 3, index: 5)
    cart.setPalettes(palettes, in: .background)

    #expect(cart.paletteEntryLabel(bank: .background, palette: 3, index: 5) == "Background palette 3, color 5: main color 42, #49b893")
    #expect(cart.paletteEntryLabel(bank: .background, palette: 5, index: 3) == "Background palette 5, color 3: main color 43, #72cf97")
    #expect(cart.mainColorLabel(42) == "Main color 42, #49b893")
}

@Test func mainColorHintNamesTheEntryUnlessItIsSpriteColorZero() {
    #expect(Bank.sprite.mainColorHint(palette: 1, color: 0) == "Sprite color 0 is always transparent.")
    #expect(Bank.background.mainColorHint(palette: 1, color: 0) == "Choose a main color for background palette 1, color 0.")
    #expect(Bank.sprite.mainColorHint(palette: 6, color: 2) == "Choose a main color for sprite palette 6, color 2.")
}
