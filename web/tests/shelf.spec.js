import { readFile } from "node:fs/promises";
import { test, expect } from "./persistent-context.js";
import { typeCode } from "./code-editor.js";
import { openShelf, selectOnShelf } from "./shelf.js";

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    window.testCartMainLua = 'error("from boot")';
  });
});

async function saveCodeAs(page, name, code) {
  await page.goto("/");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  await page.getByRole("button", { name: "Code" }).click();
  await typeCode(page, code);
  await page.locator("#cart-name").fill(name);
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText(`Saved ${name}.`);
}

function answerNextDialog(page, answer) {
  const questions = [];
  page.once("dialog", (dialog) => {
    questions.push(dialog.message());
    answer === "accept" ? dialog.accept() : dialog.dismiss();
  });
  return questions;
}

test("Play runs the selected saved cart in the game view", async ({ page }) => {
  await saveCodeAs(page, "Mine", 'error("from shelf")');
  await page.reload();

  await openShelf(page);
  await selectOnShelf(page, "Mine");
  await page.getByRole("button", { name: "Play" }).click();
  await expect(page.locator("body")).toHaveAttribute("data-view", "game");
  await expect(page.locator("#cart-error")).toContainText("main.lua:1: from shelf");
});

test("Edit shows the selected saved cart's code and name in the Code view", async ({ page }) => {
  await saveCodeAs(page, "Mine", "-- mine");
  await page.reload();

  await openShelf(page);
  await selectOnShelf(page, "Mine");
  await page.getByRole("button", { name: "Edit", exact: true }).click();
  await expect(page.locator("body")).toHaveAttribute("data-view", "code");
  await expect(page.locator(".cm-content")).toHaveText("-- mine");
  await expect(page.locator("#cart-name")).toHaveValue("Mine");
});

test("Play and Edit wait for a selection, and Export is only for saved carts", async ({ page }) => {
  await saveCodeAs(page, "Mine", "-- mine");
  await openShelf(page);
  const play = page.getByRole("button", { name: "Play" });
  const edit = page.getByRole("button", { name: "Edit", exact: true });
  const exportButton = page.getByRole("button", { name: "Export" });
  await expect(play).toBeDisabled();
  await expect(edit).toBeDisabled();
  await expect(exportButton).toBeDisabled();

  await selectOnShelf(page, "Built-in demo");
  await expect(play).toBeEnabled();
  await expect(edit).toBeEnabled();
  await expect(exportButton).toBeDisabled();

  await selectOnShelf(page, "Mine");
  await expect(exportButton).toBeEnabled();
});

test("the built-in demo opens after asking about unsaved changes, and saves as a new cart", async ({ page }) => {
  await saveCodeAs(page, "Mine", "-- mine");
  await typeCode(page, "-- edited");

  await openShelf(page);
  await selectOnShelf(page, "Built-in demo");
  const questions = answerNextDialog(page, "accept");
  await page.getByRole("button", { name: "Edit", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Opened the built-in demo.");
  expect(questions).toEqual(["Discard unsaved changes to Mine?"]);
  await expect(page.locator(".cm-content")).toHaveText('error("from boot")');
  await expect(page.locator("#cart-name")).toHaveValue("Demo");

  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Demo.");
  expect(await page.evaluate(() => fesStorage.listCartFolders())).toHaveLength(2);
});

test("Export exports the selected saved cart, not the open cart's unsaved edits", async ({ page }) => {
  await saveCodeAs(page, "Mine", "-- the saved code");
  await typeCode(page, "-- the open code");

  await openShelf(page);
  await selectOnShelf(page, "Mine");
  const downloading = page.waitForEvent("download");
  await page.getByRole("button", { name: "Export" }).click();
  const download = await downloading;
  expect(download.suggestedFilename()).toBe("Mine.fes");
  const archive = await readFile(await download.path());
  expect(archive.includes("-- the saved code")).toBe(true);
  expect(archive.includes("-- the open code")).toBe(false);
});

test("cancelling the unsaved-changes question on Play keeps the edit and stays on the shelf", async ({ page }) => {
  await saveCodeAs(page, "Mine", "-- mine");
  await typeCode(page, "-- edited");

  await openShelf(page);
  await selectOnShelf(page, "Mine");
  const questions = answerNextDialog(page, "dismiss");
  await page.getByRole("button", { name: "Play" }).click();
  await expect.poll(() => questions).toEqual(["Discard unsaved changes to Mine?"]);
  await expect(page.locator("body")).toHaveAttribute("data-view", "shelf");
  await page.getByRole("button", { name: "Code" }).click();
  await expect(page.locator(".cm-content")).toHaveText("-- edited");
});

function delayStorage(page, milliseconds) {
  return page.addInitScript((milliseconds) => {
    // In WebKit a patch on navigator.storage itself is lost on some later navigations; one on the prototype isn't.
    const getDirectory = StorageManager.prototype.getDirectory;
    StorageManager.prototype.getDirectory = function () {
      return new Promise((resolve) => setTimeout(() => resolve(getDirectory.call(this)), milliseconds));
    };
  }, milliseconds);
}

test("Carts tapped while saved carts are still being listed shows the built-in demo", async ({ page }) => {
  const pageErrors = [];
  page.on("pageerror", (error) => pageErrors.push(error.message));
  await delayStorage(page, 3000);
  await page.goto("/");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");

  await page.getByRole("button", { name: "Carts" }).click();
  await expect(page.locator("#shelf-list").getByRole("button", { name: "Built-in demo" })).toBeFocused();
  expect(pageErrors).toEqual([]);
});

test("the shelf entry with focus keeps it when the boot listing finishes", async ({ page }) => {
  await saveCodeAs(page, "Mine", "-- mine");
  await delayStorage(page, 3000);
  await page.reload();
  await expect(page.locator("#cart-name")).toHaveValue("Demo");

  await page.getByRole("button", { name: "Carts" }).click();
  await expect(page.locator("#shelf-list").getByRole("button", { name: "Built-in demo" })).toBeFocused();
  await expect(page.locator("#shelf-list").getByRole("button", { name: "Mine" })).toBeAttached({ timeout: 15000 });
  await expect(page.locator("#shelf-list").getByRole("button", { name: "Built-in demo" })).toBeFocused();
});

test("the shelf entry with focus keeps it when a save finishes", async ({ page }) => {
  await saveCodeAs(page, "Mine", "-- mine");
  await page.locator("#cart-name").fill("Renamed");
  await openShelf(page);
  await page.locator("#shelf-list").getByRole("button", { name: "Mine" }).focus();

  await page.locator("#cart-save").dispatchEvent("click");
  await expect(page.locator("#cart-status")).toHaveText("Saved Renamed.");
  await expect(page.locator("#shelf-list").getByRole("button", { name: "Renamed" })).toBeFocused();
});

test("a save finishing while focus is outside the shelf list leaves focus where it is", async ({ page }) => {
  await saveCodeAs(page, "Mine", "-- mine");
  await page.locator("#cart-name").fill("Renamed");
  await openShelf(page);
  await page.getByRole("button", { name: "Import" }).focus();

  await page.locator("#cart-save").dispatchEvent("click");
  await expect(page.locator("#cart-status")).toHaveText("Saved Renamed.");
  await expect(page.getByRole("button", { name: "Import" })).toBeFocused();
});
