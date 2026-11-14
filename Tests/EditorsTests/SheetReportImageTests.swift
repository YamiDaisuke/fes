import Console
@testable import Editors
import GoldenImage
import Storage
import Testing

private func rgba(_ color: Color, alpha: UInt8 = 255) -> [UInt8] {
    [color.red, color.green, color.blue, alpha]
}

@Test func theReportImageDrawsAnImageAtItsBankPositionsAndRingsItsProblemTiles() throws {
    let mainPalette = MainPalette()
    var pixels: [UInt8] = []
    for y in 0..<8 {
        for x in 0..<8 {
            let index = (x + y) % 8
            pixels += rgba(mainPalette[index], alpha: index == 0 ? 0 : 255)
        }
        for x in 0..<8 {
            let isHalfTransparent = x == 7 && y == 7
            pixels += rgba(mainPalette[8 + (x + y) % 9], alpha: isHalfTransparent ? 128 : 255)
        }
    }
    let cart = Cart(name: "Report", mainLua: "")
    guard case .refused(let problems) = cart.sheetImport(width: 16, height: 8, rgba: pixels, bank: .sprite, preferredPalette: 0) else {
        Issue.record("imported")
        return
    }
    #expect(problems.allSatisfy { $0.tile == SheetTile(column: 1, row: 0) })

    let layout = tileSheetLayout(fittingWidth: 145, height: 145)
    #expect(layout.zoom == 1)
    let image = sheetReportImage(width: 16, height: 8, rgba: pixels, problems: problems, layout: layout)
    try expectImageMatchesGolden(
        rgba: image.rgba, width: image.width, height: image.height, named: "sheet-report-16x8-problem-tile-1-0")
}

@Test func theReportImageDrawsNoPixelsWhenTheSizeRulesOrByteCountFail() {
    let layout = tileSheetLayout(fittingWidth: 145, height: 145)
    let plainGrid = RGBAImage(width: layout.side, height: layout.side, color: gridLineColor)
    let white = rgba(Color(rgb: 0xffffff))
    let notMultipleOf8 = Array([[UInt8]](repeating: white, count: 12 * 8).joined())
    let tooFewBytes = Array([[UInt8]](repeating: white, count: 8 * 8).joined())
    #expect(sheetReportImage(width: 12, height: 8, rgba: notMultipleOf8, problems: [], layout: layout) == plainGrid)
    #expect(sheetReportImage(width: 16, height: 8, rgba: tooFewBytes, problems: [], layout: layout) == plainGrid)
}
