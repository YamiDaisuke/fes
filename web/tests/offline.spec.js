import { readdirSync } from "node:fs";
import { test, expect } from "@playwright/test";

test("FES boots from the service worker cache with the network off", async ({ page, context }) => {
  await page.goto("/");
  await page.evaluate(() => navigator.serviceWorker.ready);
  if (await page.evaluate(() => navigator.serviceWorker.controller === null)) await page.reload();
  await expect.poll(() => page.evaluate(() => navigator.serviceWorker.controller !== null)).toBe(true);

  await context.setOffline(true);
  await page.reload();

  await expect(page.locator("#shelf-list").getByRole("button", { name: "Built-in demo" })).toBeVisible();
  expect(await page.evaluate(() => getComputedStyle(document.body).display)).toBe("grid");
});

test("the service worker precaches every built file", async ({ page }) => {
  const builtFiles = readdirSync("web/dist", { recursive: true, withFileTypes: true })
    .filter((entry) => entry.isFile())
    .map((entry) => `${entry.parentPath}/${entry.name}`.replace(/^web\/dist/, ""))
    .filter((path) => path !== "/sw.js" && path !== "/index.html");

  await page.goto("/");
  await page.evaluate(() => navigator.serviceWorker.ready);
  const precached = await page.evaluate(async () => {
    const [cacheName] = await caches.keys();
    const requests = await (await caches.open(cacheName)).keys();
    return requests.map((request) => new URL(request.url).pathname);
  });

  expect(precached.sort()).toEqual(["/", ...builtFiles].sort());
});
