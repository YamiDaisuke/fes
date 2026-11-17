import { test, expect } from "@playwright/test";
import { openPaused, runFrames } from "./frames.js";

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    window.testCartMainLua = "function _draw() cls(1) spr(0, 20, 20) end";
  });
});

async function expectCRT(page, on) {
  await expect(page.locator("body")).toHaveAttribute("data-crt", on ? "on" : "off");
  await expect(page.locator("#crt-toggle")).toHaveAttribute("aria-pressed", String(on));
}

test("the CRT filter is off on first boot, the key turns it on and off, and the choice survives a reload", async ({ page }) => {
  await openPaused(page);
  await expectCRT(page, false);
  await expect(page.locator("#screen-crt")).toBeHidden();

  await page.getByRole("button", { name: "CRT filter" }).click();
  await expectCRT(page, true);
  await expect(page.locator("#screen-crt")).toBeVisible();

  await page.reload();
  await expectCRT(page, true);

  await page.getByRole("button", { name: "CRT filter" }).click();
  await page.reload();
  await expectCRT(page, false);
});

test("with localStorage throwing, the CRT key still switches the filter for the visit and the page reports no error", async ({ page }) => {
  const errors = [];
  page.on("pageerror", (error) => errors.push(error.message));
  await page.addInitScript(() => {
    const refuse = () => {
      throw new DOMException("The operation is insecure.", "SecurityError");
    };
    Storage.prototype.getItem = refuse;
    Storage.prototype.setItem = refuse;
  });
  await openPaused(page);
  await expectCRT(page, false);

  await page.getByRole("button", { name: "CRT filter" }).click();
  await expectCRT(page, true);
  await page.getByRole("button", { name: "CRT filter" }).click();
  await expectCRT(page, false);
  expect(errors).toEqual([]);
});

test("the canvas's pixels are identical with the filter off and on", async ({ page }) => {
  await openPaused(page);
  const readCanvas = () =>
    page.evaluate(() => {
      const canvas = document.getElementById("screen");
      return Array.from(canvas.getContext("2d").getImageData(0, 0, canvas.width, canvas.height).data);
    });
  await runFrames(page, 2);
  const filterOff = await readCanvas();

  await page.getByRole("button", { name: "CRT filter" }).click();
  await runFrames(page, 1);
  const filterOn = await readCanvas();

  expect(filterOn.some((value) => value !== 0)).toBe(true);
  expect(filterOn).toEqual(filterOff);
});
