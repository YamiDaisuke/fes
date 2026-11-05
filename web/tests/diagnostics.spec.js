import { test as ephemeralTest, expect } from "@playwright/test";
import { test } from "./persistent-context.js";

async function openCodeView(page) {
  await page.goto("/");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  await page.getByRole("button", { name: "Code" }).click();
}

const line = (page, number) => page.locator(".cm-line").nth(number - 1);

ephemeralTest("a syntax error appears on its line after typing", async ({ page }) => {
  await openCodeView(page);
  await page.locator(".cm-content").fill("x = 1\ny = 2\nx = = 1");
  await expect(line(page, 3).locator(".cm-lintRange-error")).toHaveCount(1);
  await expect(page.locator("#code-error")).toHaveText("main.lua:3: unexpected symbol near '='");
});

ephemeralTest("fixing the error clears the diagnostic", async ({ page }) => {
  await openCodeView(page);
  await page.locator(".cm-content").fill("x = = 1");
  await expect(page.locator("#code-error")).toContainText("main.lua:1:");
  await page.locator(".cm-content").fill("x = 1");
  await expect(page.locator("#code-error")).toBeEmpty();
  await expect(page.locator(".cm-lintRange-error")).toHaveCount(0);
});

ephemeralTest("Code after a runtime error puts the cursor on its line", async ({ page }) => {
  await page.addInitScript(() => {
    window.testCartMainLua = "x = 1\nfunction _update()\n  local y = 2\n  missing()\nend";
  });
  await page.goto("/");
  await expect(page.locator("#cart-error")).toContainText("main.lua:4:");
  await page.getByRole("button", { name: "Code" }).click();
  await expect(page.locator(".cm-activeLine")).toHaveText("  missing()");
  await expect(line(page, 4).locator(".cm-lintRange-error")).toHaveCount(1);
  await expect(page.locator("#code-error")).toContainText("main.lua:4: attempt to call a nil value (global 'missing')");
});

test("restored code with a syntax error shows it without typing", async ({ page }) => {
  await openCodeView(page);
  await page.evaluate(() => fesStorage.writeUnsavedCode(JSON.stringify({ name: "Demo", mainLua: "x = 1\ny = 2\nz = = 3" })));
  page.on("dialog", (dialog) => dialog.accept());

  await page.reload();
  await expect(page.locator("#code-error")).toHaveText("main.lua:3: unexpected symbol near '='");
  await expect(line(page, 3).locator(".cm-lintRange-error")).toHaveCount(1);
});

ephemeralTest("Code after a run without an error drops the previous run's error", async ({ page }) => {
  await page.addInitScript(() => {
    window.testCartMainLua = "x = 1\nfunction _update()\n  local y = 2\n  if btn(4) then error('pressed') end\nend";
  });
  await page.goto("/");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  await page.keyboard.down("KeyZ");
  await expect(page.locator("#cart-error")).toContainText("main.lua:4: pressed");
  await page.keyboard.up("KeyZ");
  await page.getByRole("button", { name: "Code" }).click();
  await expect(page.locator("#code-error")).toContainText("main.lua:4: pressed");

  await page.getByRole("button", { name: "Run" }).click();
  await page.getByRole("button", { name: "Code" }).click();
  await expect(page.locator("#code-error")).toBeEmpty();
  await expect(page.locator(".cm-lintRange-error")).toHaveCount(0);
});

ephemeralTest("a syntax check pending at Run doesn't clear the runtime error", async ({ page }) => {
  await openCodeView(page);
  await page.locator(".cm-content").fill("x = 1\nerror('quick')");
  await page.getByRole("button", { name: "Run" }).click();
  await page.getByRole("button", { name: "Code" }).click();
  await page.waitForTimeout(700);
  await expect(page.locator("#code-error")).toHaveText("main.lua:2: quick");
  await expect(line(page, 2).locator(".cm-lintRange-error")).toHaveCount(1);
});
