// Store-only zip: PKWARE APPNOTE https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT sections 4.3.7, 4.3.12, 4.3.16.
private let localHeaderSignature: UInt32 = 0x0403_4B50
private let centralHeaderSignature: UInt32 = 0x0201_4B50
private let endRecordSignature: UInt32 = 0x0605_4B50
private let localHeaderLength = 30
private let centralHeaderLength = 46
private let endRecordLength = 22
private let mostEntries = 64
private let encryptedFlag = 1
private let storedMethod = 0
private let versionNeeded: UInt16 = 10
private let versionMadeBy: UInt16 = 20
private let midnight: UInt16 = 0
private let january1st1980: UInt16 = 0x0021

public struct ArchiveError: Error, CustomStringConvertible {
    public var reason: String

    init(_ reason: String) {
        self.reason = reason
    }

    public var description: String { reason }
}

func storedZip(_ entries: [(name: String, bytes: [UInt8])]) -> [UInt8] {
    var archive: [UInt8] = []
    var centralDirectory: [UInt8] = []
    for entry in entries {
        let name = Array(entry.name.utf8)
        let size = littleEndian(UInt32(entry.bytes.count))
        let fieldsInBothHeaders =
            littleEndian(UInt16(0)) + littleEndian(UInt16(storedMethod)) + littleEndian(midnight) + littleEndian(january1st1980)
            + littleEndian(crc32(entry.bytes)) + size + size
            + littleEndian(UInt16(name.count)) + littleEndian(UInt16(0))
        let localHeaderOffset = UInt32(archive.count)

        archive += littleEndian(localHeaderSignature) + littleEndian(versionNeeded) + fieldsInBothHeaders
        archive += name + entry.bytes

        let noComment = littleEndian(UInt16(0))
        let diskZero = littleEndian(UInt16(0))
        let noAttributes = littleEndian(UInt16(0)) + littleEndian(UInt32(0))
        centralDirectory += littleEndian(centralHeaderSignature) + littleEndian(versionMadeBy) + littleEndian(versionNeeded)
        centralDirectory += fieldsInBothHeaders + noComment + diskZero + noAttributes + littleEndian(localHeaderOffset) + name
    }
    let centralDirectoryOffset = UInt32(archive.count)
    let entryCount = littleEndian(UInt16(entries.count))
    archive += centralDirectory
    archive += littleEndian(endRecordSignature) + littleEndian(UInt16(0)) + littleEndian(UInt16(0)) + entryCount + entryCount
    archive += littleEndian(UInt32(centralDirectory.count)) + littleEndian(centralDirectoryOffset) + littleEndian(UInt16(0))
    return archive
}

func readStoredZip(_ archive: [UInt8]) throws(ArchiveError) -> [String: [UInt8]] {
    let end = try endRecordOffset(archive)
    guard try uint16(archive, at: end + 4) == 0, try uint16(archive, at: end + 6) == 0 else {
        throw ArchiveError("the archive spans several disks")
    }
    let entryCount = try uint16(archive, at: end + 10)
    guard try uint16(archive, at: end + 8) == entryCount else {
        throw ArchiveError("the archive spans several disks")
    }
    guard entryCount <= mostEntries else {
        throw ArchiveError("more than \(mostEntries) entries")
    }
    let directorySize = try offsetOrLength(archive, at: end + 12)
    let directoryStart = try offsetOrLength(archive, at: end + 16)
    guard directoryStart <= end, directorySize <= end - directoryStart else {
        throw ArchiveError("the central directory lies outside the file")
    }

    var files: [String: [UInt8]] = [:]
    var header = directoryStart
    for _ in 0..<entryCount {
        guard try uint32(archive, at: header) == centralHeaderSignature else {
            throw ArchiveError("an entry in the central directory is damaged")
        }
        let flags = try uint16(archive, at: header + 8)
        let method = try uint16(archive, at: header + 10)
        let expectedCRC = try uint32(archive, at: header + 16)
        let compressedSize = try offsetOrLength(archive, at: header + 20)
        let size = try offsetOrLength(archive, at: header + 24)
        let nameLength = try uint16(archive, at: header + 28)
        let extraLength = try uint16(archive, at: header + 30)
        let commentLength = try uint16(archive, at: header + 32)
        let localHeader = try offsetOrLength(archive, at: header + 42)
        let name = String(decoding: try bytes(archive, from: header + centralHeaderLength, count: nameLength), as: UTF8.self)

        guard flags & encryptedFlag == 0 else {
            throw ArchiveError("\(name) is encrypted")
        }
        guard method == storedMethod else {
            throw ArchiveError("\(name) is compressed; FES reads .fes files it exported")
        }
        guard compressedSize == size else {
            throw ArchiveError("\(name) has two different sizes")
        }
        guard localHeader <= directoryStart - localHeaderLength, try uint32(archive, at: localHeader) == localHeaderSignature else {
            throw ArchiveError("\(name) has no local header where the central directory says")
        }
        let dataStart = localHeader + localHeaderLength
            + (try uint16(archive, at: localHeader + 26)) + (try uint16(archive, at: localHeader + 28))
        guard dataStart <= directoryStart, size <= directoryStart - dataStart else {
            throw ArchiveError("\(name)'s data runs into the central directory")
        }
        let data = Array(archive[dataStart..<(dataStart + size)])
        guard crc32(data) == expectedCRC else {
            throw ArchiveError("\(name) is damaged (its CRC doesn't match)")
        }
        guard files[name] == nil else {
            throw ArchiveError("\(name) appears twice")
        }
        files[name] = data
        header += centralHeaderLength + nameLength + extraLength + commentLength
    }
    return files
}

private func endRecordOffset(_ archive: [UInt8]) throws(ArchiveError) -> Int {
    let lastPossible = archive.count - endRecordLength
    let longestComment = Int(UInt16.max)
    var offset = lastPossible
    while offset >= max(0, lastPossible - longestComment) {
        if try uint32(archive, at: offset) == endRecordSignature, try uint16(archive, at: offset + 20) == lastPossible - offset {
            return offset
        }
        offset -= 1
    }
    throw ArchiveError("not a .fes file")
}

private func bytes(_ archive: [UInt8], from start: Int, count: Int) throws(ArchiveError) -> ArraySlice<UInt8> {
    guard count <= archive.count - start else {
        throw ArchiveError("the file is cut short")
    }
    return archive[start..<(start + count)]
}

private func uint16(_ archive: [UInt8], at offset: Int) throws(ArchiveError) -> Int {
    let field = try bytes(archive, from: offset, count: 2)
    return Int(field[offset]) | Int(field[offset + 1]) << 8
}

private func uint32(_ archive: [UInt8], at offset: Int) throws(ArchiveError) -> UInt32 {
    let field = try bytes(archive, from: offset, count: 4)
    return (0..<4).reduce(0) { value, index in value | UInt32(field[offset + index]) << (8 * index) }
}

private func offsetOrLength(_ archive: [UInt8], at offset: Int) throws(ArchiveError) -> Int {
    guard let value = Int(exactly: try uint32(archive, at: offset)) else {
        throw ArchiveError("the file is cut short")
    }
    return value
}

private func littleEndian(_ value: UInt16) -> [UInt8] {
    [UInt8(value & 0xFF), UInt8(value >> 8)]
}

private func littleEndian(_ value: UInt32) -> [UInt8] {
    [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF), UInt8((value >> 16) & 0xFF), UInt8(value >> 24)]
}
