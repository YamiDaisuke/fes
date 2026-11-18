import { test, expect } from "@playwright/test";
import { typeCode } from "./code-editor.js";

async function openApp(page) {
  await page.goto("/");
  await expect(page.locator("#shelf-list").getByRole("button", { name: "Built-in demo" })).toBeVisible();
}

const manual = (page) => page.frameLocator("#help-frame");

test("the manual loads only on the first visit to Help, and Help focuses it", async ({ page }) => {
  await openApp(page);
  await expect(page.locator("#help-frame")).not.toHaveAttribute("src");

  await page.getByRole("button", { name: "Help" }).click();

  await expect(page.locator("body")).toHaveAttribute("data-view", "help");
  await expect(manual(page).getByRole("heading", { level: 1, name: "FES manual" })).toBeVisible();
  expect(await page.evaluate(() => document.activeElement.id)).toBe("help-frame");
});

test("switching Help → Code → Help keeps the code and the manual's scroll position", async ({ page }) => {
  await openApp(page);
  await page.getByRole("button", { name: "Code" }).click();
  await typeCode(page, "-- kept");
  await page.getByRole("button", { name: "Help" }).click();
  const body = manual(page).locator("body");
  await expect(body.locator("#buttons")).toBeVisible();
  const scrolled = await body.evaluate(() => {
    scrollTo(0, document.getElementById("buttons").offsetTop);
    return scrollY;
  });
  expect(scrolled).toBeGreaterThan(0);

  await page.getByRole("button", { name: "Code" }).click();
  await expect(page.locator(".cm-line")).toHaveText(["-- kept"]);
  await page.getByRole("button", { name: "Help" }).click();

  expect(await body.evaluate(() => scrollY)).toBe(scrolled);
});

test("every in-page link in the manual points at an id that exists", async ({ page }) => {
  await page.goto("/manual/");
  const broken = await page.evaluate(() =>
    [...document.querySelectorAll('a[href^="#"]')]
      .map((link) => link.getAttribute("href"))
      .filter((href) => document.querySelectorAll(`[id="${CSS.escape(href.slice(1))}"]`).length !== 1),
  );
  expect(broken).toEqual([]);
});

test("the Back to FES link shows only when the manual is opened on its own", async ({ page }) => {
  await page.goto("/manual/");
  const back = page.getByRole("link", { name: "Back to FES" });
  await expect(back).toBeVisible();
  expect(await back.evaluate((link) => link.href)).toBe(new URL("/", page.url()).href);

  await openApp(page);
  await page.getByRole("button", { name: "Help" }).click();
  await expect(manual(page).locator("#contents")).toHaveJSProperty("open", true);
  await expect(manual(page).locator("#back-to-fes")).toBeHidden();
});

test("the contents are open beside the text in landscape and closed above it in portrait", async ({ page }) => {
  const layout = () => page.evaluate(() => {
    const nav = document.querySelector("nav").getBoundingClientRect();
    const main = document.querySelector("main").getBoundingClientRect();
    return { open: document.getElementById("contents").open, beside: nav.right <= main.left, above: nav.bottom <= main.top };
  });

  await page.goto("/manual/");
  expect(await layout()).toEqual({ open: true, beside: true, above: false });

  await page.setViewportSize({ width: 834, height: 1194 });
  await page.goto("/manual/");
  expect(await layout()).toEqual({ open: false, beside: false, above: true });
});
