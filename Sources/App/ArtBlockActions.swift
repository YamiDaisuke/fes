import Console
import Editors
import JavaScriptKit

nonisolated(unsafe) private let document = JSObject.global.document
nonisolated(unsafe) private let pasteButton = document.getElementById("art-paste")

nonisolated(unsafe) private var copiedBlock: BlockPixels?

nonisolated(unsafe) private let flipHorizontalClicked = JSClosure { _ in
    editBlockTiles { tiles in
        let block = artSelection.block
        tiles.paste(tiles.pixels(of: block).flippedHorizontally(), atSelectedTile: block.firstTile)
    }
    return .undefined
}

nonisolated(unsafe) private let flipVerticalClicked = JSClosure { _ in
    editBlockTiles { tiles in
        let block = artSelection.block
        tiles.paste(tiles.pixels(of: block).flippedVertically(), atSelectedTile: block.firstTile)
    }
    return .undefined
}

nonisolated(unsafe) private let copyClicked = JSClosure { _ in
    copiedBlock = cart.tiles(in: artSelection.bank).pixels(of: artSelection.block)
    redrawArtView()
    return .undefined
}

nonisolated(unsafe) private let pasteClicked = JSClosure { _ in
    if let copiedBlock {
        editBlockTiles { tiles in
            tiles.paste(copiedBlock, atSelectedTile: artSelection.tile)
        }
    }
    return .undefined
}

func startBlockActions() {
    _ = document.getElementById("art-flip-horizontal").addEventListener("click", flipHorizontalClicked)
    _ = document.getElementById("art-flip-vertical").addEventListener("click", flipVerticalClicked)
    _ = document.getElementById("art-copy").addEventListener("click", copyClicked)
    _ = pasteButton.addEventListener("click", pasteClicked)
}

func redrawBlockActions() {
    pasteButton.disabled = .boolean(copiedBlock == nil)
}

private func editBlockTiles(_ edit: (inout TileBank) -> Void) {
    dropArtStroke()
    var tiles = cart.tiles(in: artSelection.bank)
    edit(&tiles)
    cart.setTiles(tiles, in: artSelection.bank)
    keepRecoveryCopy()
    redrawArtView()
}
