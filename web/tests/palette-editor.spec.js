import { test as ephemeralTest, expect } from "@playwright/test";
import { test } from "./persistent-context.js";

async function openArtView(page) {
  await page.goto("/");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  await page.locator("#show-art").click();
}

const button = (page, name) => page.getByRole("button", { name, exact: true });
const sheetPixels = (page) => page.evaluate(() => document.getElementById("art-sheet").toDataURL());

test.describe("with a cart that draws sprite tile 2", () => {
  test.beforeEach(async ({ page }) => {
    await page.addInitScript(() => {
      window.testCartMainLua = "function _draw() cls() spr(2, 0, 0) end";
    });
  });

  test("a main color assigned to a sprite entry shows in Run, and is still there after Save and a reload", async ({ page }) => {
    await openArtView(page);
    await button(page, "Sprites").click();
    await page.locator("#art-tile").fill("2");
    await button(page, "Color 3").click();
    await button(page, "Paint pixel").click();

    await button(page, "Palettes").click();
    await page.getByRole("button", { name: /^Sprite palette 0, color 3:/ }).click();
    await button(page, "Main color 42, #49b893").click();
    await button(page, "Run").click();
    await expect
      .poll(() => page.evaluate(() => document.getElementById("screen").getContext("2d").getImageData(0, 0, 1, 1).data.join()))
      .toBe("73,184,147,255");

    await button(page, "Code").click();
    await page.locator("#cart-name").fill("Recolored");
    await button(page, "Save").click();
    await expect(page.locator("#cart-status")).toHaveText("Saved Recolored.");
    await page.reload();
    await page.locator("#cart-list").getByRole("button", { name: "Recolored", includeHidden: true }).dispatchEvent("click");
    await expect(page.locator("#cart-status")).toHaveText("Loaded Recolored.");
    await page.locator("#show-art").click();
    await button(page, "Sprites").click();
    await button(page, "Palettes").click();
    await expect(button(page, "Sprite palette 0, color 3: main color 42, #49b893")).toBeVisible();
  });
});

ephemeralTest("choosing an entry selects its palette and color, and a main color recolors the sheet and keeps a recovery copy", async ({ page }) => {
  await openArtView(page);
  const editWidth = await page.evaluate(() => document.getElementById("art-edit").width);
  const readCopy = () => page.evaluate(() => fesStorage.readRecoveryCopy());
  await button(page, "Palettes").click();

  await page.getByRole("button", { name: /^Background palette 2, color 5:/ }).click();
  await expect(button(page, "Palette 2")).toHaveAttribute("aria-pressed", "true");
  await expect(button(page, "Color 5")).toHaveAttribute("aria-pressed", "true");
  const sheetBefore = await sheetPixels(page);
  expect(await readCopy()).toBeNull();

  await button(page, "Main color 42, #49b893").click();
  await expect(button(page, "Main color 42, #49b893")).toHaveAttribute("aria-pressed", "true");
  await expect(button(page, "Background palette 2, color 5: main color 42, #49b893")).toHaveAttribute("aria-pressed", "true");
  expect(await sheetPixels(page)).not.toBe(sheetBefore);
  const palettes = JSON.parse(await readCopy()).files["palettes.pal"].split("\n");
  expect(palettes[2].split(" ")[5]).toBe("2a");

  await button(page, "Palettes").click();
  await expect.poll(() => page.evaluate(() => document.getElementById("art-edit").width)).toBe(editWidth);
});

ephemeralTest("sprite color 0 disables the main colors until a bank with a real color 0 is shown", async ({ page }) => {
  await openArtView(page);
  await button(page, "Palettes").click();
  const mainColor = button(page, "Main color 42, #49b893");
  await expect(mainColor).toBeEnabled();

  await button(page, "Sprites").click();
  await button(page, "Sprite palette 0, color 0: transparent").click();
  await expect(mainColor).toBeDisabled();
  await expect(page.locator("#art-main-hint")).toHaveText("Sprite color 0 is always transparent.");

  await button(page, "Background").click();
  await expect(mainColor).toBeEnabled();
});
