import { test, expect } from "./persistent-context.js";
import { typeCode, loadCodeFiles } from "./code-editor.js";

const twoFiles = {
  "main.lua": 'local player = require("player")',
  "player.lua": "return {}",
};

async function openTwoFiles(page, codeFiles = twoFiles) {
  await page.goto("/");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  await page.getByRole("button", { name: "Code" }).click();
  await loadCodeFiles(page, codeFiles);
}

const tab = (page, name) => page.getByRole("tab", { name });
const lines = (page) => page.locator(".cm-line");

async function typeAtEnd(page, text) {
  await lines(page).last().click();
  await page.keyboard.press("End");
  await page.keyboard.type(text);
}

test("tapping a file's tab shows its text and selects only that tab", async ({ page }) => {
  await openTwoFiles(page);
  await expect(tab(page, "main.lua")).toHaveAttribute("aria-selected", "true");

  await tab(page, "player.lua").click();
  await expect(lines(page)).toHaveText(["return {}"]);
  await expect(tab(page, "player.lua")).toHaveAttribute("aria-selected", "true");
  await expect(tab(page, "main.lua")).toHaveAttribute("aria-selected", "false");
  await expect(page.getByRole("textbox", { name: "player.lua" })).toBeVisible();
});

test("each file keeps its own text and undo history across tab switches", async ({ page }) => {
  await openTwoFiles(page);
  await tab(page, "player.lua").click();
  await typeAtEnd(page, " -- p");
  await tab(page, "main.lua").click();
  await typeAtEnd(page, " -- m");

  await tab(page, "player.lua").click();
  await expect(lines(page)).toHaveText(["return {} -- p"]);
  await page.locator(".cm-content").focus();
  await page.keyboard.press("Meta+z");
  await expect(lines(page)).toHaveText(["return {}"]);
  await tab(page, "main.lua").click();
  await expect(lines(page)).toHaveText(['local player = require("player") -- m']);
});

test("a syntax error typed in another file is marked there within a moment", async ({ page }) => {
  await openTwoFiles(page);
  await tab(page, "player.lua").click();
  await typeCode(page, "x = 1\nx = = 1");

  await expect(lines(page).nth(1).locator(".cm-lintRange-error")).toHaveCount(1);
  await expect(page.locator("#code-error")).toHaveText("player.lua:2: unexpected symbol near '='");
});

test("an error's mark follows its file across tab switches", async ({ page }) => {
  await openTwoFiles(page);
  await tab(page, "player.lua").click();
  await typeCode(page, "x = = 1");
  await expect(page.locator(".cm-lintRange-error")).toHaveCount(1);

  await tab(page, "main.lua").click();
  await typeCode(page, "x = 1");
  await page.waitForTimeout(700);
  await expect(page.locator(".cm-lintRange-error")).toHaveCount(0);
  await expect(page.locator("#code-error")).toHaveText("player.lua:1: unexpected symbol near '='");

  await tab(page, "player.lua").click();
  await expect(page.locator(".cm-lintRange-error")).toHaveCount(1);

  await tab(page, "main.lua").click();
  await typeCode(page, "y = = 2");
  await expect(page.locator("#code-error")).toHaveText("main.lua:1: unexpected symbol near '='");
  await tab(page, "player.lua").click();
  await expect(page.locator(".cm-lintRange-error")).toHaveCount(0);
});

test("arrow keys on the tabs switch files and wrap at the ends", async ({ page }) => {
  await openTwoFiles(page, { ...twoFiles, "enemy.lua": "return 1" });
  await tab(page, "main.lua").focus();

  await page.keyboard.press("ArrowRight");
  await expect(tab(page, "enemy.lua")).toBeFocused();
  await expect(tab(page, "enemy.lua")).toHaveAttribute("aria-selected", "true");
  await expect(lines(page)).toHaveText(["return 1"]);
  await page.keyboard.press("End");
  await expect(tab(page, "player.lua")).toBeFocused();
  await page.keyboard.press("ArrowRight");
  await expect(tab(page, "main.lua")).toBeFocused();
  await page.keyboard.press("ArrowLeft");
  await expect(tab(page, "player.lua")).toBeFocused();
  await page.keyboard.press("Home");
  await expect(tab(page, "main.lua")).toBeFocused();
  await expect(lines(page)).toHaveText([twoFiles["main.lua"]]);
});

test("Save, reload and Load keep every file and its tab", async ({ page }) => {
  await openTwoFiles(page);
  await tab(page, "player.lua").click();
  await typeAtEnd(page, " -- saved");
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Two files.");

  await page.reload();
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  await page.getByRole("button", { name: "Code" }).click();
  await page.locator("#cart-list").getByRole("button", { name: "Two files" }).click();
  await expect(page.locator("#cart-status")).toHaveText("Loaded Two files.");
  await expect(page.getByRole("tab")).toHaveText(["main.lua", "player.lua"]);
  await tab(page, "player.lua").click();
  await expect(lines(page)).toHaveText(["return {} -- saved"]);
});

test("loading a cart forgets the undo history of the code it replaces", async ({ page }) => {
  await openTwoFiles(page);
  await typeAtEnd(page, " -- typed");
  await tab(page, "player.lua").click();
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Two files.");

  await page.locator("#cart-list").getByRole("button", { name: "Two files" }).click();
  await expect(page.locator("#cart-status")).toHaveText("Loaded Two files.");
  await page.locator(".cm-content").focus();
  await page.keyboard.press("Meta+z");
  await expect(lines(page)).toHaveText(['local player = require("player") -- typed']);
});
