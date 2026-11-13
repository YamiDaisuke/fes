import { test as ephemeralTest, expect } from "@playwright/test";
import { test } from "./persistent-context.js";

async function openPalettes(page) {
  await page.goto("/");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  await page.locator("#show-art").click();
  await button(page, "Palettes").click();
}

const button = (page, name) => page.getByRole("button", { name, exact: true });
const picker = (page) => page.getByLabel("Edit main color", { exact: false });
const sheetPixels = (page) => page.evaluate(() => document.getElementById("art-sheet").toDataURL());
const readCopy = (page) => page.evaluate(() => fesStorage.readRecoveryCopy());

test("an edited main color recolors every entry using it, shows in Run, and is still there after Save and a reload", async ({ page }) => {
  await page.addInitScript(() => {
    window.testCartMainLua = "function _draw() cls() spr(2, 0, 0) end";
  });
  await page.goto("/");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  await page.locator("#show-art").click();
  await button(page, "Sprites").click();
  await page.locator("#art-tile").fill("2");
  await button(page, "Color 3").click();
  await button(page, "Paint pixel").click();
  await button(page, "Palettes").click();
  await page.getByRole("button", { name: /^Sprite palette 0, color 3:/ }).click();
  await expect(picker(page)).toHaveAccessibleName("Edit main color 3");
  await expect(picker(page)).toHaveValue("#c058cc");
  const sheetBefore = await sheetPixels(page);

  await picker(page).fill("#ff0000");
  await expect(button(page, "Sprite palette 0, color 3: main color 3, #ff0000")).toBeVisible();
  await expect(button(page, "Main color 3, #ff0000")).toBeVisible();
  expect(await sheetPixels(page)).not.toBe(sheetBefore);
  await button(page, "Background").click();
  await expect(button(page, "Background palette 0, color 3: main color 3, #ff0000")).toBeVisible();

  await button(page, "Run").click();
  await expect
    .poll(() => page.evaluate(() => document.getElementById("screen").getContext("2d").getImageData(0, 0, 1, 1).data.join()))
    .toBe("255,0,0,255");

  await button(page, "Code").click();
  await page.locator("#cart-name").fill("Red");
  await button(page, "Save").click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Red.");
  await page.reload();
  await page.locator("#cart-list").getByRole("button", { name: "Red", includeHidden: true }).dispatchEvent("click");
  await expect(page.locator("#cart-status")).toHaveText("Loaded Red.");
  await page.locator("#show-art").click();
  await button(page, "Palettes").click();
  await expect(button(page, "Main color 3, #ff0000")).toBeVisible();
});

ephemeralTest("an edited main color reaches the recovery copy after the picker settles", async ({ page }) => {
  await openPalettes(page);
  await page.getByRole("button", { name: /^Background palette 0, color 3:/ }).click();
  await picker(page).fill("#123456");
  await picker(page).fill("#ff0000");

  await expect.poll(() => readCopy(page)).not.toBeNull();
  const mainPalette = JSON.parse(await readCopy(page)).files["main-palette.hex"].split("\n");
  expect(mainPalette[3]).toBe("ff0000");
});

ephemeralTest("Reset asks first, then puts back Z64 and is disabled until a color changes again", async ({ page }) => {
  await openPalettes(page);
  const reset = button(page, "Reset main palette");
  await expect(reset).toBeDisabled();
  await page.getByRole("button", { name: /^Background palette 0, color 3:/ }).click();
  await picker(page).fill("#ff0000");
  await expect(reset).toBeEnabled();

  page.once("dialog", (dialog) => dialog.dismiss());
  await reset.click();
  await expect(button(page, "Main color 3, #ff0000")).toBeVisible();

  page.once("dialog", (dialog) => dialog.accept());
  await reset.click();
  await expect(button(page, "Main color 3, #c058cc")).toBeVisible();
  await expect(picker(page)).toHaveValue("#c058cc");
  await expect(reset).toBeDisabled();
});

ephemeralTest("sprite color 0 disables the main color picker", async ({ page }) => {
  await openPalettes(page);
  await button(page, "Sprites").click();
  await button(page, "Sprite palette 0, color 0: transparent").click();
  await expect(picker(page)).toBeDisabled();
  await expect(picker(page)).toHaveAccessibleName("Edit main color");
});
