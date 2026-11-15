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

function answerNextDialog(page, text) {
  page.once("dialog", (dialog) => dialog.accept(text));
}

async function clickAndAnswer(page, buttonName, text) {
  answerNextDialog(page, text);
  await page.getByRole("button", { name: buttonName, exact: true }).click();
}

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

test("a new file opens empty and shown, and main.lua can require it", async ({ page }) => {
  await openTwoFiles(page);
  await clickAndAnswer(page, "New file", "Enemy");

  await expect(page.locator("#cart-status")).toHaveText("Added enemy.lua.");
  await expect(page.getByRole("tab")).toHaveText(["main.lua", "enemy.lua", "player.lua"]);
  await expect(tab(page, "enemy.lua")).toHaveAttribute("aria-selected", "true");
  await expect(page.locator(".cm-content")).toBeFocused();
  await expect(lines(page)).toHaveText([""]);
  await typeCode(page, 'error("enemy ran")');
  await tab(page, "main.lua").click();
  await typeCode(page, 'require("enemy")');
  await page.getByRole("button", { name: "Run" }).click();
  await expect(page.locator("#cart-error")).toContainText("enemy.lua:1: enemy ran");
});

test("renaming a file keeps its text, and a require of the old name is then not found", async ({ page }) => {
  await openTwoFiles(page, { "main.lua": 'require("enemy")', "enemy.lua": "return 1" });
  await tab(page, "enemy.lua").click();
  await clickAndAnswer(page, "Rename", "foe");

  await expect(page.locator("#cart-status")).toHaveText("Renamed enemy.lua to foe.lua.");
  await expect(page.getByRole("tab")).toHaveText(["main.lua", "foe.lua"]);
  await expect(tab(page, "foe.lua")).toHaveAttribute("aria-selected", "true");
  await expect(lines(page)).toHaveText(["return 1"]);
  await expect(page.getByRole("button", { name: "Rename" })).toBeFocused();
  await page.getByRole("button", { name: "Run" }).click();
  await expect(page.locator("#cart-error")).toContainText("module 'enemy' not found: this cart has no file enemy.lua");
});

test("a bad name and a taken name each show their message and change nothing", async ({ page }) => {
  await openTwoFiles(page);
  await tab(page, "player.lua").click();
  const status = page.locator("#cart-status");

  await clickAndAnswer(page, "New file", "2fast");
  await expect(status).toHaveText("Can't add 2fast.lua: code file names can't start with a digit");
  await clickAndAnswer(page, "New file", "player");
  await expect(status).toHaveText("Can't add player.lua: this cart already has it");
  await clickAndAnswer(page, "Rename", "main");
  await expect(status).toHaveText("Can't rename player.lua to main.lua: this cart already has it");

  await expect(page.getByRole("tab")).toHaveText(["main.lua", "player.lua"]);
  await expect(tab(page, "player.lua")).toHaveAttribute("aria-selected", "true");
  await expect(lines(page)).toHaveText(["return {}"]);
});

test("deleting a file shows main.lua, and Save removes the file from the folder", async ({ page }) => {
  await openTwoFiles(page);
  const deleteButton = page.getByRole("button", { name: "Delete" });
  await expect(deleteButton).toBeDisabled();
  await tab(page, "player.lua").click();
  await expect(deleteButton).toBeEnabled();
  await clickAndAnswer(page, "Delete");

  await expect(page.locator("#cart-status")).toHaveText("Deleted player.lua.");
  await expect(tab(page, "main.lua")).toHaveAttribute("aria-selected", "true");
  await expect(tab(page, "main.lua")).toBeFocused();
  await expect(deleteButton).toBeDisabled();
  await expect(page.getByRole("button", { name: "Rename" })).toBeDisabled();
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Two files.");
  const codeFilesInTwoFilesFolder = await page.evaluate(async () => {
    for (const folder of await fesStorage.listCartFolders()) {
      const cartJSON = JSON.parse(await fesStorage.readCartFile(folder, "cart.json"));
      if (cartJSON.name === "Two files") return (await fesStorage.listCartFiles(folder)).filter((name) => name.endsWith(".lua"));
    }
  });
  expect(codeFilesInTwoFilesFolder).toEqual(["main.lua"]);

  await page.reload();
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  await page.getByRole("button", { name: "Code" }).click();
  await page.locator("#cart-list").getByRole("button", { name: "Two files" }).click();
  await expect(page.locator("#cart-status")).toHaveText("Loaded Two files.");
  await expect(page.getByRole("tab")).toHaveText(["main.lua"]);
});

test("an unsaved new file comes back from the recovery copy after a reload", async ({ page }) => {
  await openTwoFiles(page);
  await clickAndAnswer(page, "New file", "enemy");

  answerNextDialog(page);
  await page.reload();
  await expect(page.locator("#cart-status")).toHaveText("Restored unsaved changes to Two files.");
  await expect(page.getByRole("tab")).toHaveText(["main.lua", "enemy.lua", "player.lua"]);
});

test("a code file that can't be removed doesn't lock a full cart out of loading (T33 QA-2)", async ({ page }) => {
  const fullCart = { "main.lua": "" };
  for (let number = 1; number <= 31; number++) fullCart[`m${String(number).padStart(2, "0")}.lua`] = "return 1";
  await page.goto("/");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  await page.getByRole("button", { name: "Code" }).click();
  await loadCodeFiles(page, fullCart, "Full");
  await page.evaluate(() => {
    FileSystemDirectoryHandle.prototype.removeEntry = () => Promise.reject(new Error("removal refused"));
  });

  await tab(page, "m31.lua").click();
  await clickAndAnswer(page, "Delete");
  await clickAndAnswer(page, "New file", "extra");
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText(/^Can't save: can't remove m31\.lua, which the cart no longer has: /);

  answerNextDialog(page);
  await page.locator("#cart-list").getByRole("button", { name: "Full" }).click();
  await expect(page.locator("#cart-status")).toHaveText("Loaded Full.");
  await expect(page.getByRole("tab")).toHaveCount(32);
  await expect(tab(page, "m31.lua")).toBeVisible();
});
