import { test, expect } from "./persistent-context.js";
import { openShelf } from "./shelf.js";

const SIZES = [
  { width: 1194, height: 834 },
  { width: 1133, height: 744 },
  { width: 834, height: 1194 },
  { width: 744, height: 1133 },
];

async function waitTwoAnimationFrames(page) {
  await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

for (const size of SIZES) {
  test(`at ${size.width}×${size.height} with the install hint and an empty shelf, every action key is in view and only the slot scrolls`, async ({ page }) => {
    await page.setViewportSize(size);
    await page.goto("/");
    await page.evaluate(async () => {
      await document.fonts.ready;
    });
    await openShelf(page);
    await expect(page.locator("#install-hint")).toBeVisible();
    await expect(page.locator("#shelf-empty")).toBeVisible();

    const keysOutOfView = await page.locator("#shelf-actions .key").evaluateAll((keys) =>
      keys
        .map((key) => ({ id: key.id, ...key.getBoundingClientRect().toJSON() }))
        .filter(({ left, top, right, bottom, width, height }) => width < 44 || height < 44 || left < 0 || top < 0 || right > innerWidth || bottom > innerHeight),
    );
    expect(keysOutOfView).toEqual([]);

    const scrolling = await page.evaluate(() => ({
      page: [document.documentElement.scrollWidth, document.documentElement.scrollHeight],
      view: document.getElementById("shelf-view").scrollHeight > document.getElementById("shelf-view").clientHeight,
      slot: document.getElementById("shelf-list").scrollHeight > document.getElementById("shelf-list").clientHeight,
    }));
    expect(scrolling).toEqual({ page: [size.width, size.height], view: false, slot: false });

    const canvasBoxes = await page.evaluate(() =>
      [document.querySelector('#shelf-list [data-folder=""] canvas'), document.getElementById("shelf-preview-label")].map((canvas) => {
        const { left, top, width, height } = canvas.getBoundingClientRect();
        return { width, height, onWholePixels: Number.isInteger(left) && Number.isInteger(top) };
      }),
    );
    expect(canvasBoxes).toEqual([
      { width: 96, height: 72, onWholePixels: true },
      { width: 384, height: 288, onWholePixels: true },
    ]);
  });
}

test("Right to the last of twelve carts scrolls the slot so the selected cartridge is fully in view", async ({ page }) => {
  await page.setViewportSize({ width: 744, height: 1133 });
  await page.goto("/");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  await page.evaluate(async () => {
    for (let number = 1; number <= 12; number++) {
      const name = `Cart ${String(number).padStart(2, "0")}`;
      await fesStorage.writeCartFile(`${number.toString(16)}0`, "cart.json", JSON.stringify({ format: 3, name }));
    }
  });
  await page.reload();

  await openShelf(page);
  const entries = page.locator("#shelf-list [data-folder]");
  await expect(entries).toHaveCount(13);
  for (let index = 1; index <= 12; index++) {
    await page.keyboard.press("ArrowRight");
    await expect(entries.nth(index)).toHaveAttribute("aria-pressed", "true");
    await waitTwoAnimationFrames(page);
  }

  const view = await page.evaluate(() => {
    const slot = document.getElementById("shelf-list");
    const slotBox = slot.getBoundingClientRect();
    const last = slot.querySelector("li:last-child button").getBoundingClientRect();
    return {
      lastInsideSlot: last.left >= slotBox.left && last.right <= slotBox.right && last.top >= slotBox.top && last.bottom <= slotBox.bottom,
      slotScrolled: slot.scrollLeft > 0,
      pageScroll: [scrollX, scrollY],
    };
  });
  expect(view).toEqual({ lastInsideSlot: true, slotScrolled: true, pageScroll: [0, 0] });
});
