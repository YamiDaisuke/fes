import { test, expect } from "@playwright/test";
import { openPaused, runFrames } from "./frames.js";
import { typeCode } from "./code-editor.js";

async function openBooted(page) {
  await page.goto("/");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
}

test("code typed in the editor runs when Run is pressed", async ({ page }) => {
  await openBooted(page);
  await page.getByRole("button", { name: "Code" }).click();
  await typeCode(page, 'error("from the editor")');
  await page.getByRole("button", { name: "Run" }).click();
  await expect(page.locator("#cart-error")).toContainText("main.lua:1: from the editor");
  await expect(page.locator(".cm-editor")).toBeHidden();
});

test("the controller's keys type into the code editor", async ({ page }) => {
  await openBooted(page);
  await page.getByRole("button", { name: "Code" }).click();
  const editor = page.locator(".cm-content");
  await editor.fill("");
  await editor.pressSequentially("zx");
  await editor.press("Enter");
  await editor.press("Shift+KeyY");
  await editor.press("ArrowLeft");
  await editor.press("KeyA");
  expect(await page.evaluate(() => document.querySelector(".cm-content").innerText)).toBe("zx\naY");
});

test("the game is paused while the code view is shown", async ({ page }) => {
  await page.addInitScript(() => {
    window.testCartMainLua = 'function _update() error("updated") end';
  });
  await openPaused(page);
  await page.getByRole("button", { name: "Code" }).click();
  await runFrames(page, 3);
  await expect(page.locator("#cart-error")).toBeEmpty();

  await page.getByRole("button", { name: "Run" }).click();
  await runFrames(page, 1);
  await expect(page.locator("#cart-error")).toContainText("main.lua:1: updated");
});

test("the screen comes back at the largest whole scale after the code view", async ({ page }) => {
  await openBooted(page);
  await page.getByRole("button", { name: "Code" }).click();
  await page.getByRole("button", { name: "Run" }).click();
  await expect(page.locator("#screen")).toHaveCSS("width", "960px");
});
