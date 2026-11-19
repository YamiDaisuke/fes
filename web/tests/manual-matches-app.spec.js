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
    if (askAnswers.has(name)) continue;
    if (await page.getByRole("button", { name, exact: true, includeHidden: true }).count() === 0) missing.push(name);
  }

  expect(missing).toEqual([]);
});
