import { test, expect } from "@playwright/test";
import { openPaused, runFrames, runFramesAt } from "./frames.js";

const COUNTING_CART = "n = 0 function _update() n = n + 1 end function _draw() cls() spr(0, n % 192, 0) end";

async function spriteColumn(page) {
  return page.evaluate(() => {
    const canvas = document.getElementById("screen");
    const topRow = canvas.getContext("2d").getImageData(0, 0, canvas.width, 1).data;
    const pixel = (x) => topRow.slice(x * 4, x * 4 + 4).join();
    const background = pixel(canvas.width - 1);
    for (let x = 0; x < canvas.width; x++) {
      if (pixel(x) !== background) return x;
    }
    return null;
  });
}

test.beforeEach(async ({ page }) => {
  await page.addInitScript((mainLua) => { window.testCartMainLua = mainLua; }, COUNTING_CART);
  await openPaused(page);
  await runFrames(page, 1);
});

test("a 120 Hz display still runs 60 console frames a second", async ({ page }) => {
  const before = await spriteColumn(page);
  await runFramesAt(page, 120, 1000 / 120);
  expect(Math.abs((await spriteColumn(page)) - before - 60)).toBeLessThanOrEqual(1);
});

test("a 30 Hz display still runs 60 console frames a second", async ({ page }) => {
  const before = await spriteColumn(page);
  await runFramesAt(page, 30, 1000 / 30);
  expect(Math.abs((await spriteColumn(page)) - before - 60)).toBeLessThanOrEqual(1);
});

test("after a 5-second gap the console runs 4 frames and then does not catch up", async ({ page }) => {
  const before = await spriteColumn(page);
  await runFramesAt(page, 1, 5000);
  const afterGap = await spriteColumn(page);
  expect(afterGap - before).toBe(4);
  await runFrames(page, 1);
  expect((await spriteColumn(page)) - afterGap).toBe(1);
});
