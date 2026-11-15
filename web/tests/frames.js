import { expect } from "@playwright/test";

export async function openPaused(page) {
  await page.addInitScript(() => {
    let queued = [];
    let clock = 0;
    window.requestAnimationFrame = (callback) => queued.push(callback);
    window.isOneGameFrameQueued = () => queued.filter((callback) => callback.name === "drawFrame").length === 1;
    window.runAnimationFramesAt = (count, periodMs) => {
      for (let i = 0; i < count; i++) {
        if (!window.isOneGameFrameQueued()) throw new Error(`expected exactly one game frame queued before frame ${i}`);
        const frame = queued;
        queued = [];
        clock += periodMs;
        for (const callback of frame) callback(clock);
      }
    };
  });
  await page.goto("/");
  await expect.poll(() => page.evaluate(() => window.isOneGameFrameQueued())).toBe(true);
}

export async function runFrames(page, count) {
  await runFramesAt(page, count, 1000 / 60);
}

export async function runFramesAt(page, count, periodMs) {
  await page.evaluate(([count, periodMs]) => window.runAnimationFramesAt(count, periodMs), [count, periodMs]);
}
