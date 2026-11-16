import { test, expect } from "./persistent-context.js";
import { loadCodeFiles } from "./code-editor.js";
import { openShelf, selectOnShelf } from "./shelf.js";
import { answerQuestion } from "./ask.js";

async function openCodeView(page) {
  await page.goto("/");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  await page.getByRole("button", { name: "Code" }).click();
}

const button = (page, name) => page.getByRole("button", { name, exact: true });
const tab = (page, name) => page.getByRole("tab", { name });

async function waitTwoAnimationFrames(page) {
  await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

test("Escape cancels a question and focus returns to the key that asked", async ({ page }) => {
  await openCodeView(page);
  await button(page, "New file").click();
  await expect(page.locator("#ask-field")).toBeFocused();

  await page.keyboard.press("Escape");
  await expect(page.locator("#ask")).toBeHidden();
  await expect(button(page, "New file")).toBeFocused();
  await expect(page.getByRole("tab")).toHaveText(["main.lua"]);
});

test("a destructive question starts on Cancel, so Enter keeps the file", async ({ page }) => {
  await openCodeView(page);
  await loadCodeFiles(page, { "main.lua": "", "player.lua": "return {}" });
  await tab(page, "player.lua").click();
  await button(page, "Delete").click();
  await expect(page.locator("#ask-cancel")).toBeFocused();

  await page.keyboard.press("Enter");
  await expect(page.locator("#ask")).toBeHidden();
  await expect(page.getByRole("tab")).toHaveText(["main.lua", "player.lua"]);
});

test("Tab and Shift+Tab stay inside the question", async ({ page }) => {
  await openCodeView(page);
  await button(page, "New file").click();
  await expect(page.locator("#ask-field")).toBeFocused();

  await page.keyboard.press("Tab");
  await page.keyboard.press("Tab");
  await page.keyboard.press("Tab");
  await expect(page.locator("#ask-field")).toBeFocused();
  await page.keyboard.press("Shift+Tab");
  await expect(page.locator("#ask-confirm")).toBeFocused();
});

test("Enter on the Restore question restores, since declining drops the copy", async ({ page }) => {
  await openCodeView(page);
  await page.evaluate(() => fesStorage.writeRecoveryCopy(JSON.stringify({ name: "Demo", mainLua: "-- restored" })));

  await page.reload();
  await expect(page.locator("#ask-confirm")).toBeFocused();
  await page.keyboard.press("Enter");
  await expect(page.locator("#cart-status")).toHaveText("Restored unsaved changes to Demo.");
  await expect(page.locator(".cm-content")).toHaveText("-- restored");
});

test("console keys pressed while a question is open don't play or move the shelf, wherever focus is", async ({ page }) => {
  await openCodeView(page);
  await page.locator("#cart-name").fill("Mine");
  await button(page, "Save").click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Mine.");
  await openShelf(page);
  await selectOnShelf(page, "Mine");
  await button(page, "Delete").click();
  await expect(page.locator("#ask")).toBeVisible();

  await page.keyboard.press("Tab");
  await page.keyboard.press("Tab");
  await page.keyboard.press("ArrowLeft");
  await page.keyboard.press("z");
  await page.evaluate(() => document.activeElement.blur());
  await page.keyboard.press("ArrowLeft");
  await page.keyboard.press("z");
  await waitTwoAnimationFrames(page);
  await answerQuestion(page, "Cancel");
  await button(page, "Duplicate").click();
  await expect(page.locator("#cart-status")).toHaveText("Duplicated Mine as Mine copy.");

  await expect(page.locator("body")).toHaveAttribute("data-view", "shelf");
  await expect(page.locator("#ask")).toBeHidden();
});

test("a load that finishes while a question is open waits for the answer", async ({ page }) => {
  await openCodeView(page);
  await loadCodeFiles(page, { "main.lua": "", "player.lua": "return {}" });
  await tab(page, "player.lua").click();
  await button(page, "Delete").click();
  await expect(page.locator("#ask")).toBeVisible();

  await page.evaluate(() => {
    document.querySelector('#shelf-list button[data-folder=""]').click();
    document.getElementById("shelf-edit").click();
  });
  await page.locator("#ask-confirm").click();
  await expect(page.locator("#ask-question")).toHaveText("Discard unsaved changes to Two files?");
  await expect(page.locator("#cart-status")).toHaveText("Deleted player.lua.");
  await answerQuestion(page, "Cancel");
  await expect(page.getByRole("tab")).toHaveText(["main.lua"]);
});

test("a question sits on whole pixels in an odd-width window", async ({ page }) => {
  await page.setViewportSize({ width: 1133, height: 744 });
  await openCodeView(page);
  await button(page, "New file").click();

  const box = await page.locator("#ask").evaluate((dialog) => dialog.getBoundingClientRect().toJSON());
  expect(Number.isInteger(box.x)).toBe(true);
  expect(Number.isInteger(box.y)).toBe(true);
});

test("a long name with no spaces wraps inside the question", async ({ page }) => {
  await page.setViewportSize({ width: 744, height: 1133 });
  await openCodeView(page);
  const longName = "W".repeat(64);
  await page.locator("#cart-name").fill(longName);
  await button(page, "Save").click();
  await expect(page.locator("#cart-status")).toHaveText(`Saved ${longName}.`);
  await openShelf(page);
  await selectOnShelf(page, longName);
  await button(page, "Delete").click();

  const question = page.locator("#ask-question");
  await expect(question).toContainText(longName);
  const questionBox = await question.boundingBox();
  const dialogBox = await page.locator("#ask").boundingBox();
  expect(questionBox.width).toBeLessThanOrEqual(dialogBox.width);
});
