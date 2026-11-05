import Foundation
import Testing

func fixture(_ name: String) throws -> [UInt8] {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/\(name)")
    return Array(try #require(FileManager.default.contents(atPath: url.path)))
}
