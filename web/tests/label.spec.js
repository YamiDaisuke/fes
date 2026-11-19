import { test, expect } from "./persistent-context.js";
import { openShelf, savedCartEntries, selectOnShelf } from "./shelf.js";

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    window.testCartMainLua = "function _draw() cls() spr(1, 92, 68) end";
  });
});

test("Set label saves the frame on screen as main palette indices in label.hex", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  await page.getByRole("button", { name: "Set label" }).click();
  await expect(page.locator("#cart-status")).toHaveText("Label set. Save to keep it.");
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Demo.");

  const { screen, labelAsScreen } = await page.evaluate(async () => {
    const [folder] = await fesStorage.listCartFolders();
    const label = await fesStorage.readCartFile(folder, "label.hex");
    const mainPalette = (await fesStorage.readCartFile(folder, "main-palette.hex")).trimEnd().split("\n");
    const labelAsScreen = label
      .trimEnd()
      .split("\n")
      .flatMap((line) => line.match(/../g).map((pair) => mainPalette[parseInt(pair, 16)]));
    const rgba = document.getElementById("screen").getContext("2d").getImageData(0, 0, 192, 144).data;
    const screen = [];
    for (let offset = 0; offset < rgba.length; offset += 4) {
      screen.push([rgba[offset], rgba[offset + 1], rgba[offset + 2]].map((channel) => channel.toString(16).padStart(2, "0")).join(""));
    }
    return { screen, labelAsScreen };
  });
  expect(new Set(screen).size).toBeGreaterThan(1);
  expect(labelAsScreen).toEqual(screen);
});

test("a saved label shows on the shelf with the game's colors", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  const screenCenter = () => page.evaluate(() => [...document.getElementById("screen").getContext("2d").getImageData(96, 72, 1, 1).data]);
  await expect.poll(async () => (await screenCenter())[3]).not.toBe(0);
  const gameCenter = await screenCenter();
  await page.getByRole("button", { name: "Set label" }).click();
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Demo.");

  await openShelf(page);
  const labelCenter = () =>
    savedCartEntries(page)
      .locator("canvas")
      .evaluate((canvas) => [...canvas.getContext("2d").getImageData(96, 72, 1, 1).data]);
  await expect.poll(labelCenter).toEqual(gameCenter);

  await selectOnShelf(page, "Demo");
  const previewCenter = await page.locator("#shelf-preview-label").evaluate((canvas) => [...canvas.getContext("2d").getImageData(96, 72, 1, 1).data]);
  expect(previewCenter).toEqual(gameCenter);
});

test("a malformed label leaves the entry named, with its name in place of the picture", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Demo.");
  await page.evaluate(async () => {
    const [folder] = await fesStorage.listCartFolders();
    await fesStorage.writeCartFile(folder, "label.hex", "zz\n");
  });
  await page.reload();

  await openShelf(page);
  const entry = savedCartEntries(page);
  await expect(entry).toHaveAccessibleName("Demo");
  await expect(entry.locator("canvas")).toHaveCount(0);
  await expect(entry.locator(".cartridge-label")).toHaveText("Demo");
  await selectOnShelf(page, "Demo");
  await page.getByRole("button", { name: "Play" }).click();
  await expect(page.locator("#cart-status")).toContainText("Can't load: label.hex");
});

test("the demo's picture shows on the shelf when saved carts can't be listed", async ({ page }) => {
  await page.addInitScript(() => {
    StorageManager.prototype.getDirectory = () => Promise.reject(new Error("unavailable"));
  });
  await page.goto("/");
  await expect(page.locator("#cart-status")).toHaveText("Saving is unavailable (Private Browsing?)");

  await openShelf(page);
  const demoCenter = await page
    .locator("#shelf-list")
    .getByRole("button", { name: "Built-in demo" })
    .locator("canvas")
    .evaluate((canvas) => [...canvas.getContext("2d").getImageData(96, 72, 1, 1).data]);
  expect(demoCenter).not.toEqual([0, 0, 0, 0]);
  await expect(page.locator("#shelf-empty")).toBeHidden();
});
