import { test, expect } from "./persistent-context.js";
import { loadCodeFiles, typeCode } from "./code-editor.js";
import { openShelf, savedCartEntries, selectOnShelf } from "./shelf.js";

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    window.testCartMainLua = "-- boot";
  });
});

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

function answerNextDialog(page, answer) {
  const questions = [];
  page.once("dialog", (dialog) => {
    questions.push(dialog.message());
    answer === "accept" ? dialog.accept() : dialog.dismiss();
  });
  return questions;
}

function button(page, name) {
  return page.getByRole("button", { name, exact: true });
}

function cartFiles(page) {
  return page.evaluate(async () => {
    const carts = {};
    for (const folder of await fesStorage.listCartFolders()) {
      const files = {};
      for (const name of (await fesStorage.listCartFiles(folder)).sort()) {
        files[name] = await fesStorage.readCartFile(folder, name);
      }
      carts[folder] = files;
    }
    return carts;
  });
}

test("New cart asks before discarding unsaved changes, opens the template in the Code view, and saves as a new cart", async ({ page }) => {
  await openBooted(page);
  await typeCode(page, "-- edited");

  await openShelf(page);
  const questions = answerNextDialog(page, "accept");
  await button(page, "New cart").click();
  await expect(page.locator("#cart-status")).toHaveText("Opened a new cart.");
  expect(questions).toEqual(["Discard unsaved changes to Demo?"]);
  await expect(page.locator("body")).toHaveAttribute("data-view", "code");
  await expect(page.locator("#cart-name")).toHaveValue("New cart");
  await expect(page.locator(".cm-content")).toContainText("function _draw()");

  await typeCode(page, "-- typed");
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved New cart.");
  await expect(savedCartEntries(page)).toHaveText(["New cart"]);
});

test("Duplicate copies every file of the saved cart into a new folder, not the open cart's unsaved edits", async ({ page }) => {
  await openBooted(page);
  await loadCodeFiles(page, { "main.lua": "-- main", "player.lua": "return {}" });
  await typeCode(page, "-- unsaved");

  await openShelf(page);
  await selectOnShelf(page, "Two files");
  await button(page, "Duplicate").click();
  await expect(page.locator("#cart-status")).toHaveText("Duplicated Two files as Two files copy.");
  await expect(page.locator("#shelf-list").getByRole("button", { name: "Two files copy" })).toHaveAttribute("aria-pressed", "true");

  const carts = Object.values(await cartFiles(page));
  const original = carts.find((files) => files["cart.json"].includes('"Two files"'));
  const copy = carts.find((files) => files["cart.json"].includes('"Two files copy"'));
  expect(Object.keys(copy)).toEqual(Object.keys(original));
  for (const name of Object.keys(original).filter((name) => name !== "cart.json")) {
    expect(copy[name]).toBe(original[name]);
  }
  expect(copy["main.lua"]).toBe("-- main");
  expect(copy["player.lua"]).toBe("return {}");
});

test("Delete removes only the confirmed cart", async ({ page }) => {
  await openBooted(page);
  await saveAs(page, "Kept");
  await openShelf(page);
  await button(page, "New cart").click();
  await saveAs(page, "Gone");
  await page.reload();

  await openShelf(page);
  await selectOnShelf(page, "Gone");
  const cancelled = answerNextDialog(page, "dismiss");
  await button(page, "Delete").click();
  await expect.poll(() => cancelled).toEqual(["Delete Gone? This can't be undone. Export it first if you want a backup."]);
  await expect(savedCartEntries(page)).toHaveText(["Gone", "Kept"]);
  await expect(button(page, "Delete")).toBeFocused();

  answerNextDialog(page, "accept");
  await button(page, "Delete").click();
  await expect(page.locator("#cart-status")).toHaveText("Deleted Gone.");
  await expect(savedCartEntries(page)).toHaveText(["Kept"]);
  expect(await page.evaluate(() => fesStorage.listCartFolders())).toHaveLength(1);
  await expect(page.locator("#shelf-list").getByRole("button", { name: "Built-in demo" })).toBeFocused();
  await expect(button(page, "Delete")).toBeDisabled();

  await page.reload();
  await expect(savedCartEntries(page)).toHaveText(["Kept"]);
});

test("a double-tapped Delete asks once and removes only the selected cart", async ({ page }) => {
  await openBooted(page);
  await saveAs(page, "Kept");
  await openShelf(page);
  await button(page, "New cart").click();
  await saveAs(page, "Gone");

  await openShelf(page);
  await selectOnShelf(page, "Gone");
  const questions = [];
  page.on("dialog", (dialog) => {
    questions.push(dialog.message());
    dialog.accept();
  });
  await page.evaluate(() => {
    document.getElementById("shelf-delete").click();
    document.getElementById("shelf-delete").click();
  });
  await expect(page.locator("#cart-status")).toHaveText("Deleted Gone.");
  await expect(savedCartEntries(page)).toHaveText(["Kept"]);
  await page.getByRole("button", { name: "Code" }).click();
  await button(page, "Save").click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Demo.");
  expect(questions).toEqual(["Delete Gone? This can't be undone. Export it first if you want a backup."]);
  await expect(savedCartEntries(page)).toHaveText(["Demo", "Kept"]);
});

test("deleting the open cart with unsaved edits warns about them, opens the demo and keeps no recovery copy", async ({ page }) => {
  await openBooted(page);
  await saveAs(page, "Mine");
  await typeCode(page, "-- unsaved");

  await openShelf(page);
  await selectOnShelf(page, "Mine");
  const questions = answerNextDialog(page, "accept");
  await button(page, "Delete").click();
  await expect(page.locator("#cart-status")).toHaveText("Deleted Mine.");
  expect(questions).toEqual([
    "Delete Mine and your unsaved changes to it? This can't be undone. Export it first if you want a backup.",
  ]);
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  expect(await page.evaluate(() => fesStorage.readRecoveryCopy())).toBeNull();
});

test("a failed delete keeps the open cart and its folder, so Save rewrites it", async ({ page }) => {
  await page.addInitScript(() => {
    const removeEntry = FileSystemDirectoryHandle.prototype.removeEntry;
    FileSystemDirectoryHandle.prototype.removeEntry = function (name, options) {
      if (options?.recursive) return Promise.reject(new DOMException("refused by the test", "NoModificationAllowedError"));
      return removeEntry.call(this, name, options);
    };
  });
  await openBooted(page);
  await saveAs(page, "Mine");

  await openShelf(page);
  await selectOnShelf(page, "Mine");
  answerNextDialog(page, "accept");
  await button(page, "Delete").click();
  await expect(page.locator("#cart-status")).toHaveText(/^Can't delete Mine: /);
  await expect(savedCartEntries(page)).toHaveText(["Mine"]);
  await expect(page.locator("#cart-name")).toHaveValue("Mine");

  await page.getByRole("button", { name: "Code" }).click();
  await button(page, "Save").click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Mine.");
  expect(await page.evaluate(() => fesStorage.listCartFolders())).toHaveLength(1);
});

test("a folder without cart.json is listed as damaged, offers only Delete, and can be deleted", async ({ page }) => {
  await openBooted(page);
  await page.evaluate(() => fesStorage.writeCartFile("0123456789abcdef", "main.lua", ""));
  await page.reload();

  await openShelf(page);
  await selectOnShelf(page, "Damaged cart");
  await expect(page.locator("#cart-status")).toHaveText(
    "This cart's cart.json is missing or can't be read, so it can only be deleted.",
  );
  for (const name of ["Play", "Edit", "Duplicate", "Export"]) {
    await expect(button(page, name)).toBeDisabled();
  }
  const questions = answerNextDialog(page, "accept");
  await button(page, "Delete").click();
  await expect(page.locator("#cart-status")).toHaveText("Deleted the damaged cart.");
  expect(questions).toEqual(["Delete the damaged cart? This can't be undone."]);
  expect(await page.evaluate(() => fesStorage.listCartFolders())).toEqual([]);
});

test("deleting the open cart's damaged folder warns about its unsaved changes", async ({ page }) => {
  await openBooted(page);
  await saveAs(page, "Mine");
  await typeCode(page, "-- unsaved");
  await openShelf(page);
  await selectOnShelf(page, "Mine");
  await button(page, "Duplicate").click();
  await expect(page.locator("#cart-status")).toHaveText("Duplicated Mine as Mine copy.");
  await page.evaluate(async () => {
    for (const folder of await fesStorage.listCartFolders()) {
      if ((await fesStorage.readCartFile(folder, "cart.json")).includes('"Mine"')) {
        await fesStorage.removeCartFile(folder, "cart.json");
      }
    }
  });
  await button(page, "Duplicate").click();
  await expect(savedCartEntries(page)).toHaveText(["Damaged cart", "Mine copy", "Mine copy copy"]);

  await selectOnShelf(page, "Damaged cart");
  const questions = answerNextDialog(page, "dismiss");
  await button(page, "Delete").click();
  await expect.poll(() => questions).toEqual([
    "Delete the damaged cart and your unsaved changes to Mine? This can't be undone.",
  ]);
});
