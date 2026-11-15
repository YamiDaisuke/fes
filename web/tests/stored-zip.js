import { crc32 } from "node:zlib";

const january1st1980 = 0x0021;

// Store-only zip, the shape FES exports: PKWARE APPNOTE sections 4.3.7, 4.3.12, 4.3.16.
export function storedZip(files) {
  const entries = [];
  const centralDirectory = [];
  let offset = 0;
  for (const [name, text] of Object.entries(files)) {
    const nameBytes = Buffer.from(name);
    const data = Buffer.from(text);
    const writeFieldsInBothHeaders = (header, flagsAt) => {
      header.writeUInt16LE(january1st1980, flagsAt + 6);
      header.writeUInt32LE(crc32(data), flagsAt + 8);
      header.writeUInt32LE(data.length, flagsAt + 12);
      header.writeUInt32LE(data.length, flagsAt + 16);
      header.writeUInt16LE(nameBytes.length, flagsAt + 20);
    };
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(10, 4);
    writeFieldsInBothHeaders(local, 6);
    const central = Buffer.alloc(46);
    central.writeUInt32LE(0x02014b50, 0);
    central.writeUInt16LE(20, 4);
    central.writeUInt16LE(10, 6);
    writeFieldsInBothHeaders(central, 8);
    central.writeUInt32LE(offset, 42);
    entries.push(local, nameBytes, data);
    centralDirectory.push(central, nameBytes);
    offset += local.length + nameBytes.length + data.length;
  }
  const directory = Buffer.concat(centralDirectory);
  const entryCount = Object.keys(files).length;
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(entryCount, 8);
  end.writeUInt16LE(entryCount, 10);
  end.writeUInt32LE(directory.length, 12);
  end.writeUInt32LE(offset, 16);
  return Buffer.concat([...entries, directory, end]);
}
