import Editors
import Testing

private let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

private func pngStart(width: [UInt8], height: [UInt8], chunkType: String = "IHDR") -> [UInt8] {
    pngSignature + [0, 0, 0, 13] + Array(chunkType.utf8) + width + height + [8, 6, 0, 0, 0]
}

private let jpegStartOfImage: [UInt8] = [0xFF, 0xD8]
private let jpegApp0: [UInt8] = [0xFF, 0xE0, 0x00, 0x05, 0x4A, 0x46, 0x49]
private let jpegHuffmanTable: [UInt8] = [0xFF, 0xC4, 0x00, 0x09, 0x08, 0x00, 0x20, 0x00, 0x30, 0x03, 0x01]
private let jpegArithmeticTable: [UInt8] = [0xFF, 0xCC, 0x00, 0x04, 0x00, 0x00]
private let jpegRestart: [UInt8] = [0xFF, 0xD0]
private let jpegProgressiveFrameHeight16Width24: [UInt8] = [0xFF, 0xC2, 0x00, 0x0B, 0x08, 0x00, 0x10, 0x00, 0x18, 0x01, 0x01, 0x11, 0x00]
private let jpegStartOfScan: [UInt8] = [0xFF, 0xDA, 0x00, 0x02]
private let jpegEndOfImage: [UInt8] = [0xFF, 0xD9]

@Test func aPNGHeaderGivesItsTypeAndSize() {
    let header = ImageFileHeader(fileBytes: pngStart(width: [0, 0, 0, 40], height: [0, 0, 0, 24]) + [1, 2, 3])
    #expect(header?.type == .png)
    #expect(header?.width == 40)
    #expect(header?.height == 24)
}

@Test func aPNGWhoseFirstChunkIsNotIHDROrShorterThan24BytesHasNoHeader() {
    #expect(ImageFileHeader(fileBytes: pngStart(width: [0, 0, 0, 40], height: [0, 0, 0, 24], chunkType: "IDAT")) == nil)
    #expect(ImageFileHeader(fileBytes: Array(pngStart(width: [0, 0, 0, 40], height: [0, 0, 0, 24]).prefix(23))) == nil)
    #expect(ImageFileHeader(fileBytes: pngSignature) == nil)
}

@Test func aPNGSizeOverInt32GivesNoHeaderRatherThanTrapping() {
    #expect(ImageFileHeader(fileBytes: pngStart(width: [0xFF, 0xFF, 0xFF, 0xFF], height: [0, 0, 0, 8])) == nil)
    #expect(ImageFileHeader(fileBytes: pngStart(width: [0, 0, 0, 8], height: [0x80, 0, 0, 0])) == nil)
}

@Test func aJPEGSizeComesFromItsFirstStartOfFrameAfterSkippingOtherSegments() {
    let bytes = jpegStartOfImage + jpegApp0 + [0xFF, 0xFF] + jpegHuffmanTable + jpegArithmeticTable + jpegRestart
        + jpegProgressiveFrameHeight16Width24 + jpegStartOfScan
    let header = ImageFileHeader(fileBytes: bytes)
    #expect(header?.type == .jpeg)
    #expect(header?.width == 24)
    #expect(header?.height == 16)
}

@Test func aJPEGWithNoStartOfFrameBeforeScanOrEndOrABadSegmentLengthOrTruncationHasNoHeader() {
    let frame = jpegProgressiveFrameHeight16Width24
    let frameWithLength1 = [0xFF, 0xC2, 0x00, 0x01] + frame.dropFirst(4)
    let cases: [[UInt8]] = [
        jpegStartOfImage + jpegApp0 + jpegStartOfScan + frame,
        jpegStartOfImage + jpegEndOfImage + [0x00, 0x02] + frame,
        jpegStartOfImage + frame.dropFirst(),
        jpegStartOfImage + frameWithLength1,
        jpegStartOfImage + jpegApp0.prefix(5),
        jpegStartOfImage + frame.prefix(8),
        jpegStartOfImage + [0xFF, 0xFF],
    ]
    for bytes in cases {
        #expect(ImageFileHeader(fileBytes: bytes) == nil)
    }
}

@Test func bytesThatAreNeitherPNGNorJPEGHaveNoHeader() {
    var notPNG = pngStart(width: [0, 0, 0, 40], height: [0, 0, 0, 24])
    notPNG[1] = 0x51
    let notJPEG = [0xFF, 0xD9] + jpegProgressiveFrameHeight16Width24
    for bytes in [[], Array("hello, world".utf8), notPNG, notJPEG] {
        #expect(ImageFileHeader(fileBytes: bytes) == nil)
    }
}
