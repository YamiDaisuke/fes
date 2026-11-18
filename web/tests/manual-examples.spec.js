import { test, expect } from "./persistent-context.js";
import { openPaused, runFrames } from "./frames.js";
import { loadCodeFiles } from "./code-editor.js";

test("every example cart in the manual runs 60 frames holding →, ↓ and A, then 60 holding ← and ↑, without an error", async ({ page, context }) => {
  await page.goto("/manual/");
  const pres = await page.evaluate(() =>
    [...document.querySelectorAll("pre[data-example]")].map((pre) => ({ name: pre.dataset.example, file: pre.dataset.file ?? "main.lua", text: pre.textContent })),
  );
  const examples = {};
  for (const { name, file, text } of pres) {
    examples[name] ??= {};
    examples[name][file] = text;
  }
  expect(Object.keys(examples).length).toBeGreaterThan(0);

  for (const [name, files] of Object.entries(examples)) {
    await test.step(name, async () => {
      const cartPage = await context.newPage();
      if (Object.keys(files).length === 1) {
        await cartPage.addInitScript((mainLua) => { window.testCartMainLua = mainLua; }, files["main.lua"]);
        await openPaused(cartPage);
      } else {
        await openPaused(cartPage);
        await cartPage.getByRole("button", { name: "Code", exact: true }).click();
        await loadCodeFiles(cartPage, files, name);
        await cartPage.getByRole("button", { name: "Run", exact: true }).click();
      }
      await cartPage.keyboard.down("ArrowRight");
      await cartPage.keyboard.down("ArrowDown");
      await cartPage.keyboard.down("KeyZ");
      await runFrames(cartPage, 60);
      await cartPage.keyboard.up("ArrowRight");
      await cartPage.keyboard.up("ArrowDown");
      await cartPage.keyboard.up("KeyZ");
      await cartPage.keyboard.down("ArrowLeft");
      await cartPage.keyboard.down("ArrowUp");
      await runFrames(cartPage, 60);
      await expect(cartPage.locator("#cart-error")).toHaveText("");
      await cartPage.close();
    });
  }
});
