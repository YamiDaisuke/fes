public struct Tilemap {
    public static let columns = 32
    public static let rows = 32

    public struct Cell: Equatable {
        public var tile: Int
        public var palette: Int

        public init(tile: Int, palette: Int) {
            self.tile = tile
            self.palette = palette
        }
    }

    private var cells = [Cell](repeating: Cell(tile: 0, palette: 0), count: columns * rows)

    public init() {}

    public subscript(column column: Int, row row: Int) -> Cell {
        get { cells[cellIndex(column, row)] }
        set {
            cells[cellIndex(column, row)] = Cell(tile: newValue.tile & 0xFF, palette: newValue.palette & 0b111)
        }
    }

    private func cellIndex(_ column: Int, _ row: Int) -> Int {
        (row & (Self.rows - 1)) * Self.columns + (column & (Self.columns - 1))
    }
}
