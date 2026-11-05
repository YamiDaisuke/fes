@testable import Storage
import Testing

private let mainLua = (name: "main.lua", bytes: Array("print(1)".utf8))

private enum OneEntryArchive {
    static let localHeader = 0
    static let data = 38
    static let centralHeader = 46
    static let endRecord = 100
}

private func refusal(_ archive: [UInt8]) -> String? {
    do {
        _ = try readStoredZip(archive)
        return nil
    } catch {
        return error.reason
    }
}

private func refusal(changing offset: Int, to value: UInt8) -> String? {
    var archive = storedZip([mainLua])
    archive[offset] = value
    return refusal(archive)
}

@Test func crc32OfTheStandardCheckStringIsTheStandardCheckValue() {
    #expect(crc32(Array("123456789".utf8)) == 0xCBF4_3926)
}

@Test func archiveWithACommentAfterTheEndRecordReads() throws {
    var archive = storedZip([mainLua])
    archive[OneEntryArchive.endRecord + 20] = 2
    archive += Array("hi".utf8)
    #expect(try readStoredZip(archive) == ["main.lua": mainLua.bytes])
}

@Test func archiveCutShortByOneByteHasNoEndRecord() {
    #expect(refusal(storedZip([mainLua]).dropLast()) == "not a .fes file")
}

@Test func archiveWithBytesAfterTheEndRecordHasNoEndRecord() {
    #expect(refusal(storedZip([mainLua]) + [0]) == "not a .fes file")
}

@Test func archiveOnASecondDiskIsRefused() {
    #expect(refusal(changing: OneEntryArchive.endRecord + 4, to: 1) == "the archive spans several disks")
}

@Test func archiveWithDifferentEntryCountsIsRefused() {
    #expect(refusal(changing: OneEntryArchive.endRecord + 8, to: 0) == "the archive spans several disks")
}

@Test func archiveWithMoreThan64EntriesIsRefusedAnd64Read() throws {
    let entries = (1...65).map { (name: "file\($0)", bytes: [UInt8]()) }
    #expect(refusal(storedZip(entries)) == "more than 64 entries")
    #expect(try readStoredZip(storedZip(Array(entries.dropLast()))).count == 64)
}

@Test func centralDirectoryOverlappingTheEndRecordIsRefused() {
    #expect(refusal(changing: OneEntryArchive.endRecord + 16, to: 47) == "the central directory lies outside the file")
}

@Test func damagedCentralHeaderIsRefused() {
    #expect(refusal(changing: OneEntryArchive.centralHeader, to: 0) == "an entry in the central directory is damaged")
}

@Test func encryptedEntryIsRefused() {
    #expect(refusal(changing: OneEntryArchive.centralHeader + 8, to: 1) == "main.lua is encrypted")
}

@Test func deflatedEntryIsRefused() {
    #expect(refusal(changing: OneEntryArchive.centralHeader + 10, to: 8) == "main.lua is compressed; FES reads .fes files it exported")
}

@Test func entryWhoseTwoSizesDifferIsRefused() {
    #expect(refusal(changing: OneEntryArchive.centralHeader + 20, to: 9) == "main.lua has two different sizes")
}

@Test func entryOffsetPastTheEndIsRefused() {
    #expect(refusal(changing: OneEntryArchive.centralHeader + 43, to: 0xFF) == "main.lua has no local header where the central directory says")
}

@Test func entryOffsetAtSomethingElseThanALocalHeaderIsRefused() {
    #expect(refusal(changing: OneEntryArchive.localHeader, to: 0) == "main.lua has no local header where the central directory says")
}

@Test func entryDataRunningIntoTheCentralDirectoryIsRefused() {
    var archive = storedZip([mainLua])
    archive[OneEntryArchive.centralHeader + 20] = 9
    archive[OneEntryArchive.centralHeader + 24] = 9
    #expect(refusal(archive) == "main.lua's data runs into the central directory")
}

@Test func flippedDataByteFailsTheCRC() {
    var archive = storedZip([mainLua])
    archive[OneEntryArchive.data] ^= 1
    #expect(refusal(archive) == "main.lua is damaged (its CRC doesn't match)")
}

@Test func sameEntryTwiceIsRefused() {
    #expect(refusal(storedZip([mainLua, mainLua])) == "main.lua appears twice")
}

@Test func nameLongerThanTheFileIsRefusedInsteadOfReadPastTheEnd() {
    #expect(refusal(changing: OneEntryArchive.centralHeader + 29, to: 0xFF) == "the file is cut short")
}
