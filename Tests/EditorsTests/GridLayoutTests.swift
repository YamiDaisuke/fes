import Editors
import Testing

@Test func sheetZoomIsTheLargestThatFitsTheSmallerSide() {
    #expect(tileSheetLayout(fittingWidth: 401, height: 600).zoom == 3)
    #expect(tileSheetLayout(fittingWidth: 600, height: 400).zoom == 2)
}

@Test func boxSmallerThanZoomOneStillGetsZoomOne() {
    #expect(tileSheetLayout(fittingWidth: 100, height: 100).zoom == 1)
    #expect(tileSheetLayout(fittingWidth: 0, height: 0).zoom == 1)
}

@Test func editAreaZoomFitsItsGridLines() {
    #expect(editAreaLayout(fittingWidth: 57, height: 57).zoom == 6)
}

@Test func gridLineBelongsToTheSquareBeforeIt() {
    let layout = tileSheetLayout(fittingWidth: 145, height: 145)
    #expect(layout.square(at: 0) == 0)
    #expect(layout.square(at: 1) == 0)
    #expect(layout.square(at: 8) == 0)
    #expect(layout.square(at: 9) == 0)
    #expect(layout.square(at: 10) == 1)
    #expect(layout.square(at: layout.side - 1) == 15)
}

@Test func positionsOutsideTheImageHaveNoSquare() {
    let layout = tileSheetLayout(fittingWidth: 145, height: 145)
    #expect(layout.square(at: -1) == nil)
    #expect(layout.square(at: layout.side) == nil)
}
