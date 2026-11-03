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

function recordDialogs(page, answer) {
  const messages = [];
  page.on("dialog", (dialog) => {
    messages.push(dialog.message());
    answer === "accept" ? dialog.accept() : dialog.dismiss();
  });
  return messages;
}

async function reloadUntilCartsListed(page) {
  await page.reload();
  // FES offers the copy in the same microtask run that draws the cart list.
  await expect(page.locator("#cart-list button")).not.toHaveCount(0);
}

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    window.testCartMainLua = "-- original";
  });
});

test("unsaved code comes back after a reload when the prompt is accepted", async ({ page }) => {
  await openBooted(page);
  await saveAs(page, "Mine");
  await page.locator(".cm-content").fill('error("edited")');
  const questions = recordDialogs(page, "accept");

  await page.reload();
  await expect.poll(() => questions).toEqual(["Restore unsaved changes to Mine?"]);
  await expect(page.locator(".cm-content")).toHaveText('error("edited")');
  await expect(page.locator("#cart-name")).toHaveValue("Mine");
  await expect(page.locator("#cart-status")).toHaveText("Restored unsaved changes to Mine.");
  await page.getByRole("button", { name: "Run" }).click();
  await expect(page.locator("#cart-error")).toContainText("main.lua:1: edited");
});

test("declining the prompt drops the copy", async ({ page }) => {
  await openBooted(page);
  await saveAs(page, "Mine");
  await page.locator(".cm-content").fill("-- edited");
  const questions = recordDialogs(page, "dismiss");

  await reloadUntilCartsListed(page);
  await expect.poll(() => questions).toEqual(["Restore unsaved changes to Mine?"]);
  await page.getByRole("button", { name: "Code" }).click();
  await expect(page.locator(".cm-content")).toHaveText("-- original");
  expect(await page.evaluate(() => fesStorage.readUnsavedCode())).toBeNull();

  await reloadUntilCartsListed(page);
  expect(questions).toHaveLength(1);
});

test("saving removes the copy", async ({ page }) => {
  await openBooted(page);
  await page.locator(".cm-content").fill("-- edited");
  await saveAs(page, "Mine");
  const questions = recordDialogs(page, "accept");

  await reloadUntilCartsListed(page);
  expect(questions).toEqual([]);
});

test("code whose saved cart can't be read is restored as a new cart", async ({ page }) => {
  await openBooted(page);
  await saveAs(page, "Mine");
  await page.locator(".cm-content").fill("-- edited");
  await page.evaluate(async () => {
    const [folder] = await fesStorage.listCartFolders();
    await fesStorage.writeCartFile(folder, "cart.json", "{");
  });
  recordDialogs(page, "accept");

  await page.reload();
  await expect(page.locator("#cart-status")).toHaveText(
    "Restored unsaved code of Mine as a new cart: its saved cart couldn't be read or was renamed.",
  );
  await expect(page.locator(".cm-content")).toHaveText("-- edited");
  await saveAs(page, "Mine");
  expect(await page.evaluate(() => fesStorage.listCartFolders())).toHaveLength(2);
});

test("a malformed copy is removed without asking", async ({ page }) => {
  await openBooted(page);
  await saveAs(page, "Mine");
  await page.evaluate(() => fesStorage.writeUnsavedCode("{"));
  const questions = recordDialogs(page, "accept");

  await reloadUntilCartsListed(page);
  expect(questions).toEqual([]);
  expect(await page.evaluate(() => fesStorage.readUnsavedCode())).toBeNull();
});

test("a copy whose folder now holds another cart is restored as a new cart", async ({ page }) => {
  await openBooted(page);
  await saveAs(page, "Mine");
  const [mineFolder] = await page.evaluate(() => fesStorage.listCartFolders());
  await page.evaluate((folder) => {
    fesStorage.writeUnsavedCode(JSON.stringify({ folder, name: "Other", mainLua: "-- other's edit" }));
  }, mineFolder);
  recordDialogs(page, "accept");

  await page.reload();
  await expect(page.locator("#cart-status")).toHaveText(
    "Restored unsaved code of Other as a new cart: its saved cart couldn't be read or was renamed.",
  );
  await expect(page.locator("#cart-name")).toHaveValue("Other");
  await saveAs(page, "Other");
  expect(await page.evaluate(() => fesStorage.listCartFolders())).toHaveLength(2);
  expect(await page.evaluate((folder) => fesStorage.readCartFile(folder, "main.lua"), mineFolder)).toBe("-- original");
});

test("an edited cart that was never saved is restored under its name", async ({ page }) => {
  await openBooted(page);
  await page.locator(".cm-content").fill("-- edited demo");
  const questions = recordDialogs(page, "accept");

  await page.reload();
  await expect.poll(() => questions).toEqual(["Restore unsaved changes to Demo?"]);
  await expect(page.locator("#cart-status")).toHaveText("Restored unsaved changes to Demo.");
  await expect(page.locator(".cm-content")).toHaveText("-- edited demo");
  await saveAs(page, "Demo");
  expect(await page.evaluate(() => fesStorage.listCartFolders())).toHaveLength(1);
});

test("undoing back to the saved code removes the copy", async ({ page }) => {
  await openBooted(page);
  await saveAs(page, "Mine");
  const editor = page.locator(".cm-content");
  await editor.press("End");
  await editor.pressSequentially("x");
  expect(await page.evaluate(() => fesStorage.readUnsavedCode())).not.toBeNull();

  await editor.press("Control+z");
  await expect(editor).toHaveText("-- original");
  expect(await page.evaluate(() => fesStorage.readUnsavedCode())).toBeNull();
});

ephemeralTest("a restore without saving still says why Save is unavailable", async ({ page }) => {
  await openBooted(page);
  await page.locator(".cm-content").fill("-- edited demo");
  recordDialogs(page, "accept");

  await page.reload();
  await expect(page.locator(".cm-content")).toHaveText("-- edited demo");
  await expect(page.locator("#cart-status")).toHaveText("Saving is unavailable (Private Browsing?)");
});
