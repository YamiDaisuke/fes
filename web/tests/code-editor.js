import { expect } from "@playwright/test";

export async function typeCode(page, code) {
  // WebKit's fill() on CodeMirror sometimes leaves an extra empty first line (T14 QA-6).
  await expect(async () => {
    await page.locator(".cm-content").fill(code);
    await expect(page.locator(".cm-line")).toHaveText(code.split("\n"), { timeout: 1000 });
  }).toPass();
}
