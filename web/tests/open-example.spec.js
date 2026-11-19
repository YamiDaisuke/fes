import { test, expect } from "./persistent-context.js";
import { openPaused, runFrames } from "./frames.js";
import { typeCode } from "./code-editor.js";
import { answerQuestion } from "./ask.js";
import { openShelf, savedCartTitles } from "./shelf.js";

const manual = (page) => page.frameLocator("#help-frame");

async function openApp(page) {
  await page.goto("/");
  await expect(page.locator("#shelf-list").getByRole("button", { name: "Built-in demo", includeHidden: true })).toBeAttached();
}

async function showHelp(page) {
  await page.getByRole("button", { name: "Help" }).click();
  await expect(manual(page).getByRole("button", { name: "Open Move a sprite in FES" })).toBeVisible();
}

async function openExample(page, heading) {
  await showHelp(page);
  await manual(page).getByRole("button", { name: `Open ${heading} in FES` }).click();
}

function exampleText(page, name, file) {
  const selector = file ? `pre[data-example="${name}"][data-file="${file}"]` : `pre[data-example="${name}"]`;
  return manual(page).locator(selector).first().textContent();
}

async function expectEditorText(page, text) {
  await expect(page.locator(".cm-line")).toHaveText(text.split("\n"));
}

function dispatchMessage(page, data, origin) {
  return page.evaluate(([data, origin]) => {
    window.dispatchEvent(new MessageEvent("message", { data, origin: origin ?? location.origin }));
  }, [data, origin]);
}

async function expectDemoStillInHelp(page) {
  await page.evaluate(() => new Promise((resolve) => setTimeout(resolve, 200)));
  await expect(page.locator("body")).toHaveAttribute("data-view", "help");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
}

test("opening Move a sprite shows its code in the Code view, and Run moves the sprite on input", async ({ page }) => {
  await openPaused(page);
  await openExample(page, "Move a sprite");

  await expect(page.locator("body")).toHaveAttribute("data-view", "code");
  await expect(page.locator("#cart-name")).toHaveValue("Move a sprite");
  await expect(page.locator("#cart-status")).toHaveText("Opened the example Move a sprite.");
  await expectEditorText(page, await exampleText(page, "move"));

  await page.getByRole("button", { name: "Run", exact: true }).click();
  await runFrames(page, 2);
  const before = await page.locator("#screen").screenshot();
  await page.keyboard.down("ArrowRight");
  await runFrames(page, 30);
  await page.keyboard.up("ArrowRight");
  const after = await page.locator("#screen").screenshot();

  expect(after.equals(before)).toBe(false);
  await expect(page.locator("#cart-error")).toHaveText("");
});

test("a two-file example opens with a tab for each file holding its text", async ({ page }) => {
  await openPaused(page);
  for (const [heading, name] of [["Two files", "two-files"], ["require", "api-require"]]) {
    await openExample(page, heading);
    await expect(page.getByRole("tab")).toHaveText(["main.lua", "player.lua"]);
    await expectEditorText(page, await exampleText(page, name));
    await page.getByRole("tab", { name: "player.lua" }).click();
    await expectEditorText(page, await exampleText(page, name, "player.lua"));
  }

  await page.getByRole("button", { name: "Run", exact: true }).click();
  await runFrames(page, 60);
  await expect(page.locator("#cart-error")).toHaveText("");
});

test("with unsaved edits the discard question comes first, and Cancel leaves the cart and Help as they were", async ({ page }) => {
  await openApp(page);
  await page.getByRole("button", { name: "Code" }).click();
  await typeCode(page, "-- my edit");

  await openExample(page, "Move a sprite");
  expect(await answerQuestion(page, "Cancel")).toBe("Discard unsaved changes to Demo?");

  await expect(page.locator("body")).toHaveAttribute("data-view", "help");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  await page.getByRole("button", { name: "Code" }).click();
  await expectEditorText(page, "-- my edit");

  await openExample(page, "Move a sprite");
  await answerQuestion(page, "Discard");
  await expect(page.locator("#cart-name")).toHaveValue("Move a sprite");
});

test("a message from another origin is ignored, and the same message from the Help frame opens the example", async ({ page }) => {
  await openApp(page);
  await showHelp(page);

  await dispatchMessage(page, { fesExample: "move" }, "https://example.com");
  await expectDemoStillInHelp(page);

  await dispatchMessage(page, { fesExample: "move" });
  await expect(page.locator("#cart-name")).toHaveValue("Move a sprite");
});

test("a message that isn't a known example name is ignored", async ({ page }) => {
  await openApp(page);
  await showHelp(page);

  for (const data of [{ fesExample: 5 }, { fesExample: "no-such-example" }, "move", null]) {
    await dispatchMessage(page, data);
  }

  await expectDemoStillInHelp(page);
  await expect(page.locator("#cart-error")).toHaveText("");
});

test("the manual has one Open in FES key per example inside Help and none on its own", async ({ page }) => {
  await page.goto("/manual/");
  await expect(page.getByRole("heading", { level: 1, name: "FES manual" })).toBeVisible();
  await expect(page.getByRole("button", { name: /in FES$/ })).toHaveCount(0);

  await openApp(page);
  await showHelp(page);
  const exampleNames = await manual(page).locator("pre[data-example]").evaluateAll((pres) => new Set(pres.map((pre) => pre.dataset.example)).size);
  const labels = await manual(page).getByRole("button", { name: /in FES$/ }).evaluateAll((keys) => keys.map((key) => key.getAttribute("aria-label")));
  expect(labels).toHaveLength(exampleNames);
  expect(new Set(labels).size).toBe(exampleNames);
});

test("saving an opened example makes a new cart and leaves the saved carts alone", async ({ page }) => {
  await openApp(page);
  await page.getByRole("button", { name: "Code" }).click();
  await page.locator("#cart-name").fill("Mine");
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Mine.");

  await openExample(page, "Move a sprite");
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Move a sprite.");

  await openShelf(page);
  await expect(savedCartTitles(page)).toHaveText(["Mine", "Move a sprite"]);
});
