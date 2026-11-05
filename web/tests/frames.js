import { expect } from "@playwright/test";

export async function openPaused(page) {
  await page.addInitScript(() => {
    let queued = [];
    window.requestAnimationFrame = (callback) => queued.push(callback);
    window.isOneGameFrameQueued = () => queued.filter((callback) => callback.name === "drawFrame").length === 1;
    window.runAnimationFrames = (count) => {
      for (let i = 0; i < count; i++) {
        if (!window.isOneGameFrameQueued()) throw new Error(`expected exactly one game frame queued before frame ${i}`);
        const frame = queued;
        queued = [];
        for (const callback of frame) callback(performance.now());
      }
    };
  });
  await page.goto("/");
  await expect.poll(() => page.evaluate(() => window.isOneGameFrameQueued())).toBe(true);
}

export async function runFrames(page, count) {
  await page.evaluate((count) => window.runAnimationFrames(count), count);
}
