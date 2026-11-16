import { expect } from "@playwright/test";

export async function openShelf(page) {
  await expect(page.locator("#shelf-list").getByRole("button", { name: "Built-in demo", includeHidden: true })).toBeAttached();
  await page.getByRole("button", { name: "Carts" }).click();
}

export function savedCartEntries(page) {
  return page.locator('#shelf-list button:not([data-folder=""])');
}

export async function selectOnShelf(page, name) {
  await page.locator("#shelf-list").getByRole("button", { name, exact: true }).click();
}

export async function loadCartFromShelf(page, name) {
  await openShelf(page);
  await selectOnShelf(page, name);
  await page.getByRole("button", { name: "Edit", exact: true }).click();
}

export async function playOnShelf(page, name) {
  await selectOnShelf(page, name);
  await page.getByRole("button", { name: "Play", exact: true }).click();
  await expect(page.locator("body")).toHaveAttribute("data-view", "game");
}
