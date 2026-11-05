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
    refusal(changing: [offset: value])
}

private func refusal(changing changes: [Int: UInt8]) -> String? {
    var archive = storedZip([mainLua])
    for (offset, value) in changes {
        archive[offset] = value
    }
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

@Test func endRecordWithAWrongCentralDirectoryOffsetIsRefused() {
    #expect(refusal(changing: OneEntryArchive.endRecord + 16, to: 47) == "the end record doesn't match the central directory")
}

@Test func endRecordWithAWrongCentralDirectorySizeIsRefused() {
    #expect(refusal(changing: OneEntryArchive.endRecord + 12, to: 10) == "the end record doesn't match the central directory")
}

@Test func centralDirectoryHoldingMoreEntriesThanTheEndRecordCountsIsRefused() {
    let noEntries = [OneEntryArchive.endRecord + 8: UInt8(0), OneEntryArchive.endRecord + 10: 0]
    #expect(refusal(changing: noEntries) == "the end record doesn't match the central directory")
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

@Test func entryWithADataDescriptorIsRefused() {
    let dataDescriptorInBothHeaders = [OneEntryArchive.localHeader + 6: UInt8(8), OneEntryArchive.centralHeader + 8: 8]
    #expect(refusal(changing: dataDescriptorInBothHeaders) == "main.lua has a data descriptor; FES reads .fes files it exported")
}

@Test func localHeaderWithAnotherNameIsRefused() {
    #expect(refusal(changing: OneEntryArchive.localHeader + 30, to: UInt8(ascii: "e")) == "main.lua's local header doesn't match the central directory")
}

@Test func localHeaderWithAnotherMethodIsRefused() {
    #expect(refusal(changing: OneEntryArchive.localHeader + 8, to: 8) == "main.lua's local header doesn't match the central directory")
}

@Test func localHeaderMarkedEncryptedIsRefused() {
    #expect(refusal(changing: OneEntryArchive.localHeader + 6, to: 1) == "main.lua's local header doesn't match the central directory")
}

@Test func localHeaderWithAnotherCRCIsRefused() {
    #expect(refusal(changing: OneEntryArchive.localHeader + 14, to: 0) == "main.lua's local header doesn't match the central directory")
}

@Test func localHeaderWithOtherSizesIsRefused() {
    let sizesOfOne = [OneEntryArchive.localHeader + 18: UInt8(1), OneEntryArchive.localHeader + 22: 1]
    #expect(refusal(changing: sizesOfOne) == "main.lua's local header doesn't match the central directory")
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
    let sizesOfNineInBothHeaders = [
        OneEntryArchive.localHeader + 18: UInt8(9), OneEntryArchive.localHeader + 22: 9,
        OneEntryArchive.centralHeader + 20: 9, OneEntryArchive.centralHeader + 24: 9,
    ]
    #expect(refusal(changing: sizesOfNineInBothHeaders) == "main.lua's data runs into the central directory")
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
