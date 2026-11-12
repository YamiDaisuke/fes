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

async function editPixelPoint(page, x, y) {
  const box = await page.locator("#art-edit").boundingBox();
  const zoom = await page.evaluate(() => (document.getElementById("art-edit").width - 9) / 8);
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

async function drag(page, from, to) {
  const start = await editPixelPoint(page, ...from);
  const end = await editPixelPoint(page, ...to);
  await page.mouse.move(start.x, start.y);
  await page.mouse.down();
  await page.mouse.move(end.x, end.y, { steps: 1 });
  await page.mouse.up();
}

async function showBlankTile(page, bank) {
  await page.getByRole("button", { name: bank }).click();
  await page.locator("#art-tile").fill("2");
  await expect(page.locator("#art-tile-number")).toHaveText("2");
}

ephemeralTest("one fast drag paints every pixel between its ends and nothing around them", async ({ page }) => {
  await openArtView(page);
  await showBlankTile(page, "Background");
  const blankRow = await editRowColors(page, 3);

  await drag(page, [0, 2], [7, 2]);
  await expect.poll(async () => (await editRowColors(page, 2))[0]).not.toBe(blankRow[0]);
  expect(new Set(await editRowColors(page, 2)).size).toBe(1);
  expect(await editRowColors(page, 3)).toEqual(blankRow);
  expect(await editAreaShowsSheetTile(page, 2)).toBe(true);
});

ephemeralTest("the picker selects the color under the pointer and hands back to the pencil", async ({ page }) => {
  await openArtView(page);
  await showBlankTile(page, "Background");
  await page.getByRole("button", { name: "Picker" }).click();
  await expect(page.getByRole("button", { name: "Color 1" })).toHaveAttribute("aria-pressed", "true");

  await drag(page, [3, 3], [3, 3]);
  await expect(page.getByRole("button", { name: "Color 0" })).toHaveAttribute("aria-pressed", "true");
  await expect(page.getByRole("button", { name: "Color 1" })).toHaveAttribute("aria-pressed", "false");
  await expect(page.getByRole("button", { name: "Pencil" })).toHaveAttribute("aria-pressed", "true");
});

test.describe("with a cart that draws sprite tile 2", () => {
  test.beforeEach(async ({ page }) => {
    await page.addInitScript(() => {
      window.testCartMainLua = "function _draw() cls() spr(2, 0, 0) end";
    });
  });

  test("a drawn sprite shows in Run, and is still there after Save and a reload", async ({ page }) => {
    await openArtView(page);
    await showBlankTile(page, "Sprites");
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
    await showBlankTile(page, "Sprites");
    expect((await editRowColors(page, 0))[0]).toBe(drawnColor);
  });

  test("drawing makes loading another cart ask to discard, and doesn't offer a code-only restore", async ({ page }) => {
    await openArtView(page);
    await page.getByRole("button", { name: "Save", exact: true }).click();
    await expect(page.locator("#cart-status")).toHaveText("Saved Demo.");
    await drag(page, [0, 0], [7, 7]);
    const questions = [];
    page.on("dialog", (dialog) => {
      questions.push(dialog.message());
      dialog.dismiss();
    });

    await page.locator("#cart-list").getByRole("button", { name: "Demo", includeHidden: true }).dispatchEvent("click");
    await expect.poll(() => questions).toEqual(["Discard unsaved changes to Demo?"]);

    await page.getByRole("button", { name: "Code" }).click();
    await typeCode(page, "-- edited");
    await typeCode(page, "function _draw() cls() spr(2, 0, 0) end");
    await page.reload();
    await expect(page.locator("#cart-list button")).not.toHaveCount(0);
    expect(questions).toEqual(["Discard unsaved changes to Demo?"]);
  });
});
