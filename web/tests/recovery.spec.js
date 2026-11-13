import { test as ephemeralTest } from "@playwright/test";
import { test, expect } from "./persistent-context.js";
import { typeCode } from "./code-editor.js";

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
  await typeCode(page, 'error("edited")');
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
  await typeCode(page, "-- edited");
  const questions = recordDialogs(page, "dismiss");

  await reloadUntilCartsListed(page);
  await expect.poll(() => questions).toEqual(["Restore unsaved changes to Mine?"]);
  await page.getByRole("button", { name: "Code" }).click();
  await expect(page.locator(".cm-content")).toHaveText("-- original");
  expect(await page.evaluate(() => fesStorage.readRecoveryCopy())).toBeNull();

  await reloadUntilCartsListed(page);
  expect(questions).toHaveLength(1);
});

test("saving removes the copy", async ({ page }) => {
  await openBooted(page);
  await typeCode(page, "-- edited");
  await saveAs(page, "Mine");
  const questions = recordDialogs(page, "accept");

  await reloadUntilCartsListed(page);
  expect(questions).toEqual([]);
});

test("code whose saved cart can't be read is restored as a new cart", async ({ page }) => {
  await openBooted(page);
  await saveAs(page, "Mine");
  await typeCode(page, "-- edited");
  await page.evaluate(async () => {
    const [folder] = await fesStorage.listCartFolders();
    await fesStorage.writeCartFile(folder, "cart.json", "{");
  });
  recordDialogs(page, "accept");

  await page.reload();
  await expect(page.locator("#cart-status")).toHaveText(
    "Restored unsaved changes to Mine as a new cart: its saved cart couldn't be read or was renamed.",
  );
  await expect(page.locator(".cm-content")).toHaveText("-- edited");
  await saveAs(page, "Mine");
  expect(await page.evaluate(() => fesStorage.listCartFolders())).toHaveLength(2);
});

test("a malformed copy is removed without asking", async ({ page }) => {
  await openBooted(page);
  await saveAs(page, "Mine");
  await page.evaluate(() => fesStorage.writeRecoveryCopy("{"));
  const questions = recordDialogs(page, "accept");

  await reloadUntilCartsListed(page);
  expect(questions).toEqual([]);
  expect(await page.evaluate(() => fesStorage.readRecoveryCopy())).toBeNull();
});

test("a copy whose folder now holds another cart is restored as a new cart", async ({ page }) => {
  await openBooted(page);
  await saveAs(page, "Mine");
  const [mineFolder] = await page.evaluate(() => fesStorage.listCartFolders());
  await page.evaluate((folder) => {
    fesStorage.writeRecoveryCopy(JSON.stringify({ folder, name: "Other", mainLua: "-- other's edit" }));
  }, mineFolder);
  recordDialogs(page, "accept");

  await page.reload();
  await expect(page.locator("#cart-status")).toHaveText(
    "Restored unsaved changes to Other as a new cart: its saved cart couldn't be read or was renamed.",
  );
  await expect(page.locator("#cart-name")).toHaveValue("Other");
  await saveAs(page, "Other");
  expect(await page.evaluate(() => fesStorage.listCartFolders())).toHaveLength(2);
  expect(await page.evaluate((folder) => fesStorage.readCartFile(folder, "main.lua"), mineFolder)).toBe("-- original");
});

test("an edited cart that was never saved is restored under its name", async ({ page }) => {
  await openBooted(page);
  await typeCode(page, "-- edited demo");
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
  expect(await page.evaluate(() => fesStorage.readRecoveryCopy())).not.toBeNull();

  await editor.press("Control+z");
  await expect(editor).toHaveText("-- original");
  expect(await page.evaluate(() => fesStorage.readRecoveryCopy())).toBeNull();
});

test("a copy from an older FES restores its code over the saved cart's art", async ({ page }) => {
  await openBooted(page);
  await saveAs(page, "Mine");
  const savedSprites = "1".repeat(128) + "\n" + ("0".repeat(128) + "\n").repeat(127);
  await page.evaluate(async (savedSprites) => {
    const [folder] = await fesStorage.listCartFolders();
    await fesStorage.writeCartFile(folder, "sprites.tiles", savedSprites);
    fesStorage.writeRecoveryCopy(JSON.stringify({ folder, name: "Mine", mainLua: "-- old" }));
  }, savedSprites);
  recordDialogs(page, "accept");

  await page.reload();
  await expect(page.locator("#cart-status")).toHaveText("Restored unsaved changes to Mine.");
  await expect(page.locator(".cm-content")).toHaveText("-- old");
  const rewritten = JSON.parse(await page.evaluate(() => fesStorage.readRecoveryCopy()));
  expect(rewritten.files["sprites.tiles"]).toBe(savedSprites);
});

test("a failed write removes the older copy and says so", async ({ page }) => {
  await page.addInitScript(() => {
    const setItem = Storage.prototype.setItem;
    Storage.prototype.setItem = function (key, value) {
      if (window.storageIsFull && key === "fes-unsaved-code") throw new DOMException("full", "QuotaExceededError");
      return setItem.call(this, key, value);
    };
  });
  await openBooted(page);
  await typeCode(page, "-- first");
  expect(await page.evaluate(() => fesStorage.readRecoveryCopy())).not.toBeNull();

  await page.evaluate(() => (window.storageIsFull = true));
  await typeCode(page, "-- second");
  await expect(page.locator("#cart-status")).toContainText("Can't keep a recovery copy");
  expect(await page.evaluate(() => fesStorage.readRecoveryCopy())).toBeNull();
});

ephemeralTest("a restore without saving still says why Save is unavailable", async ({ page }) => {
  await openBooted(page);
  await typeCode(page, "-- edited demo");
  recordDialogs(page, "accept");

  await page.reload();
  await expect(page.locator(".cm-content")).toHaveText("-- edited demo");
  await expect(page.locator("#cart-status")).toHaveText("Saving is unavailable (Private Browsing?)");
});
