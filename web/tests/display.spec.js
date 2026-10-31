import { test, expect } from "@playwright/test";
import { readFileSync } from "node:fs";
import { inflateSync } from "node:zlib";
import { openPaused, runFrames } from "./frames.js";

function readGoldenRGBA(name) {
  const png = readFileSync(new URL(`../../Tests/ConsoleTests/Golden/${name}.png`, import.meta.url));
  let width = 0;
  const compressed = [];
  for (let offset = 8; offset < png.length; ) {
    const length = png.readUInt32BE(offset);
    const type = png.toString("ascii", offset + 4, offset + 8);
    const data = png.subarray(offset + 8, offset + 8 + length);
    if (type === "IHDR") width = data.readUInt32BE(0);
    if (type === "IDAT") compressed.push(data);
    offset += 12 + length;
  }
  const filtered = inflateSync(Buffer.concat(compressed));
  const rowLength = width * 4;
  const rows = [];
  for (let row = 0; row < filtered.length; row += rowLength + 1) {
    expect(filtered[row], "PNG filter type").toBe(0);
    rows.push(filtered.subarray(row + 1, row + 1 + rowLength));
  }
  return { width, rgba: Buffer.concat(rows) };
}

function firstMismatch(browser, golden, width) {
  for (let i = 0; i < golden.length; i += 4) {
    const browserPixel = browser.slice(i, i + 4);
    const goldenPixel = Array.from(golden.subarray(i, i + 4));
    if (browserPixel.some((value, channel) => value !== goldenPixel[channel])) {
      const pixel = i / 4;
      return { x: pixel % width, y: Math.floor(pixel / width), browser: browserPixel, golden: goldenPixel };
    }
  }
  return null;
}

test("frame 60 of the test scene matches the native golden", async ({ page }) => {
  await openPaused(page);
  const framesZeroThroughSixty = 61;
  await runFrames(page, framesZeroThroughSixty);

  const browser = await page.evaluate(() => {
    const canvas = document.getElementById("screen");
    return Array.from(canvas.getContext("2d").getImageData(0, 0, canvas.width, canvas.height).data);
  });
  const golden = readGoldenRGBA("test-scene-frame-60");

  expect(browser.length).toBe(golden.rgba.length);
  expect(firstMismatch(browser, golden.rgba, golden.width)).toBeNull();
});
