import { expect } from "@playwright/test";

export async function openPaused(page) {
  await page.addInitScript(() => {
    let queued = [];
    window.requestAnimationFrame = (callback) => queued.push(callback);
    window.isGameFrameQueued = () => queued.some((callback) => callback.name === "drawFrame");
    window.runAnimationFrames = (count) => {
      for (let i = 0; i < count; i++) {
        if (!window.isGameFrameQueued()) throw new Error(`no game frame queued before frame ${i}`);
        const frame = queued;
        queued = [];
        for (const callback of frame) callback(performance.now());
      }
    };
  });
  await page.goto("/");
  await expect.poll(() => page.evaluate(() => window.isGameFrameQueued())).toBe(true);
}

export async function runFrames(page, count) {
  await page.evaluate((count) => window.runAnimationFrames(count), count);
}
