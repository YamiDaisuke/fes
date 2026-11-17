import { test, expect } from "@playwright/test";
import { openPaused } from "./frames.js";

const VIEWPORTS = [
  { width: 1194, height: 834, scale: 4, installHint: false },
  { width: 1133, height: 744, scale: 4, installHint: false },
  { width: 1133, height: 744, scale: 3, installHint: true },
  { width: 834, height: 1194, scale: 4, installHint: false },
  { width: 744, height: 1133, scale: 3, installHint: false },
];

function intersects(a, b) {
  return a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height;
}

function contains(outer, inner) {
  return inner.x >= outer.x && inner.y >= outer.y && inner.x + inner.width <= outer.x + outer.width && inner.y + inner.height <= outer.y + outer.height;
}

for (const { width, height, scale, installHint } of VIEWPORTS) {
  test(`at ${width}×${height}${installHint ? " with the install hint" : ""} the screen keeps a whole ${scale}× scale on whole pixels, the CRT overlay covers exactly the screen, and the controller stays off both`, async ({ page }) => {
    await page.setViewportSize({ width, height });
    await page.addInitScript((installHint) => {
      if (!installHint) localStorage.setItem("fes-install-hint-dismissed", String(Date.now()));
      localStorage.setItem("fes-crt", "on");
      window.testCartMainLua = "function _draw() cls() end";
    }, installHint);
    await openPaused(page);
    await expect(page.locator("#install-hint")).toBeVisible({ visible: installHint });
    await expect(page.locator("#screen")).toHaveCSS("width", `${192 * scale}px`);

    const boxes = await page.evaluate(() => {
      const box = (element) => {
        const { x, y, width, height } = element.getBoundingClientRect();
        return { x, y, width, height };
      };
      return {
        bezel: box(document.getElementById("bezel")),
        screen: box(document.getElementById("screen")),
        crtOverlay: box(document.getElementById("screen-crt")),
        crtKey: box(document.getElementById("crt-toggle")),
        badge: box(document.getElementById("badge")),
        keys: [...document.querySelectorAll("#pad button[data-buttons]")].map((key) => ({ name: key.dataset.buttons, ...box(key) })),
        scrolls: document.scrollingElement.scrollHeight > innerHeight || document.scrollingElement.scrollWidth > innerWidth,
      };
    });

    expect(contains(boxes.bezel, boxes.screen)).toBe(true);
    expect(boxes.crtOverlay).toEqual(boxes.screen);
    expect(boxes.scrolls).toBe(false);
    expect(Math.min(boxes.crtKey.width, boxes.crtKey.height), "CRT key hit area").toBeGreaterThanOrEqual(44);
    for (const key of boxes.keys) {
      expect(intersects(key, boxes.bezel), `${key.name} overlaps the bezel`).toBe(false);
      expect(intersects(key, boxes.crtKey), `${key.name} overlaps the CRT key`).toBe(false);
      expect(Math.min(key.width, key.height), `${key.name} hit area`).toBeGreaterThanOrEqual(44);
    }
    for (const [name, box] of [["bezel", boxes.bezel], ["screen", boxes.screen], ["badge", boxes.badge], ["CRT key", boxes.crtKey], ...boxes.keys.map((key) => [key.name, key])]) {
      expect([box.x, box.y, box.width, box.height].every(Number.isInteger), `${name} sits on whole pixels: ${JSON.stringify(box)}`).toBe(true);
    }
  });
}
