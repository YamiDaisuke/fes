import { readFileSync, readdirSync } from "node:fs";
import { test, expect } from "@playwright/test";

const appSources = new URL("../../Sources/App/", import.meta.url);
const askAnswers = new Set(readdirSync(appSources).flatMap((file) =>
  [...readFileSync(new URL(file, appSources), "utf8").matchAll(/(?:confirm|cancel):[^"\n]*"([^"]+)"/g)].map((match) => match[1]),
));

async function openShelf(page) {
  await page.goto("/");
  await expect(page.locator("#shelf-list").getByRole("button", { name: "Built-in demo" })).toBeVisible();
}

test("every key the manual names exists in the app under that name", async ({ page }) => {
  await page.goto("/manual/");
  const names = await page.evaluate(() =>
    [...new Set([...document.querySelectorAll("kbd[data-control]")].map((kbd) => kbd.dataset.control || kbd.textContent))],
  );
  expect(names.length).toBeGreaterThan(0);

  await openShelf(page);
  const missing = [];
  for (const name of names) {
    if (await page.getByRole("button", { name, exact: true, includeHidden: true }).count() === 0) missing.push(name);
  }

  expect(missing).toEqual([]);
});

test("every ask answer the manual names is an answer the app asks with", async ({ page }) => {
  await page.goto("/manual/");
  const answers = await page.locator("kbd[data-answer]").allTextContents();
  expect(answers.length).toBeGreaterThan(0);

  expect(answers.filter((answer) => !askAnswers.has(answer))).toEqual([]);
});

test("the manual's palette diagram shows a new cart's main colors", async ({ page }) => {
  const swatchColors = (selector) => page.locator(selector).evaluateAll((swatches) =>
    swatches.map((swatch) => [Number(swatch.dataset.mainColor), getComputedStyle(swatch).backgroundColor]),
  );
  await page.goto("/manual/");
  const manualSwatches = await swatchColors("[data-main-color]");

  await openShelf(page);
  await page.getByRole("button", { name: "New cart", exact: true }).click();
  await page.getByRole("button", { name: "Art", exact: true }).click();
  await page.getByRole("button", { name: "Palettes", exact: true }).click();
  const appColors = new Map(await swatchColors("#art-main-colors [data-main-color]"));

  expect(appColors.size).toBe(64);
  expect(new Set(manualSwatches.map(([index]) => index))).toEqual(new Set(appColors.keys()));
  for (const [index, color] of manualSwatches) expect(color, `main color ${index}`).toBe(appColors.get(index));
});
