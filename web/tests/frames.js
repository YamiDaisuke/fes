import { expect } from "@playwright/test";

export async function openPaused(page) {
  await page.addInitScript(() => {
    const queued = [];
    window.requestAnimationFrame = (callback) => queued.push(callback);
    window.queuedAnimationFrames = () => queued.length;
    window.runAnimationFrames = (count) => {
      for (let i = 0; i < count; i++) {
        if (queued.length === 0) throw new Error(`no animation frame queued before frame ${i}`);
        queued.shift()(performance.now());
      }
    };
  });
  await page.goto("/");
  await expect.poll(() => page.evaluate(() => window.queuedAnimationFrames())).toBe(1);
}

export async function runFrames(page, count) {
  await page.evaluate((count) => window.runAnimationFrames(count), count);
}
