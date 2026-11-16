import { test, expect } from "@playwright/test";
import { openPaused, runFrames } from "./frames.js";

test("a cart's runtime error appears with its line on frame 120", async ({ page }) => {
  await page.addInitScript(() => {
    window.testCartMainLua = `function _init()
  frames = 0
end

function _update()
  frames = frames + 1
  if frames == 120 then
    frames = frames + speed
  end
end`;
  });
  await openPaused(page);
  const cartError = page.locator("#cart-error");

  await runFrames(page, 119);
  await expect(cartError).toBeEmpty();
  await expect(cartError).toBeHidden();

  await runFrames(page, 1);
  await expect(cartError).toBeVisible();
  await expect(cartError).toContainText(
    "main.lua:8: attempt to perform arithmetic on a nil value (global 'speed')\nstack traceback:",
  );
});

test("a long error wraps and scrolls inside a plate that stays on the screen", async ({ page }) => {
  await page.addInitScript(() => {
    window.testCartMainLua = `error(string.rep("A", 3000) .. string.rep("\\nline", 200), 0)`;
  });
  await openPaused(page);
  await runFrames(page, 1);

  const bar = await page.locator("#cart-error").evaluate((bar) => ({
    scrollWidth: bar.scrollWidth,
    clientWidth: bar.clientWidth,
    scrollHeight: bar.scrollHeight,
    clientHeight: bar.clientHeight,
    bottom: bar.getBoundingClientRect().bottom,
  }));
  const screenBottom = await page.locator("#screen").evaluate((screen) => screen.getBoundingClientRect().bottom);
  expect(bar.scrollWidth).toBe(bar.clientWidth);
  expect(bar.scrollHeight).toBeGreaterThan(bar.clientHeight);
  expect(bar.bottom).toBeLessThan(screenBottom);
});
