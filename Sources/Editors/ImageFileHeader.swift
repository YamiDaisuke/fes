public enum ImageFileType {
    case png
    case jpeg
}

public struct ImageFileHeader: Equatable {
    public let type: ImageFileType
    public let width: Int
    public let height: Int

    public init?(fileBytes: [UInt8]) {
        if let size = pngSize(fileBytes) {
            type = .png
            (width, height) = size
        } else if let size = jpegSize(fileBytes) {
            type = .jpeg
            (width, height) = size
        } else {
            return nil
        }
    }
}

private let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
private let pngHeaderChunkType = Array("IHDR".utf8)

private func pngSize(_ bytes: [UInt8]) -> (width: Int, height: Int)? {
    guard bytes.count >= 24,
          bytes.starts(with: pngSignature),
          Array(bytes[12..<16]) == pngHeaderChunkType,
          let width = bigEndianUInt32(bytes, at: 16).flatMap(Int32.init(exactly:)),
          let height = bigEndianUInt32(bytes, at: 20).flatMap(Int32.init(exactly:))
    else { return nil }
    return (Int(width), Int(height))
}

private let jpegStartOfImage: [UInt8] = [0xFF, 0xD8]

private func jpegSize(_ bytes: [UInt8]) -> (width: Int, height: Int)? {
    guard bytes.starts(with: jpegStartOfImage) else { return nil }
    var offset = jpegStartOfImage.count
    while offset < bytes.count {
        guard bytes[offset] == 0xFF else { return nil }
        while offset < bytes.count && bytes[offset] == 0xFF {
            offset += 1
        }
        guard offset < bytes.count else { return nil }
        let marker = bytes[offset]
        offset += 1

        let isStandalone = marker == 0x01 || (0xD0...0xD7).contains(marker)
        if isStandalone {
            continue
        }
        let isStartOfScanOrEndOfImage = marker == 0xDA || marker == 0xD9
        if isStartOfScanOrEndOfImage {
            return nil
        }
        guard let segmentLength = bigEndianUInt16(bytes, at: offset), segmentLength >= 2 else { return nil }
        if isStartOfFrame(marker) {
            guard let height = bigEndianUInt16(bytes, at: offset + 3),
                  let width = bigEndianUInt16(bytes, at: offset + 5)
            else { return nil }
            return (width, height)
        }
        offset += segmentLength
    }
    return nil
}

private func isStartOfFrame(_ marker: UInt8) -> Bool {
    let notFrames: [UInt8] = [0xC4, 0xC8, 0xCC]
    return (0xC0...0xCF).contains(marker) && !notFrames.contains(marker)
}

private func bigEndianUInt16(_ bytes: [UInt8], at offset: Int) -> Int? {
    guard offset + 2 <= bytes.count else { return nil }
    return Int(bytes[offset]) << 8 | Int(bytes[offset + 1])
}

private func bigEndianUInt32(_ bytes: [UInt8], at offset: Int) -> UInt32? {
    guard offset + 4 <= bytes.count else { return nil }
    return bytes[offset..<(offset + 4)].reduce(0) { $0 << 8 | UInt32($1) }
}
