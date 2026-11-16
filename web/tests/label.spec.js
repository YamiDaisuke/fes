import { test, expect } from "./persistent-context.js";

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
