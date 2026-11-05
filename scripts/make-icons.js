import { deflateSync, crc32 } from "node:zlib";
import { writeFileSync } from "node:fs";

const art = [
  "................",
  "................",
  "................",
  "................",
  ".####.####..###.",
  ".#....#....#....",
  ".###..###..#....",
  ".#....#.....##..",
  ".#....#.......#.",
  ".#....####.###..",
  "................",
  "..============..",
  "..============..",
  "................",
  "................",
  "................",
];

const colors = {
  ".": [0x14, 0x18, 0x2e],
  "#": [0xf4, 0xf4, 0xf4],
  "=": [0xe8, 0x3b, 0x3b],
};

function chunk(type, data) {
  const typeAndData = Buffer.concat([Buffer.from(type, "ascii"), data]);
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(typeAndData));
  return Buffer.concat([length, typeAndData, crc]);
}

function iconPNG(size) {
  const scale = Math.floor(size / 16);
  const offset = Math.floor((size - 16 * scale) / 2);
  const rowBytes = 1 + size * 3;
  const pixels = Buffer.alloc(size * rowBytes);
  for (let y = 0; y < size; y++) {
    pixels[y * rowBytes] = 0;
    for (let x = 0; x < size; x++) {
      const artRow = art[Math.floor((y - offset) / scale)];
      const symbol = artRow?.[Math.floor((x - offset) / scale)] ?? ".";
      pixels.set(colors[symbol], y * rowBytes + 1 + x * 3);
    }
  }
  const header = Buffer.alloc(13);
  header.writeUInt32BE(size, 0);
  header.writeUInt32BE(size, 4);
  header[8] = 8;
  header[9] = 2;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", header),
    chunk("IDAT", deflateSync(pixels)),
    chunk("IEND", Buffer.alloc(0)),
  ]);
}

for (const size of [180, 512]) {
  writeFileSync(new URL(`../web/icons/icon-${size}.png`, import.meta.url), iconPNG(size));
}
