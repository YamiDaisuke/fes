// Uncompressed PNG: PNG spec https://www.w3.org/TR/png/, zlib RFC 1950, stored deflate blocks RFC 1951.
func pngData(rgba: [UInt8], width: Int, height: Int) -> [UInt8] {
    var header = bigEndian(UInt32(width)) + bigEndian(UInt32(height))
    header += [8, 6, 0, 0, 0]

    let rowLength = width * 4
    var scanlines: [UInt8] = []
    for y in 0..<height {
        scanlines.append(0)
        scanlines += rgba[(y * rowLength)..<((y + 1) * rowLength)]
    }

    return [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        + chunk("IHDR", header)
        + chunk("IDAT", zlibStored(scanlines))
        + chunk("IEND", [])
}

private func zlibStored(_ data: [UInt8]) -> [UInt8] {
    var out: [UInt8] = [0x78, 0x01]
    let maxBlockLength = 65_535
    var start = 0
    repeat {
        let end = min(start + maxBlockLength, data.count)
        let length = UInt16(end - start)
        out.append(end == data.count ? 1 : 0)
        out += littleEndian(length) + littleEndian(~length)
        out += data[start..<end]
        start = end
    } while start < data.count
    return out + bigEndian(adler32(data))
}

private func chunk(_ type: String, _ data: [UInt8]) -> [UInt8] {
    let typeAndData = Array(type.utf8) + data
    return bigEndian(UInt32(data.count)) + typeAndData + bigEndian(crc32(typeAndData))
}

private func crc32(_ bytes: [UInt8]) -> UInt32 {
    var crc: UInt32 = 0xFFFF_FFFF
    for byte in bytes {
        crc ^= UInt32(byte)
        for _ in 0..<8 {
            crc = crc & 1 == 1 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
        }
    }
    return ~crc
}

private func adler32(_ bytes: [UInt8]) -> UInt32 {
    var a: UInt32 = 1
    var b: UInt32 = 0
    for byte in bytes {
        a = (a + UInt32(byte)) % 65_521
        b = (b + a) % 65_521
    }
    return (b << 16) | a
}

private func bigEndian(_ value: UInt32) -> [UInt8] {
    [UInt8(value >> 24), UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
}

private func littleEndian(_ value: UInt16) -> [UInt8] {
    [UInt8(value & 0xFF), UInt8(value >> 8)]
}
