import { expect } from "@playwright/test";
import { storedZip } from "./stored-zip.js";
import { loadCartFromShelf } from "./shelf.js";

export async function typeCode(page, code) {
  // WebKit's fill() on CodeMirror sometimes leaves an extra empty first line (T14 QA-6).
  await expect(async () => {
    await page.locator(".cm-content").fill(code);
    await expect(page.locator(".cm-line")).toHaveText(code.split("\n"), { timeout: 1000 });
  }).toPass();
}

export async function loadCodeFiles(page, codeFiles, name = "Two files") {
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText(/^Saved /);
  const savedFiles = await page.evaluate(async () => {
    const [folder] = await fesStorage.listCartFolders();
    const names = ["palettes.pal", "background.tiles", "sprites.tiles", "main-palette.hex", "map.map"];
    return Object.fromEntries(await Promise.all(names.map(async (name) => [name, await fesStorage.readCartFile(folder, name)])));
  });
  await page.locator("#cart-import-file").setInputFiles({
    name: "cart.fes",
    mimeType: "application/zip",
    buffer: storedZip({ ...savedFiles, "cart.json": `{"format": 3, "name": "${name}"}`, ...codeFiles }),
  });
  await loadCartFromShelf(page, name);
  await expect(page.locator("#cart-status")).toHaveText(`Loaded ${name}.`);
}
