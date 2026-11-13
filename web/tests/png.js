import { crc32, deflateSync } from "node:zlib";

function chunk(type, data) {
  const typeAndData = Buffer.concat([Buffer.from(type, "latin1"), data]);
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(typeAndData));
  return Buffer.concat([length, typeAndData, crc]);
}

export const pngSignature = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

const bitDepth = 8;
const rgbaColorType = 6;

export function pngHeader(width, height) {
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header[8] = bitDepth;
  header[9] = rgbaColorType;
  return Buffer.concat([pngSignature, chunk("IHDR", header)]);
}

export function encodePNG(width, height, rgba) {
  const rows = [];
  for (let y = 0; y < height; y++) {
    rows.push(Buffer.from([0]), Buffer.from(rgba.subarray(y * width * 4, (y + 1) * width * 4)));
  }
  return Buffer.concat([pngHeader(width, height), chunk("IDAT", deflateSync(Buffer.concat(rows))), chunk("IEND", Buffer.alloc(0))]);
}
