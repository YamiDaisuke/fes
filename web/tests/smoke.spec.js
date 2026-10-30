import { test, expect } from "@playwright/test";

test("boots the wasm and draws to the canvas without console errors", async ({ page }) => {
  const errors = [];
  page.on("console", (message) => {
    if (message.type() === "error") errors.push(message.text());
  });
  page.on("pageerror", (error) => errors.push(error.message));

  await page.goto("/");

  await expect(page.locator("#screen")).toHaveJSProperty("width", 192);
  await expect
    .poll(() =>
      page.evaluate(() => {
        const canvas = document.getElementById("screen");
        const center = canvas.getContext("2d").getImageData(canvas.width / 2, canvas.height / 2, 1, 1);
        return center.data[3];
      }),
    )
    .toBe(255);
  expect(errors).toEqual([]);
});
