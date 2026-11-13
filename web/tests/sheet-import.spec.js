import { test as ephemeralTest } from "@playwright/test";
import { test, expect } from "./persistent-context.js";
import { encodePNG, pngHeader } from "./png.js";

async function openArtView(page) {
  await page.goto("/");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  await page.locator("#show-art").click();
}

function rgbOf(locator) {
  return locator.evaluate((element) => getComputedStyle(element).backgroundColor.match(/\d+/g).map(Number));
}

async function previewColors(page) {
  const colors = [];
  for (let index = 0; index < 8; index++) {
    colors.push(await rgbOf(page.locator(`#art-colors [data-color='${index}']`)));
  }
  return colors;
}

function sheetTileRGB(page, tile) {
  return page.evaluate((tile) => {
    const sheet = document.getElementById("art-sheet");
    const zoom = (sheet.width - 17) / 128;
    const origin = (square) => 1 + square * (8 * zoom + 1);
    const context = sheet.getContext("2d");
    const pixels = [];
    for (let y = 0; y < 8; y++) {
      for (let x = 0; x < 8; x++) {
        const left = origin(tile % 16) + x * zoom + Math.floor(zoom / 2);
        const top = origin(Math.floor(tile / 16)) + y * zoom + Math.floor(zoom / 2);
        pixels.push([...context.getImageData(left, top, 1, 1).data.slice(0, 3)]);
      }
    }
    return pixels;
  }, tile);
}

const sheetImage = (page) => page.evaluate(() => document.getElementById("art-sheet").toDataURL());

function screenTopLeftTile(page) {
  return page.evaluate(() => {
    const pixels = document.getElementById("screen").getContext("2d").getImageData(0, 0, 8, 8).data;
    return Array.from({ length: 64 }, (_, i) => [...pixels.slice(i * 4, i * 4 + 3)]);
  });
}

function opaquePixelsMatch(pixels, colorAt) {
  return pixels.every((pixel, i) => {
    const expected = colorAt(i % 8, Math.floor(i / 8));
    return !expected || pixel.join() === expected.join();
  });
}

function imagePixels(width, height, colorAt) {
  const rgba = new Uint8Array(width * height * 4);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const color = colorAt(x, y);
      rgba.set(color ? [...color, 255] : [0, 0, 0, 0], (y * width + x) * 4);
    }
  }
  return rgba;
}

const isTransparentPixel = (x, y) => (x + 2 * y) % 5 === 0;

test.describe("with a cart that draws sprite tile 17", () => {
  test.beforeEach(async ({ page }) => {
    await page.addInitScript(() => {
      window.testCartMainLua = "function _draw() cls() spr(17, 0, 0, 2) end";
    });
  });

  test("an imported PNG fills the sprite bank at its tile positions with exact colors, runs, and is one undo step", async ({ page }) => {
    await openArtView(page);
    await page.getByRole("button", { name: "Sprites" }).click();
    await page.getByRole("button", { name: "Palette 2" }).click();
    const colors = await previewColors(page);
    const colorAt = (x, y) => (isTransparentPixel(x, y) ? null : colors[1 + ((x + y) % 7)]);
    const png = encodePNG(16, 16, imagePixels(16, 16, colorAt));
    const sheetBefore = await sheetImage(page);
    const questions = [];
    page.on("dialog", (dialog) => {
      questions.push(dialog.message());
      dialog.accept();
    });

    await page.locator("#art-import-file").setInputFiles({ name: "sheet.png", mimeType: "image/png", buffer: png });

    await expect(page.locator("#cart-status")).toHaveText("Imported sheet.png into the sprite tiles.");
    expect(questions).toEqual(["Replace all 256 sprite tiles with sheet.png? Undo puts them back."]);
    const tile17Color = (x, y) => colorAt(8 + x, 8 + y);
    expect(opaquePixelsMatch(await sheetTileRGB(page, 17), tile17Color)).toBe(true);
    const sheetAfter = await sheetImage(page);
    expect(await page.evaluate(() => fesStorage.readRecoveryCopy())).not.toBeNull();

    await page.getByRole("button", { name: "Undo sheet import" }).click();
    expect(await sheetImage(page)).toBe(sheetBefore);
    await page.getByRole("button", { name: "Redo sheet import" }).click();
    expect(await sheetImage(page)).toBe(sheetAfter);

    await page.getByRole("button", { name: "Run" }).click();
    await expect.poll(async () => opaquePixelsMatch(await screenTopLeftTile(page), tile17Color)).toBe(true);

    await page.reload();
    await expect.poll(() => questions.at(-1)).toBe("Restore unsaved changes to Demo?");
    await expect(page.locator("#cart-status")).toHaveText("Restored unsaved changes to Demo.");
    await page.locator("#show-art").click();
    await page.getByRole("button", { name: "Sprites" }).click();
    await page.getByRole("button", { name: "Palette 2" }).click();
    expect(await sheetImage(page)).toBe(sheetAfter);
  });
});

ephemeralTest("cancelling the confirm changes nothing and adds no undo step", async ({ page }) => {
  await openArtView(page);
  const colors = await previewColors(page);
  const sheetBefore = await sheetImage(page);
  const statusBefore = await page.locator("#cart-status").textContent();
  const questions = [];
  page.on("dialog", (dialog) => {
    questions.push(dialog.message());
    dialog.dismiss();
  });

  const png = encodePNG(8, 8, imagePixels(8, 8, () => colors[1]));
  await page.locator("#art-import-file").setInputFiles({ name: "sheet.png", mimeType: "image/png", buffer: png });

  await expect.poll(() => questions).toHaveLength(1);
  await expect(page.locator("#cart-status")).toHaveText(statusBefore);
  expect(await sheetImage(page)).toBe(sheetBefore);
  await expect(page.getByRole("button", { name: "Undo", exact: true })).toHaveAttribute("aria-disabled", "true");
});

ephemeralTest("a 9-color tile is refused with a report naming it, and Close returns focus to Import sheet", async ({ page }) => {
  await openArtView(page);
  await page.getByRole("button", { name: "Background" }).click();
  const [backgroundColor] = await previewColors(page);
  await page.getByRole("button", { name: "Palettes" }).click();
  const mainColors = [];
  for (const swatch of await page.locator("#art-main-colors button").all()) {
    mainColors.push(await rgbOf(swatch));
  }
  await page.getByRole("button", { name: "Palettes" }).click();
  const nineColors = [...new Map(mainColors.map((color) => [color.join(), color])).values()].slice(0, 9);
  expect(nineColors).toHaveLength(9);
  const colorAt = (x, y) => (x < 8 ? backgroundColor : nineColors[(x + y * 8) % 9]);
  const png = encodePNG(16, 8, imagePixels(16, 8, colorAt));
  const sheetBefore = await sheetImage(page);

  await page.locator("#art-import-file").setInputFiles({ name: "busy.png", mimeType: "image/png", buffer: png });

  const report = page.getByRole("dialog", { name: "Can't import busy.png" });
  await expect(report).toBeVisible();
  await expect(report.getByRole("button", { name: "Close" })).toBeFocused();
  await expect(report.getByRole("listitem")).toHaveText(["Tile at column 1, row 0 (from pixel 8, 0): 9 colors. A background tile can use 8."]);
  await expect(report.locator("canvas")).toBeVisible();
  await expect(report.locator("canvas")).toHaveAttribute("aria-hidden", "true");
  const topEdges = await report.locator("canvas").evaluate((canvas) => {
    const zoom = (canvas.width - 17) / 128;
    const topEdgeMiddle = (square) => canvas.getContext("2d").getImageData(square * (8 * zoom + 1) + 4 * zoom, 0, 1, 1).data.join();
    return [zoom, topEdgeMiddle(0), topEdgeMiddle(1)];
  });
  expect(topEdges).toEqual([3, expect.not.stringMatching("255,48,48,255"), "255,48,48,255"]);
  expect(await report.locator("canvas").boundingBox()).toMatchObject({ width: 401, height: 401 });
  await expect(page.locator("#art-import-report-hint")).toBeHidden();
  expect(await sheetImage(page)).toBe(sheetBefore);

  await report.getByRole("button", { name: "Close" }).click();
  await expect(report).toBeHidden();
  await expect(page.getByRole("button", { name: "Import sheet" })).toBeFocused();
});

ephemeralTest("a JPEG's report says to export PNG, and Escape closes it", async ({ page }) => {
  await openArtView(page);
  const jpeg = await page.evaluate(async () => {
    const canvas = new OffscreenCanvas(16, 16);
    const context = canvas.getContext("2d");
    const gradient = context.createLinearGradient(0, 0, 16, 16);
    gradient.addColorStop(0, "#123456");
    gradient.addColorStop(1, "#fedcba");
    context.fillStyle = gradient;
    context.fillRect(0, 0, 16, 16);
    const blob = await canvas.convertToBlob({ type: "image/jpeg" });
    return [...new Uint8Array(await blob.arrayBuffer())];
  });

  await page.locator("#art-import-file").setInputFiles({ name: "sheet.jpg", mimeType: "image/jpeg", buffer: Buffer.from(jpeg) });

  const report = page.getByRole("dialog", { name: "Can't import sheet.jpg" });
  await expect(report).toBeVisible();
  await expect(report).toContainText("Export the sheet from your art app as PNG and import that.");
  await page.keyboard.press("Escape");
  await expect(report).toBeHidden();
  await expect(page.getByRole("button", { name: "Import sheet" })).toBeFocused();
});

ephemeralTest("a PNG claiming 20000 × 20000 pixels is refused from its header without decoding", async ({ page }) => {
  await openArtView(page);
  const bomb = Buffer.concat([pngHeader(20000, 20000), Buffer.from("not a deflate stream")]);

  await page.locator("#art-import-file").setInputFiles({ name: "bomb.png", mimeType: "image/png", buffer: bomb });

  const report = page.getByRole("dialog", { name: "Can't import bomb.png" });
  await expect(report.getByRole("listitem")).toHaveText(["The image is 20000 × 20000 pixels. A sheet is at most 128 × 128."]);
  await expect(report.locator("canvas")).toBeHidden();
  await expect(page.locator("#cart-status")).not.toContainText("decode");
});

ephemeralTest("files that aren't images, or are over 1 MiB, are refused in the status line", async ({ page }) => {
  await openArtView(page);
  const input = page.locator("#art-import-file");

  await input.setInputFiles({ name: "x.png", mimeType: "image/png", buffer: Buffer.from("just text") });
  await expect(page.locator("#cart-status")).toHaveText("Can't import x.png: it isn't a PNG or JPEG image.");

  await input.setInputFiles({ name: "x", mimeType: "image/png", buffer: Buffer.alloc(2 << 20) });
  await expect(page.locator("#cart-status")).toHaveText("Can't import x: larger than 1 MiB.");
});
