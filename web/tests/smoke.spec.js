import { test, expect } from "@playwright/test";

function collectErrors(page) {
  const errors = [];
  page.on("console", (message) => {
    if (message.type() === "error") errors.push(message.text());
  });
  page.on("pageerror", (error) => errors.push(error.message));
  return errors;
}

async function expectDemoDrawn(page) {
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
}

test("boots the wasm and draws to the canvas without console errors", async ({ page }) => {
  const errors = collectErrors(page);

  await page.goto("/");

  await expectDemoDrawn(page);
  expect(errors).toEqual([]);
});

test("boots and lets the install hint be dismissed when every localStorage call throws", async ({ page }) => {
  const errors = collectErrors(page);
  await page.addInitScript(() => {
    const refuse = () => {
      throw new DOMException("The operation is insecure.", "SecurityError");
    };
    Storage.prototype.getItem = refuse;
    Storage.prototype.setItem = refuse;
    Storage.prototype.removeItem = refuse;
  });

  await page.goto("/");

  await expectDemoDrawn(page);
  await expect(page.locator("#install-hint")).toBeVisible();
  await page.getByRole("button", { name: "Not now" }).click();
  await expect(page.locator("#install-hint")).toBeHidden();
  expect(errors).toEqual([]);
});
