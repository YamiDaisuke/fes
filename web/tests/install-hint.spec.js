import { test, expect } from "@playwright/test";

test("Not now moves focus to Run and keeps the install hint hidden after a reload", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator("#install-hint")).toBeVisible();

  await page.getByRole("button", { name: "Not now" }).click();
  await expect(page.locator("#install-hint")).toBeHidden();
  await expect(page.locator("#run")).toBeFocused();

  await page.reload();
  await expect(page.locator("#screen")).toHaveJSProperty("width", 192);
  await expect(page.locator("#install-hint")).toBeHidden();
});

test("the install hint comes back once 7 days have passed since Not now", async ({ page }) => {
  await page.addInitScript(() => {
    localStorage.setItem("fes-install-hint-dismissed", String(Date.now() - 7 * 24 * 60 * 60 * 1000 - 1000));
  });
  await page.goto("/");
  await expect(page.locator("#install-hint")).toBeVisible();
});

for (const [name, storedValue] of [
  ["in the future", () => String(Date.now() + 24 * 60 * 60 * 1000)],
  ["Infinity", () => "Infinity"],
]) {
  test(`the install hint shows when the stored dismissal time is ${name}`, async ({ page }) => {
    await page.addInitScript(
      ([key, value]) => localStorage.setItem(key, value),
      ["fes-install-hint-dismissed", storedValue()],
    );
    await page.goto("/");
    await expect(page.locator("#install-hint")).toBeVisible();
  });
}
