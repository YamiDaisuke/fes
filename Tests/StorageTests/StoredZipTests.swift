@testable import Storage
import Testing

private let mainLua = (name: "main.lua", bytes: Array("print(1)".utf8))

private enum OneEntryArchive {
    static let localHeader = 0
    static let data = 38
    static let centralHeader = 46
    static let endRecord = 100
}

private let evilMainLua = (name: "main.lua", bytes: Array("print(\"EVIL\")".utf8))
private let notes = (name: "notes.txt", bytes: Array("hi".utf8))

private func localEntry(_ entry: (name: String, bytes: [UInt8])) -> [UInt8] {
    Array(storedZip([entry]).prefix(30 + entry.name.utf8.count + entry.bytes.count))
}

private func centralHeader(_ entry: (name: String, bytes: [UInt8]), at localHeaderOffset: Int) -> [UInt8] {
    var header = Array(storedZip([entry]).dropFirst(localEntry(entry).count).dropLast(22))
    header.replaceSubrange(42..<46, with: littleEndian(UInt32(localHeaderOffset)))
    return header
}

private func archive(_ localEntries: [UInt8], centralHeaders: [[UInt8]]) -> [UInt8] {
    let directory = centralHeaders.flatMap { $0 }
    var endRecord = storedZip([])
    endRecord[8] = UInt8(centralHeaders.count)
    endRecord[10] = UInt8(centralHeaders.count)
    endRecord.replaceSubrange(12..<16, with: littleEndian(UInt32(directory.count)))
    endRecord.replaceSubrange(16..<20, with: littleEndian(UInt32(localEntries.count)))
    return localEntries + directory + endRecord
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

@Test func entryWhoseLocalHeaderIsInsideAnotherEntrysDataIsRefused() {
    let notesHidingMainLua = (name: "notes.txt", bytes: localEntry(evilMainLua))
    let insideNotesData = 30 + notesHidingMainLua.name.utf8.count
    let overlapping = archive(
        localEntry(notesHidingMainLua),
        centralHeaders: [centralHeader(notesHidingMainLua, at: 0), centralHeader(evilMainLua, at: insideNotesData)]
    )
    #expect(refusal(overlapping) == "main.lua overlaps another entry or has bytes before it")
}

@Test func bytesBetweenTwoEntriesAreRefused() {
    let gap = [UInt8](repeating: 0, count: 4)
    let withGap = archive(
        localEntry(notes) + gap + localEntry(mainLua),
        centralHeaders: [centralHeader(notes, at: 0), centralHeader(mainLua, at: localEntry(notes).count + gap.count)]
    )
    #expect(refusal(withGap) == "main.lua overlaps another entry or has bytes before it")
}

@Test func localEntryHiddenBeforeTheCentralDirectoryIsRefused() {
    let hidden = archive(localEntry(mainLua) + localEntry(evilMainLua), centralHeaders: [centralHeader(mainLua, at: 0)])
    #expect(refusal(hidden) == "there are bytes between the last entry and the central directory")
}

@Test func bytesBeforeTheFirstEntryAreRefusedEvenWithOffsetsAdjusted() {
    let stub = Array("#!/bin/sh\n".utf8)
    let prepended = archive(stub + localEntry(mainLua), centralHeaders: [centralHeader(mainLua, at: stub.count)])
    #expect(refusal(prepended) == "main.lua overlaps another entry or has bytes before it")
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
