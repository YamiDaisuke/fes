import { test, expect } from "@playwright/test";
import { pixelColors, rgb } from "./pixels.js";

const SIZES = [
  { width: 1194, height: 834 },
  { width: 1133, height: 744 },
  { width: 834, height: 1194 },
  { width: 744, height: 1133 },
];

async function openArtView(page, { width, height }) {
  await page.setViewportSize({ width, height });
  await page.addInitScript(() => localStorage.setItem("fes-install-hint-dismissed", String(Date.now())));
  await page.goto("/");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  await page.locator("#show-art").click();
}

function overflowingPanels(page, ids) {
  return page.evaluate((ids) => {
    const scrolls = (element) => element.scrollHeight > element.clientHeight || element.scrollWidth > element.clientWidth;
    const panels = ids.map((id) => [id, document.getElementById(id)]);
    panels.push(["page", document.scrollingElement]);
    return panels.filter(([, element]) => scrolls(element)).map(([id]) => id);
  }, ids);
}

function badControls(page, selector) {
  return page.evaluate((selector) => {
    const controls = [...document.querySelectorAll(selector)].filter((control) => control.offsetParent !== null);
    return controls
      .map((control) => ({ name: control.id || control.getAttribute("aria-label") || control.textContent.trim(), ...control.getBoundingClientRect().toJSON() }))
      .filter(({ x, y, width, height }) => width < 44 || height < 44 || !Number.isInteger(x) || !Number.isInteger(y));
  }, selector);
}

function canvasOutsideItsArea(page) {
  return page.evaluate(() => [["art-sheet", "art-sheet-area"], ["art-edit", "art-edit-area"]].filter(([canvasId, areaId]) => {
    const canvas = document.getElementById(canvasId).getBoundingClientRect();
    const area = document.getElementById(areaId).getBoundingClientRect();
    return canvas.left < area.left || canvas.top < area.top || canvas.right > area.right || canvas.bottom > area.bottom;
  }).map(([canvasId]) => canvasId));
}

for (const size of SIZES) {
  test(`at ${size.width}×${size.height} the Art view, its tools and its selection fit without scrolling, with every control at least 44 px on whole pixels`, async ({ page }) => {
    await openArtView(page, size);
    await expect.poll(() => page.evaluate(() => document.getElementById("art-sheet").width)).toBe(401);

    expect(await overflowingPanels(page, ["art-view", "art-tools", "art-selection"])).toEqual([]);
    expect(await badControls(page, "#art-view button, #art-view input[type=range]")).toEqual([]);
    expect(await canvasOutsideItsArea(page)).toEqual([]);
  });

  test(`at ${size.width}×${size.height} the palette editor fits, with 44 px swatches`, async ({ page }) => {
    await openArtView(page, size);
    await page.getByRole("button", { name: "Palettes", exact: true }).click();
    await expect(page.locator("#art-palettes")).toBeVisible();

    expect(await overflowingPanels(page, ["art-view", "art-palettes", "art-tools", "art-selection"])).toEqual([]);
    expect(await badControls(page, "#art-palettes button")).toEqual([]);
  });
}

test("in a 320 px wide window the whole tile sheet stays on screen, inside its own column", async ({ page }) => {
  await openArtView(page, { width: 320, height: 1000 });
  await expect.poll(() => page.evaluate(() => Number.isInteger((document.getElementById("art-sheet").width - 17) / 128))).toBe(true);

  const sheetRight = await page.evaluate(() => document.getElementById("art-sheet").getBoundingClientRect().right);
  expect(sheetRight).toBeLessThanOrEqual(320);
  expect(await canvasOutsideItsArea(page)).toEqual([]);
});

test("Undo with nothing to undo keeps its ink focus ring on the shell", async ({ page }) => {
  await openArtView(page, SIZES[0]);
  await page.locator("#art-copy").focus();
  await page.keyboard.press("Tab");
  const undo = page.getByRole("button", { name: "Undo", exact: true });
  await expect(undo).toBeFocused();
  await expect(undo).toHaveAttribute("aria-disabled", "true");
  const ink = rgb(await page.evaluate(() => getComputedStyle(document.getElementById("art-view")).color)).join();

  const box = await undo.boundingBox();
  const outsideTheButterOutline = await page.screenshot({ clip: { x: box.x - 4, y: box.y, width: 2, height: box.height } });

  expect(new Set(await pixelColors(page, outsideTheButterOutline))).toEqual(new Set([ink]));
});

test("in a 700×500 window the open palette editor leaves the tools plate uncovered", async ({ page }) => {
  await openArtView(page, { width: 700, height: 500 });
  await page.getByRole("button", { name: "Palettes", exact: true }).click();
  await expect(page.locator("#art-palettes")).toBeVisible();
  const undo = page.getByRole("button", { name: "Undo", exact: true });
  await undo.scrollIntoViewIfNeeded();
  const box = await undo.boundingBox();

  const isUndoOnTop = await page.evaluate(
    ({ x, y }) => document.elementFromPoint(x, y)?.id === "art-undo",
    { x: box.x + box.width / 2, y: box.y + box.height / 2 },
  );

  expect(isUndoOnTop).toBe(true);
});
