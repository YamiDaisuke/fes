import Console
import Storage

extension Color {
    public var hexCode: String {
        "#" + lowercaseHex(Int(red) << 16 | Int(green) << 8 | Int(blue), digits: 6)
    }

    public init?(hexCode: String) {
        guard hexCode.utf8.count == 7, hexCode.first == "#", let rgb = hexValue(hexCode.dropFirst()) else {
            return nil
        }
        self.init(rgb: rgb)
    }
}
