public struct GridLayout: Equatable {
    public let squares: Int
    public let pixelsPerSquare: Int
    public let zoom: Int

    public var squareSide: Int { pixelsPerSquare * zoom }
    public var side: Int { squares * (squareSide + 1) + 1 }

    public func origin(ofSquare square: Int) -> Int {
        1 + square * (squareSide + 1)
    }

    public func square(at position: Int) -> Int? {
        let square = unboundedSquare(at: position)
        return (0..<squares).contains(square) ? square : nil
    }

    public func unboundedSquare(at position: Int) -> Int {
        let step = squareSide + 1
        return position < 0 ? (position + 1) / step - 1 : max(position - 1, 0) / step
    }

    public static func largest(squares: Int, pixelsPerSquare: Int, fittingWidth width: Int, height: Int) -> GridLayout {
        let linePixels = squares + 1
        let zoom = max(1, (min(width, height) - linePixels) / (squares * pixelsPerSquare))
        return GridLayout(squares: squares, pixelsPerSquare: pixelsPerSquare, zoom: zoom)
    }
}
