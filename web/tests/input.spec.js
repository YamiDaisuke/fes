import { test, expect } from "@playwright/test";
import { openPaused, runFrames } from "./frames.js";

const BUTTONS_IN_BIT_ORDER = ["left", "right", "up", "down", "a", "b", "start", "select"];

async function litIndicators(page) {
  return page.evaluate((names) => {
    const context = document.getElementById("screen").getContext("2d");
    const lit = {};
    names.forEach((name, slot) => {
      const box = context.getImageData(50 + slot * 12, 8, 8, 8).data;
      const color = box.slice(0, 4).join(",");
      let isSolid = true;
      for (let i = 0; i < box.length; i += 4) {
        if (box.slice(i, i + 4).join(",") !== color) isSolid = false;
      }
      if (isSolid) lit[name] = color;
    });
    return lit;
  }, BUTTONS_IN_BIT_ORDER);
}

async function litNames(page) {
  return Object.keys(await litIndicators(page));
}

async function touch(page, type, buttons, pointerId) {
  const control = page.locator(`[data-buttons="${buttons}"]`);
  const box = await control.boundingBox();
  await control.dispatchEvent(type, {
    pointerId,
    pointerType: "touch",
    isPrimary: pointerId === 1,
    clientX: box.x + box.width / 2,
    clientY: box.y + box.height / 2,
  });
}

test.beforeEach(async ({ page }) => {
  await openPaused(page);
});

test("each overlay button lights its own indicator for one frame when tapped", async ({ page }) => {
  for (const name of BUTTONS_IN_BIT_ORDER) {
    await page.locator(`[data-buttons="${name}"]`).tap();
    await runFrames(page, 1);
    expect(await litNames(page), `after tapping ${name}`).toEqual([name]);
    await runFrames(page, 1);
    expect(await litNames(page), `the frame after tapping ${name}`).toEqual([]);
  }
});

test("a held button shows its press frame, then stays held", async ({ page }) => {
  await touch(page, "pointerdown", "a", 1);
  await runFrames(page, 1);
  const pressedColor = (await litIndicators(page)).a;
  await runFrames(page, 1);
  const heldColor = (await litIndicators(page)).a;
  expect(pressedColor).toBeDefined();
  expect(heldColor).toBeDefined();
  expect(heldColor).not.toBe(pressedColor);

  await touch(page, "pointerup", "a", 1);
  await runFrames(page, 1);
  expect(await litNames(page)).toEqual([]);
});

test("two fingers hold the D-pad and A at once, and lifting or cancelling one releases only its buttons", async ({ page }) => {
  await touch(page, "pointerdown", "right", 1);
  await touch(page, "pointerdown", "a", 2);
  await runFrames(page, 1);
  expect(await litNames(page)).toEqual(["right", "a"]);

  await touch(page, "pointerup", "right", 1);
  await runFrames(page, 1);
  expect(await litNames(page)).toEqual(["a"]);

  await touch(page, "pointercancel", "a", 2);
  await runFrames(page, 1);
  expect(await litNames(page)).toEqual([]);
});

test("a finger sliding across the D-pad moves the press", async ({ page }) => {
  await touch(page, "pointerdown", "up", 1);
  await runFrames(page, 1);
  expect(await litNames(page)).toEqual(["up"]);

  await touch(page, "pointermove", "right", 1);
  await runFrames(page, 1);
  expect(await litNames(page)).toEqual(["right"]);

  await touch(page, "pointermove", "down right", 1);
  await runFrames(page, 1);
  expect(await litNames(page)).toEqual(["right", "down"]);
});

test("keys map to buttons and losing focus releases held keys", async ({ page }) => {
  await page.keyboard.down("ArrowLeft");
  await page.keyboard.down("KeyX");
  await runFrames(page, 2);
  expect(await litNames(page)).toEqual(["left", "a"]);

  await page.evaluate(() => window.dispatchEvent(new Event("blur")));
  await runFrames(page, 1);
  expect(await litNames(page)).toEqual([]);
});
