import { test as ephemeralTest } from "@playwright/test";
import { test, expect } from "./persistent-context.js";

async function openBooted(page) {
  await page.goto("/");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
}

test("a saved cart's code runs when it is loaded on another page", async ({ context, page }) => {
  await page.addInitScript(() => {
    window.testCartMainLua = 'error("from saved cart")';
  });
  await openBooted(page);
  await page.locator("#cart-name").fill("Saved");
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Saved.");
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-list button")).toHaveCount(1);

  const secondPage = await context.newPage();
  await openBooted(secondPage);
  await expect(secondPage.locator("#cart-error")).toBeEmpty();
  await secondPage.locator("#cart-list").getByRole("button", { name: "Saved" }).click();
  await expect(secondPage.locator("#cart-error")).toContainText("main.lua:1: from saved cart");
  await expect(secondPage.locator("#cart-name")).toHaveValue("Saved");
});

test("Enter on the focused Save button saves instead of pressing Start", async ({ page }) => {
  await page.addInitScript(() => {
    window.testCartMainLua = 'function _update() if btnp(6) then error("Start pressed") end end';
  });
  await openBooted(page);
  await page.getByRole("button", { name: "Save", exact: true }).focus();
  await page.keyboard.press("Enter");
  await expect(page.locator("#cart-status")).toHaveText("Saved Demo.");
  await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  await expect(page.locator("#cart-error")).toBeEmpty();
});

test("a cart whose cart.json can't be read is listed as damaged, and choosing it names the file", async ({ page }) => {
  await openBooted(page);
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Demo.");
  await page.evaluate(async () => {
    const [folder] = await fesStorage.listCartFolders();
    await fesStorage.writeCartFile(folder, "cart.json", "{");
  });
  await page.reload();

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
  await page.locator("#cart-name").fill("Room");
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Room.");
  await page.evaluate(async () => {
    const [folder] = await fesStorage.listCartFolders();
    const map = await fesStorage.readCartFile(folder, "map.map");
    await fesStorage.writeCartFile(folder, "map.map", map.split("\n").slice(0, 31).join("\n") + "\n");
  });
  await page.locator("#cart-name").fill("Renamed but unsaved");

  await page.locator("#cart-list").getByRole("button", { name: "Room" }).click();
  await expect(page.locator("#cart-status")).toHaveText("Can't load: map.map line 32: expected 32 lines, found 31");
  await expect(page.locator("#cart-name")).toHaveValue("Renamed but unsaved");
  await expect(page.locator("#cart-error")).toBeEmpty();
});

ephemeralTest("without OPFS saving is unavailable and the console still boots cleanly", async ({ page }) => {
  const errors = [];
  page.on("console", (message) => {
    if (message.type() === "error") errors.push(message.text());
  });
  page.on("pageerror", (error) => errors.push(error.message));

  await page.goto("/");

  await expect(page.locator("#cart-status")).toHaveText("Saving is unavailable (Private Browsing?)");
  await expect(page.getByRole("button", { name: "Save", exact: true })).toBeDisabled();
  await expect
    .poll(() =>
      page.evaluate(() => {
        const canvas = document.getElementById("screen");
        return canvas.getContext("2d").getImageData(canvas.width / 2, canvas.height / 2, 1, 1).data[3];
      }),
    )
    .toBe(255);
  expect(errors).toEqual([]);
});
