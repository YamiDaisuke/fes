import { test, expect } from "@playwright/test";

test("FES boots from the service worker cache with the network off", async ({ page, context }) => {
  await page.goto("/");
  await page.evaluate(() => navigator.serviceWorker.ready);
  if (await page.evaluate(() => navigator.serviceWorker.controller === null)) await page.reload();
  await expect.poll(() => page.evaluate(() => navigator.serviceWorker.controller !== null)).toBe(true);

  await context.setOffline(true);
  await page.reload();

  await expect
    .poll(() =>
      page.evaluate(() => {
        const canvas = document.getElementById("screen");
        return canvas.getContext("2d").getImageData(canvas.width / 2, canvas.height / 2, 1, 1).data[3];
      }),
    )
    .toBe(255);
});
