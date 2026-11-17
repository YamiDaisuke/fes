import { test, expect } from "@playwright/test";
import { pixelColors, rgb, tokenColor } from "./pixels.js";
import { contrastRatio } from "./contrast.js";

test.beforeEach(async ({ page }) => {
  await page.setViewportSize({ width: 1194, height: 834 });
  await page.addInitScript(() => localStorage.setItem("fes-install-hint-dismissed", String(Date.now())));
  await page.goto("/");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  await page.locator("#show-art").click();
  await page.evaluate(() => document.fonts.ready);
});

function canvasPixel(page, canvasId, x, y) {
  return page.evaluate(
    ([canvasId, x, y]) => [...document.getElementById(canvasId).getContext("2d").getImageData(x, y, 1, 1).data.slice(0, 3)].join(),
    [canvasId, x, y],
  );
}

test("the sheet and edit area draw grid, tile border, selection ring and checker in the look's token colours", async ({ page }) => {
  await page.getByRole("button", { name: "Sprites" }).click();
  await page.getByRole("button", { name: "2 by 2" }).click();
  await page.locator("#art-tile").fill("2");
  await expect(page.locator("#art-tile-number")).toHaveText("2");
  const sheetZoom = await page.evaluate(() => (document.getElementById("art-sheet").width - 17) / 128);
  const sheetOrigin = (square) => 1 + square * (8 * sheetZoom + 1);
  const editZoom = await page.evaluate(() => (document.getElementById("art-edit").width - 17) / 16);
  const editOrigin = (square) => 1 + square * (editZoom + 1);
  const middleOfFirstRow = sheetOrigin(0) + 4 * sheetZoom;
  const blankTileLeft = sheetOrigin(6);

  const drawn = {
    gridLine: await canvasPixel(page, "art-sheet", blankTileLeft - 1, middleOfFirstRow),
    ringOutside: await canvasPixel(page, "art-sheet", sheetOrigin(2) - 1, middleOfFirstRow),
    ringInside: await canvasPixel(page, "art-sheet", sheetOrigin(2), middleOfFirstRow),
    tileBorder: await canvasPixel(page, "art-edit", editOrigin(8) - 1, editOrigin(3)),
    checkerLight: await canvasPixel(page, "art-sheet", blankTileLeft, sheetOrigin(0)),
    checkerDark: await canvasPixel(page, "art-sheet", blankTileLeft + sheetZoom - 1, sheetOrigin(0)),
  };

  expect(drawn).toEqual({
    gridLine: await tokenColor(page, "--shell-deep"),
    ringOutside: await tokenColor(page, "--ink"),
    ringInside: await tokenColor(page, "--butter"),
    tileBorder: await tokenColor(page, "--ink"),
    checkerLight: await tokenColor(page, "--shell-light"),
    checkerDark: await tokenColor(page, "--shell-dark"),
  });
});

test("art pixels reach the screen in their exact colours", async ({ page }) => {
  const { canvasColor, clip } = await page.evaluate(() => {
    const edit = document.getElementById("art-edit");
    const zoom = (edit.width - 9) / 8;
    const center = 1 + (zoom + 1) + Math.floor(zoom / 2);
    const color = [...edit.getContext("2d").getImageData(center, center, 1, 1).data.slice(0, 3)].join();
    const box = edit.getBoundingClientRect();
    const cssPerCanvasPixel = box.width / edit.width;
    return {
      canvasColor: color,
      clip: { x: box.x + center * cssPerCanvasPixel - 2, y: box.y + center * cssPerCanvasPixel - 2, width: 4, height: 4 },
    };
  });

  const onScreen = await page.screenshot({ clip });

  expect(new Set(await pixelColors(page, onScreen))).toEqual(new Set([canvasColor]));
});

function textContrasts(page) {
  return page.locator("#art-view").evaluate((view) => {
    const hasOwnText = (element) => [...element.childNodes].some((node) => node.nodeType === Node.TEXT_NODE && node.textContent.trim() !== "");
    const backgroundOf = (element) => {
      for (let current = element; current; current = current.parentElement) {
        const background = getComputedStyle(current).backgroundColor;
        if (background !== "rgba(0, 0, 0, 0)" && background !== "transparent") return background;
      }
      return getComputedStyle(document.body).backgroundColor;
    };
    return [...view.querySelectorAll("*")]
      .filter((element) => element.checkVisibility() && hasOwnText(element))
      .map((element) => ({ text: element.textContent.trim(), color: getComputedStyle(element).color, background: backgroundOf(element) }));
  });
}

for (const palettes of ["closed", "open"]) {
  test(`every text in the Art view is at least 7:1 on what's behind it, with Palettes ${palettes}`, async ({ page }) => {
    if (palettes === "open") {
      await page.getByRole("button", { name: "Palettes", exact: true }).click();
      await expect(page.locator("#art-palettes")).toBeVisible();
    }

    const texts = await textContrasts(page);

    expect(texts.length).toBeGreaterThan(5);
    for (const { text, color, background } of texts) {
      expect(contrastRatio(rgb(color), rgb(background)), `${text}: ${color} on ${background}`).toBeGreaterThanOrEqual(7);
    }
  });
}

const iconKeyNames = [
  "Pencil", "Picker", "Fill", "Flip horizontally", "Flip vertically", "Copy", "Paste",
  "Undo", "Redo", "Import sheet", "Import sheet and colors", "Palettes",
];

test("each icon key has its old name, no visible text and no description", async ({ page }) => {
  const keys = page.locator("#art-view .icon-key");
  await expect(keys).toHaveCount(iconKeyNames.length);

  for (const [index, name] of iconKeyNames.entries()) {
    const key = keys.nth(index);
    await expect(key).toHaveAccessibleName(name);
    await expect(key).toHaveText("");
    await expect(key).toHaveAccessibleDescription("");
  }

  await page.getByRole("button", { name: "Flip horizontally" }).click();
  await expect(page.locator("#art-undo")).not.toHaveAccessibleName("Undo");
});

test("every icon key draws its icon in only ink and its face colour at 2×", async ({ page }) => {
  const ink = await tokenColor(page, "--ink");
  const keys = await page.locator("#art-view .icon-key").all();
  expect(keys).toHaveLength(iconKeyNames.length);

  for (const key of keys) {
    const name = await key.getAttribute("aria-label");
    const face = rgb(await key.evaluate((element) => getComputedStyle(element).backgroundColor)).join();
    const box = await key.boundingBox();
    expect(box.height, `${name} is square`).toBe(box.width);
    const inset = 8;
    const iconArea = await page.screenshot({ clip: { x: box.x + inset, y: box.y + inset, width: box.width - 2 * inset, height: box.height - 2 * inset } });

    const colors = new Set(await pixelColors(page, iconArea));

    expect(colors.has(ink), `${name} shows ink`).toBe(true);
    expect([...colors].filter((color) => color !== ink && color !== face), `${name} shows only ink and ${face}`).toEqual([]);
  }
});
