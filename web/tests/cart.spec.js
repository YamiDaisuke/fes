import { test, expect } from "@playwright/test";
import { openPaused, runFrames } from "./frames.js";

test("the test cart's runtime error appears with its line on frame 120", async ({ page }) => {
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
