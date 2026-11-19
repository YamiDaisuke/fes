import { readFileSync } from "node:fs";
import { test, expect } from "./persistent-context.js";
import { openPaused, runFrames } from "./frames.js";
import { loadCodeFiles } from "./code-editor.js";

const manual = readFileSync(new URL("../manual/index.html", import.meta.url), "utf8");
const exampleNames = [...new Set([...manual.matchAll(/data-example="([^"]+)"/g)].map((match) => match[1]))];

test("the manual has example carts to run", () => {
  expect(exampleNames.length).toBeGreaterThan(0);
});

for (const name of exampleNames) {
  test(`the manual's ${name} example runs 60 frames holding →, ↓ and A, then 60 holding ← and ↑, without an error`, async ({ page }) => {
    await page.goto("/manual/");
    const files = await page.evaluate((name) => Object.fromEntries(
      [...document.querySelectorAll(`pre[data-example="${name}"]`)].map((pre) => [pre.dataset.file ?? "main.lua", pre.textContent]),
    ), name);
    expect(Object.keys(files).length).toBeGreaterThan(0);

    if (Object.keys(files).length === 1) {
      await page.addInitScript((mainLua) => { window.testCartMainLua = mainLua; }, files["main.lua"]);
      await openPaused(page);
    } else {
      await openPaused(page);
      await page.getByRole("button", { name: "Code", exact: true }).click();
      await loadCodeFiles(page, files, name);
      await page.getByRole("button", { name: "Run", exact: true }).click();
    }
    await page.keyboard.down("ArrowRight");
    await page.keyboard.down("ArrowDown");
    await page.keyboard.down("KeyZ");
    await runFrames(page, 60);
    await page.keyboard.up("ArrowRight");
    await page.keyboard.up("ArrowDown");
    await page.keyboard.up("KeyZ");
    await page.keyboard.down("ArrowLeft");
    await page.keyboard.down("ArrowUp");
    await runFrames(page, 60);
    await expect(page.locator("#cart-error")).toHaveText("");
  });
}
