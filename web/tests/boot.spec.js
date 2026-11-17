import { test, expect } from "@playwright/test";

async function holdWasm(page) {
  let release;
  const released = new Promise((resolve) => (release = resolve));
  await page.route("**/App.wasm", async (route) => {
    await released;
    await route.continue();
  });
  return release;
}

test("the manifest's background and theme colours and the theme-color meta equal the --shell token", async ({ page }) => {
  await page.goto("/");
  const shell = await page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue("--shell").trim().toLowerCase());
  const manifest = await (await page.request.get("/manifest.webmanifest")).json();

  expect(manifest.background_color.toLowerCase()).toBe(shell);
  expect(manifest.theme_color.toLowerCase()).toBe(shell);
  await expect(page.locator('meta[name="theme-color"]')).toHaveAttribute("content", shell);
});

test("while App.wasm loads the preview screen shows the boot logo, and it is gone within 1 second of the shelf listing the demo", async ({ page }) => {
  const releaseWasm = await holdWasm(page);
  await page.goto("/");

  await expect(page.locator("#boot-logo")).toBeVisible();
  releaseWasm();
  await expect(page.locator("#shelf-list").getByRole("button", { name: "Built-in demo" })).toBeVisible();

  await expect(page.locator("body")).not.toHaveAttribute("data-booting", { timeout: 1000 });
  await expect(page.locator("#boot-logo")).toBeHidden();
});

test("under reduced motion the boot shows no logo and the power LED does not blink", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  const releaseWasm = await holdWasm(page);
  await page.goto("/");

  await expect(page.locator("#boot-logo")).toBeHidden();
  expect(await page.locator("#toolbar .power-led").evaluate((led) => led.getAnimations().length)).toBe(0);
  releaseWasm();
});
