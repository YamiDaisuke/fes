import { test as ephemeralTest } from "@playwright/test";
import { test, expect } from "./persistent-context.js";

async function openBooted(page) {
  await page.goto("/");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  await page.getByRole("button", { name: "Code" }).click();
}

async function saveAs(page, name) {
  await page.locator("#cart-name").fill(name);
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText(`Saved ${name}.`);
}

async function loadExpectingQuestion(page, name, question) {
  const questions = [];
  page.once("dialog", (dialog) => {
    questions.push(dialog.message());
    dialog.dismiss();
  });
  await page.locator("#cart-list").getByRole("button", { name }).click();
  await expect.poll(() => questions).toEqual([question]);
}

test("a saved cart's code runs when it is loaded on another page", async ({ context, page }) => {
  await page.addInitScript(() => {
    window.testCartMainLua = 'error("from saved cart")';
  });
  await openBooted(page);
  await saveAs(page, "Saved");
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-list button")).toHaveCount(1);

  const secondPage = await context.newPage();
  await openBooted(secondPage);
  await secondPage.locator("#cart-list").getByRole("button", { name: "Saved" }).click();
  await expect(secondPage.locator(".cm-content")).toHaveText('error("from saved cart")');
  await expect(secondPage.locator("#cart-name")).toHaveValue("Saved");
  await secondPage.getByRole("button", { name: "Run" }).click();
  await expect(secondPage.locator("#cart-error")).toContainText("main.lua:1: from saved cart");
});

test("Enter on the focused Save button saves", async ({ page }) => {
  await openBooted(page);
  await page.getByRole("button", { name: "Save", exact: true }).focus();
  await page.keyboard.press("Enter");
  await expect(page.locator("#cart-status")).toHaveText("Saved Demo.");
});

test("loading over unsaved code asks first, and cancelling keeps the edit", async ({ page }) => {
  await page.addInitScript(() => {
    window.testCartMainLua = "-- saved";
  });
  await openBooted(page);
  await saveAs(page, "Mine");
  await expect(page.locator("#cart-list button")).toHaveCount(1);
  const editor = page.locator(".cm-content");
  await editor.fill("-- edited");

  await loadExpectingQuestion(page, "Mine", "Discard unsaved changes to Mine?");
  await expect(editor).toHaveText("-- edited");

  page.once("dialog", (dialog) => dialog.accept());
  await page.locator("#cart-list").getByRole("button", { name: "Mine" }).click();
  await expect(page.locator("#cart-status")).toHaveText("Loaded Mine.");
  await expect(editor).toHaveText("-- saved");
});

test("loading over an edited boot cart asks first, even before any save on this page", async ({ context, page }) => {
  await openBooted(page);
  await saveAs(page, "Mine");

  const secondPage = await context.newPage();
  await openBooted(secondPage);
  await secondPage.locator(".cm-content").fill("-- my edit to the demo");
  await loadExpectingQuestion(secondPage, "Mine", "Discard unsaved changes to Demo?");
  await expect(secondPage.locator(".cm-content")).toHaveText("-- my edit to the demo");
});

test("code typed while a save is running stays unsaved", async ({ page }) => {
  await page.addInitScript(() => {
    const close = FileSystemWritableFileStream.prototype.close;
    FileSystemWritableFileStream.prototype.close = async function () {
      await new Promise((resolve) => setTimeout(resolve, 300));
      return close.call(this);
    };
  });
  await openBooted(page);
  await page.locator("#cart-name").fill("Mine");
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await page.locator(".cm-content").fill("-- typed during the save");
  await expect(page.locator("#cart-status")).toHaveText("Saved Mine.");
  await loadExpectingQuestion(page, "Mine", "Discard unsaved changes to Mine?");
});

test("a cart whose cart.json can't be read is listed as damaged, and choosing it names the file", async ({ page }) => {
  await openBooted(page);
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Demo.");
  await page.evaluate(async () => {
    const [folder] = await fesStorage.listCartFolders();
    await fesStorage.writeCartFile(folder, "cart.json", "{");
  });
  await openBooted(page);

  await page.locator("#cart-list").getByRole("button", { name: "Damaged cart" }).click();
  await expect(page.locator("#cart-status")).toHaveText(/^Can't load: cart.json/);
});

test("an empty name is refused and nothing is saved", async ({ page }) => {
  await openBooted(page);
  await page.locator("#cart-name").fill("  ");
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Can't save: the name is empty");
  await page.reload();
  await expect(page.locator("#cart-status")).toBeEmpty();
  await expect(page.locator("#cart-list button")).toHaveCount(0);
});

test("loading a cart with a damaged map names the file and line and keeps the current cart", async ({ page }) => {
  await openBooted(page);
  await saveAs(page, "Room");
  await page.evaluate(async () => {
    const [folder] = await fesStorage.listCartFolders();
    const map = await fesStorage.readCartFile(folder, "map.map");
    await fesStorage.writeCartFile(folder, "map.map", map.split("\n").slice(0, 31).join("\n") + "\n");
  });
  await page.locator("#cart-name").fill("Renamed but unsaved");

  await page.locator("#cart-list").getByRole("button", { name: "Room" }).click();
  await expect(page.locator("#cart-status")).toHaveText("Can't load: map.map line 32: expected 32 lines, found 31");
  await expect(page.locator("#cart-name")).toHaveValue("Renamed but unsaved");
});

ephemeralTest("without OPFS saving is unavailable and the console still boots cleanly", async ({ page }) => {
  const errors = [];
  page.on("console", (message) => {
    if (message.type() === "error") errors.push(message.text());
  });
  page.on("pageerror", (error) => errors.push(error.message));

  await page.goto("/");

  await expect
    .poll(() =>
      page.evaluate(() => {
        const canvas = document.getElementById("screen");
        return canvas.getContext("2d").getImageData(canvas.width / 2, canvas.height / 2, 1, 1).data[3];
      }),
    )
    .toBe(255);
  await page.getByRole("button", { name: "Code" }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saving is unavailable (Private Browsing?)");
  await expect(page.getByRole("button", { name: "Save", exact: true })).toBeDisabled();
  expect(errors).toEqual([]);
});
