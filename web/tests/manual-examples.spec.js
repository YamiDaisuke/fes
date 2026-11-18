import { test, expect } from "@playwright/test";
import { openPaused, runFrames } from "./frames.js";

test("every example cart in the manual runs 120 frames without an error", async ({ page, context }) => {
  await page.goto("/manual/");
  const examples = await page.evaluate(() =>
    [...document.querySelectorAll("pre[data-example]")].map((pre) => ({ name: pre.dataset.example, mainLua: pre.textContent })),
  );
  expect(examples.length).toBeGreaterThan(0);

  for (const { name, mainLua } of examples) {
    await test.step(name, async () => {
      const cartPage = await context.newPage();
      await cartPage.addInitScript((mainLua) => { window.testCartMainLua = mainLua; }, mainLua);
      await openPaused(cartPage);
      await runFrames(cartPage, 120);
      await expect(cartPage.locator("#cart-error")).toHaveText("");
      await cartPage.close();
    });
  }
});
