import { test, expect } from "@playwright/test";
import { openPaused, runFrames } from "./frames.js";

test("every example cart in the manual runs 60 frames holding → and A, then 60 holding ←, without an error", async ({ page, context }) => {
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
      await cartPage.keyboard.down("ArrowRight");
      await cartPage.keyboard.down("KeyZ");
      await runFrames(cartPage, 60);
      await cartPage.keyboard.up("ArrowRight");
      await cartPage.keyboard.up("KeyZ");
      await cartPage.keyboard.down("ArrowLeft");
      await runFrames(cartPage, 60);
      await expect(cartPage.locator("#cart-error")).toHaveText("");
      await cartPage.close();
    });
  }
});
