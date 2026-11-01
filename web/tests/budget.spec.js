import { test, expect } from "@playwright/test";
import { openPaused, runFrames } from "./frames.js";

const runawayCarts = [
  ["an infinite loop in _update", "function _update() while true do end end", "main.lua:1: CPU budget exceeded\nstack traceback:"],
  ["a __call cycle", "function _update() local t = {} setmetatable(t, {__call = t}) t() end", "main.lua:1: stack overflow"],
  ["a 2 GB string.rep", `function _update() s = string.rep("x", 2e9) end`, "memory budget exceeded"],
];

for (const [name, mainLua, message] of runawayCarts) {
  test(`${name} stops the cart with its budget error and the loop keeps running`, async ({ page }) => {
    await page.addInitScript((mainLua) => { window.testCartMainLua = mainLua; }, mainLua);
    await openPaused(page);

    await runFrames(page, 1);
    await expect(page.locator("#cart-error")).toContainText(message);
    await runFrames(page, 2);
  });
}
