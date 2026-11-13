import { test as ephemeralTest, expect } from "@playwright/test";
import { test } from "./persistent-context.js";
import { typeCode } from "./code-editor.js";

async function openArtView(page) {
  await page.goto("/");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  await page.locator("#show-art").click();
}

function sheetTileCenter(page, tile) {
  return page.evaluate((tile) => {
    const zoom = (document.getElementById("art-sheet").width - 17) / 128;
    const origin = (square) => 1 + square * (8 * zoom + 1);
    return { x: origin(tile % 16) + 4 * zoom, y: origin(Math.floor(tile / 16)) + 4 * zoom };
  }, tile);
}

function editAreaShowsSheetTile(page, tile) {
  return page.evaluate((tile) => {
    const pixelAt = (canvas, x, y) => canvas.getContext("2d").getImageData(x, y, 1, 1).data.join();
    const sheet = document.getElementById("art-sheet");
    const edit = document.getElementById("art-edit");
    const sheetZoom = (sheet.width - 17) / 128;
    const editZoom = (edit.width - 9) / 8;
    const sheetLeft = 1 + (tile % 16) * (8 * sheetZoom + 1);
    const sheetTop = 1 + Math.floor(tile / 16) * (8 * sheetZoom + 1);
    for (let y = 0; y < 8; y++) {
      for (let x = 0; x < 8; x++) {
        const fromSheet = pixelAt(sheet, sheetLeft + x * sheetZoom, sheetTop + y * sheetZoom);
        const fromEdit = pixelAt(edit, 1 + x * (editZoom + 1) + editZoom / 2, 1 + y * (editZoom + 1) + editZoom / 2);
        if (fromSheet !== fromEdit) return false;
      }
    }
    return true;
  }, tile);
}

function sheetTilePixels(page, tile) {
  return page.evaluate((tile) => {
    const sheet = document.getElementById("art-sheet");
    const zoom = (sheet.width - 17) / 128;
    const origin = (square) => 1 + square * (8 * zoom + 1);
    const side = 8 * zoom;
    return sheet.getContext("2d").getImageData(origin(tile % 16), origin(Math.floor(tile / 16)), side, side).data.join();
  }, tile);
}

const sheetPixels = (page) => page.evaluate(() => document.getElementById("art-sheet").toDataURL());

ephemeralTest("tapping a tile in the sheet shows it in the edit area", async ({ page }) => {
  await openArtView(page);
  expect(await editAreaShowsSheetTile(page, 1)).toBe(false);

  await page.locator("#art-sheet").click({ position: await sheetTileCenter(page, 1) });
  await expect(page.locator("#art-tile")).toHaveAttribute("aria-valuetext", "1, column 1, row 0");
  expect(await editAreaShowsSheetTile(page, 1)).toBe(true);
});

ephemeralTest("the bank and palette buttons recolor the sheet and show which is pressed", async ({ page }) => {
  await openArtView(page);
  const background = page.getByRole("button", { name: "Background" });
  const sprites = page.getByRole("button", { name: "Sprites" });
  await expect(background).toHaveAttribute("aria-pressed", "true");
  const backgroundSheet = await sheetPixels(page);

  await sprites.click();
  await expect(sprites).toHaveAttribute("aria-pressed", "true");
  await expect(background).toHaveAttribute("aria-pressed", "false");
  const spriteSheet = await sheetPixels(page);
  expect(spriteSheet).not.toBe(backgroundSheet);

  await page.getByRole("button", { name: "Palette 3" }).click();
  await expect(page.getByRole("button", { name: "Palette 3" })).toHaveAttribute("aria-pressed", "true");
  await expect(page.getByRole("button", { name: "Palette 0" })).toHaveAttribute("aria-pressed", "false");
  expect(await sheetPixels(page)).not.toBe(spriteSheet);
});

ephemeralTest("the tile slider selects tiles from the keyboard", async ({ page }) => {
  await openArtView(page);
  await page.locator("#art-tile").focus();
  await page.keyboard.press("ArrowRight");
  await expect(page.locator("#art-tile")).toHaveAttribute("aria-valuetext", "1, column 1, row 0");
  await expect(page.locator("#art-tile-number")).toHaveText("1");
  expect(await editAreaShowsSheetTile(page, 1)).toBe(true);
});

ephemeralTest("pressing Art from the keyboard moves focus to the tile slider", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  await page.locator("#show-art").focus();
  await page.keyboard.press("Enter");
  await expect(page.locator("#art-tile")).toBeFocused();
});

test("Save works from the art view", async ({ page }) => {
  await openArtView(page);
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Demo.");
});

test("loading a cart while the art view is shown redraws the sheet in its colors", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  await page.getByRole("button", { name: "Code" }).click();
  await page.locator("#cart-name").fill("Recolored");
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Recolored.");
  await page.evaluate(async () => {
    const [folder] = await fesStorage.listCartFolders();
    await fesStorage.writeCartFile(folder, "main-palette.hex", "123456\n".repeat(64));
  });
  await page.locator("#show-art").click();
  const demoSheet = await sheetPixels(page);

  await page.locator("#cart-list").getByRole("button", { name: "Recolored", includeHidden: true }).dispatchEvent("click");
  await expect(page.locator("#cart-status")).toHaveText("Loaded Recolored.");
  expect(await sheetPixels(page)).not.toBe(demoSheet);
});

ephemeralTest("leaving the game through the art view still shows the runtime error on its line in Code", async ({ page }) => {
  await page.addInitScript(() => {
    window.testCartMainLua = "x = 1\nfunction _update()\n  missing()\nend";
  });
  await page.goto("/");
  await expect(page.locator("#cart-error")).toContainText("main.lua:3:");

  await page.locator("#show-art").click();
  await page.getByRole("button", { name: "Code" }).click();
  await expect(page.locator("#code-error")).toContainText("main.lua:3:");
  await expect(page.locator(".cm-activeLine")).toHaveText("  missing()");
});

ephemeralTest("going through the art view doesn't put an old run's error on edited code", async ({ page }) => {
  await page.addInitScript(() => {
    window.testCartMainLua = "function _update() missing() end";
  });
  await page.goto("/");
  await expect(page.locator("#cart-error")).toContainText("main.lua:1:");
  await page.getByRole("button", { name: "Code" }).click();
  await expect(page.locator("#code-error")).toContainText("main.lua:1:");
  await typeCode(page, "x = 1");
  await expect(page.locator("#code-error")).toBeEmpty();

  await page.locator("#show-art").click();
  await page.getByRole("button", { name: "Code" }).click();
  await expect(page.locator("#code-error")).toBeEmpty();
});

async function editPixelPoint(page, x, y, squares = 8) {
  const box = await page.locator("#art-edit").boundingBox();
  const zoom = await page.evaluate((squares) => (document.getElementById("art-edit").width - squares - 1) / squares, squares);
  return { x: box.x + 1 + x * (zoom + 1) + zoom / 2, y: box.y + 1 + y * (zoom + 1) + zoom / 2 };
}

function editRowColors(page, y) {
  return page.evaluate((y) => {
    const edit = document.getElementById("art-edit");
    const zoom = (edit.width - 9) / 8;
    const context = edit.getContext("2d");
    const centerOf = (square) => 1 + square * (zoom + 1) + zoom / 2;
    return [0, 1, 2, 3, 4, 5, 6, 7].map((x) => context.getImageData(centerOf(x), centerOf(y), 1, 1).data.join());
  }, y);
}

async function drag(page, from, to, squares = 8) {
  const start = await editPixelPoint(page, ...from, squares);
  const end = await editPixelPoint(page, ...to, squares);
  await page.mouse.move(start.x, start.y);
  await page.mouse.down();
  await page.mouse.move(end.x, end.y, { steps: 1 });
  await page.mouse.up();
}

async function showTile(page, bank, tile) {
  await page.getByRole("button", { name: bank }).click();
  await page.locator("#art-tile").fill(String(tile));
  await expect(page.locator("#art-tile-number")).toHaveText(String(tile));
}

function editAreaRingsPixel(page, x, y) {
  return page.evaluate(([x, y]) => {
    const edit = document.getElementById("art-edit");
    const zoom = (edit.width - 9) / 8;
    const ringTop = y * (zoom + 1);
    return edit.getContext("2d").getImageData(1 + x * (zoom + 1) + zoom / 2, ringTop, 1, 1).data.join() === "255,255,255,255";
  }, [x, y]);
}

const editTileColors = (page) => Promise.all([0, 1, 2, 3, 4, 5, 6, 7].map((y) => editRowColors(page, y)));

async function pressMouseOnPixel(page, x, y) {
  const point = await editPixelPoint(page, x, y);
  await page.mouse.move(point.x, point.y);
  await page.mouse.down();
}

const mousePointerId = 1;

const nextFrame = (page) => page.evaluate(() => new Promise((resolve) => requestAnimationFrame(resolve)));

function cancelMouseStroke(page) {
  return page
    .locator("#art-edit")
    .evaluate((canvas, pointerId) => canvas.dispatchEvent(new PointerEvent("pointercancel", { pointerId })), mousePointerId);
}

ephemeralTest("one fast drag paints every pixel between its ends and nothing around them", async ({ page }) => {
  await openArtView(page);
  await showTile(page, "Background", 2);
  const blankRow = await editRowColors(page, 3);

  await drag(page, [0, 2], [7, 2]);
  await expect.poll(async () => (await editRowColors(page, 2))[0]).not.toBe(blankRow[0]);
  expect(new Set(await editRowColors(page, 2)).size).toBe(1);
  expect(await editRowColors(page, 3)).toEqual(blankRow);
  expect(await editAreaShowsSheetTile(page, 2)).toBe(true);
});

ephemeralTest("a cancelled stroke puts the tile back as it was", async ({ page }) => {
  await openArtView(page);
  await showTile(page, "Background", 2);
  const blankTile = await editTileColors(page);

  await pressMouseOnPixel(page, 0, 2);
  const end = await editPixelPoint(page, 7, 2);
  await page.mouse.move(end.x, end.y, { steps: 1 });
  await expect.poll(() => editTileColors(page)).not.toEqual(blankTile);
  await cancelMouseStroke(page);
  await page.mouse.up();

  await expect.poll(() => editTileColors(page)).toEqual(blankTile);
  expect(await editAreaShowsSheetTile(page, 2)).toBe(true);
});

ephemeralTest("a stroke paints nothing more after the art view is left", async ({ page }) => {
  await openArtView(page);
  await showTile(page, "Background", 2);
  await pressMouseOnPixel(page, 1, 1);
  await expect.poll(async () => new Set(await editRowColors(page, 1)).size).toBe(2);
  const tapped = await editTileColors(page);

  await page.locator("#show-code").dispatchEvent("click");
  for (const position of [100, 200, 300, 400]) {
    await page.mouse.move(position, position);
  }
  await page.mouse.up();
  await page.locator("#show-art").click();
  await nextFrame(page);

  expect(await editTileColors(page)).toEqual(tapped);
});

ephemeralTest("the picker selects the color under the pointer and hands back to the pencil", async ({ page }) => {
  await openArtView(page);
  await showTile(page, "Background", 2);
  await page.getByRole("button", { name: "Picker" }).click();

  await drag(page, [3, 3], [3, 3]);
  await expect(page.getByRole("button", { name: "Color 0" })).toHaveAttribute("aria-pressed", "true");
  await expect(page.getByRole("button", { name: "Pencil" })).toHaveAttribute("aria-pressed", "true");
});

ephemeralTest("a picker drag from an edge pixel to past the edit area keeps that pixel's color", async ({ page }) => {
  const pageErrors = [];
  page.on("pageerror", (error) => pageErrors.push(error.message));
  await openArtView(page);
  await showTile(page, "Background", 2);
  await page.getByRole("button", { name: "Color 5" }).click();
  await drag(page, [7, 3], [7, 3]);
  await page.getByRole("button", { name: "Color 2" }).click();
  await page.getByRole("button", { name: "Picker" }).click();

  const start = await editPixelPoint(page, 7, 3);
  const box = await page.locator("#art-edit").boundingBox();
  await page.mouse.move(start.x, start.y);
  await page.mouse.down();
  await page.mouse.move(box.x + box.width + 40, start.y, { steps: 1 });
  await page.mouse.up();

  await expect(page.getByRole("button", { name: "Color 5" })).toHaveAttribute("aria-pressed", "true");
  await expect(page.getByRole("button", { name: "Pencil" })).toHaveAttribute("aria-pressed", "true");
  await showTile(page, "Background", 3);
  expect(pageErrors).toEqual([]);
});

test.describe("with a cart that draws sprite tile 2", () => {
  test.beforeEach(async ({ page }) => {
    await page.addInitScript(() => {
      window.testCartMainLua = "function _draw() cls() spr(2, 0, 0) end";
    });
  });

  test("a drawn sprite shows in Run, and is still there after Save and a reload", async ({ page }) => {
    await openArtView(page);
    await showTile(page, "Sprites", 2);
    await page.getByRole("button", { name: "Color 3" }).click();
    await drag(page, [0, 0], [0, 0]);
    await expect.poll(async () => new Set(await editRowColors(page, 0)).size).toBe(2);
    const drawnColor = (await editRowColors(page, 0))[0];

    await page.getByRole("button", { name: "Run" }).click();
    await expect
      .poll(() => page.evaluate(() => document.getElementById("screen").getContext("2d").getImageData(0, 0, 1, 1).data.join()))
      .toBe(drawnColor);

    await page.getByRole("button", { name: "Code" }).click();
    await page.locator("#cart-name").fill("Painted");
    await page.getByRole("button", { name: "Save", exact: true }).click();
    await expect(page.locator("#cart-status")).toHaveText("Saved Painted.");
    await page.reload();
    await page.locator("#cart-list").getByRole("button", { name: "Painted", includeHidden: true }).dispatchEvent("click");
    await expect(page.locator("#cart-status")).toHaveText("Loaded Painted.");
    await page.locator("#show-art").click();
    await showTile(page, "Sprites", 2);
    expect((await editRowColors(page, 0))[0]).toBe(drawnColor);
  });

  test("unsaved drawing and code come back after a reload", async ({ page }) => {
    await page.goto("/");
    await expect(page.locator("#cart-name")).toHaveValue("Demo");
    await page.getByRole("button", { name: "Code" }).click();
    await page.locator("#cart-name").fill("Mine");
    await page.getByRole("button", { name: "Save", exact: true }).click();
    await expect(page.locator("#cart-status")).toHaveText("Saved Mine.");
    await page.locator("#show-art").click();
    await page.getByRole("button", { name: "Color 3" }).click();
    await showTile(page, "Background", 5);
    const blankRow = await editRowColors(page, 0);
    await drag(page, [0, 0], [7, 0]);
    await expect.poll(() => editRowColors(page, 0)).not.toEqual(blankRow);
    const backgroundRow = await editRowColors(page, 0);
    await showTile(page, "Sprites", 2);
    await drag(page, [0, 0], [0, 0]);
    await expect.poll(async () => new Set(await editRowColors(page, 0)).size).toBe(2);
    const drawnColor = (await editRowColors(page, 0))[0];
    await page.getByRole("button", { name: "Code" }).click();
    await typeCode(page, "function _draw() cls() spr(2, 1, 0) end");
    const questions = [];
    page.on("dialog", (dialog) => {
      questions.push(dialog.message());
      dialog.accept();
    });

    await page.reload();
    await expect(page.locator("#cart-status")).toHaveText("Restored unsaved changes to Mine.");
    expect(questions).toEqual(["Restore unsaved changes to Mine?"]);
    await expect(page.locator(".cm-content")).toHaveText("function _draw() cls() spr(2, 1, 0) end");
    await page.locator("#show-art").click();
    await showTile(page, "Background", 5);
    expect(await editRowColors(page, 0)).toEqual(backgroundRow);
    await showTile(page, "Sprites", 2);
    expect((await editRowColors(page, 0))[0]).toBe(drawnColor);
    await page.getByRole("button", { name: "Run" }).click();
    await expect
      .poll(() => page.evaluate(() => document.getElementById("screen").getContext("2d").getImageData(1, 0, 1, 1).data.join()))
      .toBe(drawnColor);

    await page.getByRole("button", { name: "Code" }).click();
    await page.getByRole("button", { name: "Save", exact: true }).click();
    await expect(page.locator("#cart-status")).toHaveText("Saved Mine.");
    await page.reload();
    await expect(page.locator("#cart-list button")).not.toHaveCount(0);
    expect(questions).toHaveLength(1);
  });
});

test("a stroke writes the recovery copy only when it ends, and a cancel back to the saved art leaves no copy", async ({ page }) => {
  await openArtView(page);
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Demo.");
  await showTile(page, "Background", 2);
  const readCopy = () => page.evaluate(() => fesStorage.readRecoveryCopy());
  const blankRow = await editRowColors(page, 2);

  await pressMouseOnPixel(page, 0, 2);
  const end = await editPixelPoint(page, 7, 2);
  await page.mouse.move(end.x, end.y, { steps: 4 });
  await expect.poll(() => editRowColors(page, 2)).not.toEqual(blankRow);
  expect(await readCopy()).toBeNull();
  await cancelMouseStroke(page);
  await page.mouse.up();
  expect(await readCopy()).toBeNull();

  await drag(page, [0, 2], [7, 2]);
  expect(await readCopy()).not.toBeNull();
});

test("Run during a held stroke writes the recovery copy before the cart starts", async ({ page }) => {
  await openArtView(page);
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Demo.");
  await showTile(page, "Background", 2);
  const blankRow = await editRowColors(page, 2);
  await pressMouseOnPixel(page, 0, 2);
  await expect.poll(() => editRowColors(page, 2)).not.toEqual(blankRow);
  await page.evaluate(() => {
    window.viewsAtWrite = [];
    const setItem = Storage.prototype.setItem;
    Storage.prototype.setItem = function (key, value) {
      viewsAtWrite.push(document.body.dataset.view);
      setItem.call(this, key, value);
    };
  });

  await page.locator("#run").dispatchEvent("click");
  await page.mouse.up();

  expect(await page.evaluate(() => viewsAtWrite)).toEqual(["art"]);
});

test("a stroke cancelled after another cart loads leaves that cart's art alone", async ({ page }) => {
  await openArtView(page);
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Demo.");
  await showTile(page, "Background", 2);
  const savedTile = await editTileColors(page);
  await drag(page, [0, 0], [7, 0]);
  await pressMouseOnPixel(page, 7, 7);
  page.on("dialog", (dialog) => dialog.accept());

  await page.locator("#cart-list").getByRole("button", { name: "Demo", includeHidden: true }).dispatchEvent("click");
  await expect(page.locator("#cart-status")).toHaveText("Loaded Demo.");
  await cancelMouseStroke(page);
  await page.mouse.up();

  await nextFrame(page);
  expect(await editTileColors(page)).toEqual(savedTile);
});

ephemeralTest("the keyboard paints the pixel under the cursor, which is ringed only while the pixel controls have focus", async ({ page }) => {
  await openArtView(page);
  await showTile(page, "Background", 2);
  const blankTile = await editTileColors(page);
  await page.getByRole("button", { name: "Color 3" }).click();

  await page.locator("#art-pixel-column").focus();
  for (let i = 0; i < 3; i++) await page.keyboard.press("ArrowRight");
  await page.keyboard.press("Tab");
  for (let i = 0; i < 2; i++) await page.keyboard.press("ArrowRight");
  await page.keyboard.press("Tab");
  await expect(page.getByRole("button", { name: "Paint pixel" })).toBeFocused();
  await page.keyboard.press("Space");
  await page.getByRole("button", { name: "Color 5" }).click();
  await page.locator("#art-pixel-apply").focus();

  await expect(page.locator("#art-pixel-column")).toHaveAttribute("aria-valuetext", "3, color 3");
  await expect(page.locator("#art-pixel-row")).toHaveAttribute("aria-valuetext", "2, color 3");
  expect(await editAreaShowsSheetTile(page, 2)).toBe(true);
  expect(await editAreaRingsPixel(page, 3, 2)).toBe(true);

  await page.keyboard.press("Tab");
  await expect(page.locator("#art-pixel-apply")).not.toBeFocused();
  expect(await editAreaRingsPixel(page, 3, 2)).toBe(false);
  const painted = await editTileColors(page);
  expect(painted[2][3]).not.toBe(blankTile[2][3]);
  painted[2][3] = blankTile[2][3];
  expect(painted).toEqual(blankTile);
});

ephemeralTest("Pick color selects the color under the cursor and hands back to the pencil", async ({ page }) => {
  await openArtView(page);
  await showTile(page, "Background", 2);
  await page.locator("#art-pixel-column").fill("3");
  await page.locator("#art-pixel-row").fill("1");
  await page.getByRole("button", { name: "Color 5" }).click();
  await page.getByRole("button", { name: "Paint pixel" }).click();
  await page.getByRole("button", { name: "Color 2" }).click();
  await page.getByRole("button", { name: "Picker" }).click();

  await page.getByRole("button", { name: "Pick color" }).click();
  await expect(page.getByRole("button", { name: "Color 5" })).toHaveAttribute("aria-pressed", "true");
  await expect(page.getByRole("button", { name: "Pencil" })).toHaveAttribute("aria-pressed", "true");
  await expect(page.locator("#art-pixel-apply")).toHaveText("Paint pixel");
});

ephemeralTest("a touch tap at the edit area's corner paints only the pixel under it", async ({ page }) => {
  await openArtView(page);
  await showTile(page, "Background", 2);
  const blankTile = await editTileColors(page);
  await page.getByRole("button", { name: "Color 3" }).click();

  const box = await page.locator("#art-edit").boundingBox();
  await page.touchscreen.tap(box.x + box.width - 5, box.y + box.height - 5);
  await nextFrame(page);

  const painted = await editTileColors(page);
  expect(painted[7][7]).not.toBe(blankTile[7][7]);
  painted[7][7] = blankTile[7][7];
  expect(painted).toEqual(blankTile);
  await expect(page.getByRole("button", { name: "Color 3" })).toHaveAttribute("aria-pressed", "true");
  await expect(page.locator("#art-pixel-apply")).not.toBeFocused();
});

ephemeralTest("a keyboard paint ends a held stroke, so a later cancel takes back neither", async ({ page }) => {
  await openArtView(page);
  await showTile(page, "Background", 2);
  const blankTile = await editTileColors(page);
  await page.locator("#art-pixel-column").fill("6");

  await pressMouseOnPixel(page, 7, 7);
  await page.locator("#art-pixel-apply").focus();
  await page.keyboard.press("Space");
  await cancelMouseStroke(page);
  await page.mouse.up();
  await nextFrame(page);

  const painted = await editTileColors(page);
  expect(painted[0][6]).not.toBe(blankTile[0][6]);
  expect(painted[7][7]).not.toBe(blankTile[7][7]);
  painted[0][6] = blankTile[0][6];
  painted[7][7] = blankTile[7][7];
  expect(painted).toEqual(blankTile);
});

ephemeralTest("pressing the edit area hides the cursor ring, and Tab then starts again from the toolbar", async ({ page }) => {
  await openArtView(page);
  await showTile(page, "Background", 2);
  await page.locator("#art-pixel-apply").focus();
  expect(await editAreaRingsPixel(page, 0, 0)).toBe(true);

  await pressMouseOnPixel(page, 5, 5);
  await page.mouse.up();
  await nextFrame(page);

  expect(await editAreaRingsPixel(page, 0, 0)).toBe(false);
  await page.keyboard.press("Tab");
  await expect(page.locator("#run")).toBeFocused();
});

ephemeralTest("at 2 by 2 one drag across the tile border paints both tiles", async ({ page }) => {
  await openArtView(page);
  await showTile(page, "Background", 2);
  await page.getByRole("button", { name: "2 by 2" }).click();
  await expect(page.getByRole("button", { name: "2 by 2" })).toHaveAttribute("aria-pressed", "true");
  const [blank2, blank3, blank4] = await Promise.all([2, 3, 4].map((tile) => sheetTilePixels(page, tile)));

  await drag(page, [4, 3], [20, 3], 16);

  await expect.poll(() => sheetTilePixels(page, 3)).not.toBe(blank3);
  expect(await sheetTilePixels(page, 2)).not.toBe(blank2);
  expect(await sheetTilePixels(page, 4)).toBe(blank4);
});

ephemeralTest("changing the block size ends a held stroke, so later moves paint nothing", async ({ page }) => {
  await openArtView(page);
  await showTile(page, "Background", 2);
  await page.getByRole("button", { name: "2 by 2" }).click();
  const start = await editPixelPoint(page, 12, 12, 16);
  await page.mouse.move(start.x, start.y);
  await page.mouse.down();
  await nextFrame(page);
  const blockTiles = [2, 3, 18, 19];
  const afterPress = await Promise.all(blockTiles.map((tile) => sheetTilePixels(page, tile)));

  await page.getByRole("button", { name: "1 by 1" }).focus();
  await page.keyboard.press("Space");
  const end = await editPixelPoint(page, 1, 1);
  await page.mouse.move(end.x, end.y, { steps: 1 });
  await page.mouse.up();
  await nextFrame(page);

  expect(await Promise.all(blockTiles.map((tile) => sheetTilePixels(page, tile)))).toEqual(afterPress);
});

ephemeralTest("at 4 by 4 the pixel sliders reach 31, and 1 by 1 brings the cursor back inside the tile", async ({ page }) => {
  await openArtView(page);
  await page.getByRole("button", { name: "4 by 4" }).click();
  await page.locator("#art-tile").fill("255");
  await expect(page.locator("#art-tile")).toHaveAttribute("aria-valuetext", "255, column 15, row 15, block from tile 204");

  await page.locator("#art-pixel-column").fill("31");
  await expect(page.locator("#art-pixel-column")).toHaveAttribute("aria-valuetext", /^31, /);

  await page.getByRole("button", { name: "1 by 1" }).click();
  await expect(page.locator("#art-pixel-column")).toHaveValue("7");
  await expect(page.locator("#art-pixel-column")).toHaveAttribute("aria-valuetext", /^7, /);
  await expect(page.locator("#art-tile")).toHaveAttribute("aria-valuetext", "255, column 15, row 15");
});

ephemeralTest("a pointer fill fills the block's region across tile borders, and a cancel takes it back", async ({ page }) => {
  await openArtView(page);
  await showTile(page, "Background", 2);
  await page.getByRole("button", { name: "2 by 2" }).click();
  await page.getByRole("button", { name: "Fill", exact: true }).click();
  const blockTiles = [2, 3, 18, 19];
  const blank = await Promise.all(blockTiles.map((tile) => sheetTilePixels(page, tile)));
  const outside = await sheetTilePixels(page, 4);

  const start = await editPixelPoint(page, 1, 1, 16);
  await page.mouse.move(start.x, start.y);
  await page.mouse.down();
  for (const [i, tile] of blockTiles.entries()) {
    await expect.poll(() => sheetTilePixels(page, tile)).not.toBe(blank[i]);
  }
  expect(await sheetTilePixels(page, 4)).toBe(outside);
  await cancelMouseStroke(page);
  await page.mouse.up();

  await expect.poll(() => Promise.all(blockTiles.map((tile) => sheetTilePixels(page, tile)))).toEqual(blank);
  await expect(page.getByRole("button", { name: "Fill", exact: true })).toHaveAttribute("aria-pressed", "true");
});

ephemeralTest("Fill region fills the region under the keyboard cursor", async ({ page }) => {
  await openArtView(page);
  await showTile(page, "Background", 2);
  const blankTile = await editTileColors(page);
  await page.getByRole("button", { name: "Color 3" }).click();
  await page.getByRole("button", { name: "Fill", exact: true }).click();

  await page.locator("#art-pixel-apply").focus();
  await expect(page.locator("#art-pixel-apply")).toHaveText("Fill region");
  await page.keyboard.press("Space");

  const filled = await editTileColors(page);
  expect(new Set(filled.flat()).size).toBe(1);
  expect(filled[0][0]).not.toBe(blankTile[0][0]);
  await expect(page.getByRole("button", { name: "Fill", exact: true })).toHaveAttribute("aria-pressed", "true");
});

ephemeralTest("Flip H and Flip V move a block's tiles along with their pixels", async ({ page }) => {
  await openArtView(page);
  await showTile(page, "Background", 2);
  await page.getByRole("button", { name: "2 by 2" }).click();
  const blank = await sheetTilePixels(page, 2);
  await drag(page, [0, 0], [0, 0], 16);
  await expect.poll(() => sheetTilePixels(page, 2)).not.toBe(blank);

  await page.getByRole("button", { name: "Flip horizontally" }).click();
  expect(await sheetTilePixels(page, 2)).toBe(blank);
  expect(await sheetTilePixels(page, 3)).not.toBe(blank);

  await page.getByRole("button", { name: "Flip vertically" }).click();
  expect(await sheetTilePixels(page, 3)).toBe(blank);
  expect(await sheetTilePixels(page, 19)).not.toBe(blank);
});

test("a flip on a saved cart writes the recovery copy", async ({ page }) => {
  await openArtView(page);
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Demo.");
  await showTile(page, "Sprites", 0);
  const unflipped = await sheetTilePixels(page, 0);

  await page.getByRole("button", { name: "Flip horizontally" }).click();

  expect(await sheetTilePixels(page, 0)).not.toBe(unflipped);
  expect(await page.evaluate(() => fesStorage.readRecoveryCopy())).not.toBeNull();
});

test("a copied block pastes into another cart, at the sheet's edge", async ({ page }) => {
  await openArtView(page);
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Demo.");
  await expect(page.getByRole("button", { name: "Paste" })).toBeDisabled();
  await showTile(page, "Background", 1);
  const copied = await sheetTilePixels(page, 1);
  await page.getByRole("button", { name: "Copy" }).click();
  page.on("dialog", (dialog) => dialog.accept());

  await page.locator("#cart-list").getByRole("button", { name: "Demo", includeHidden: true }).dispatchEvent("click");
  await expect(page.locator("#cart-status")).toHaveText("Loaded Demo.");
  await showTile(page, "Background", 255);
  expect(await sheetTilePixels(page, 255)).not.toBe(copied);
  await page.getByRole("button", { name: "Paste" }).click();

  expect(await sheetTilePixels(page, 255)).toBe(copied);
});
