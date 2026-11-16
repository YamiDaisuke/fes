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
  const gameCenter = await page.evaluate(() => [...document.getElementById("screen").getContext("2d").getImageData(96, 72, 1, 1).data]);
  await page.getByRole("button", { name: "Set label" }).click();
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Demo.");

  await openShelf(page);
  const labelCenter = () =>
    savedCartEntries(page)
      .locator("canvas")
      .evaluate((canvas) => [...canvas.getContext("2d").getImageData(96, 72, 1, 1).data]);
  await expect.poll(labelCenter).toEqual(gameCenter);
});

test("a malformed label leaves the entry named with a blank picture", async ({ page }) => {
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
  const center = await entry.locator("canvas").evaluate((canvas) => [...canvas.getContext("2d").getImageData(96, 72, 1, 1).data]);
  expect(center).toEqual([0, 0, 0, 0]);
  await selectOnShelf(page, "Demo");
  await page.getByRole("button", { name: "Play" }).click();
  await expect(page.locator("#cart-status")).toContainText("Can't load: label.hex");
});
