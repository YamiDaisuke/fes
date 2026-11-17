import { test, expect } from "./persistent-context.js";
import { typeCode } from "./code-editor.js";
import { storedZip } from "./stored-zip.js";
import { loadCartFromShelf, openShelf, savedCartTitles, selectOnShelf } from "./shelf.js";

const cartFileNames = ["cart.json", "main.lua", "palettes.pal", "background.tiles", "sprites.tiles", "main-palette.hex", "map.map"];

async function openBooted(page) {
  await page.goto("/");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  await page.getByRole("button", { name: "Code" }).click();
}

function savedFolders(page) {
  return page.evaluate(() => fesStorage.listCartFolders());
}

test("an exported cart imports as a new cart with identical files, leaving the open cart alone", async ({ page }, testInfo) => {
  await page.addInitScript(() => {
    window.testCartMainLua = 'x = "ä\0b"\nfunction frame() end\n';
  });
  await openBooted(page);
  await page.locator("#cart-name").fill("Ünï:a/b");
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Ünï:a/b.");

  const downloading = page.waitForEvent("download");
  await openShelf(page);
  await selectOnShelf(page, "Ünï:a/b");
  await page.getByRole("button", { name: "Export" }).click();
  const download = await downloading;
  expect(download.suggestedFilename()).toBe("Ünï-a-b.fes");
  await expect(page.locator("#cart-status")).toHaveText("Exported Ünï-a-b.fes.");
  const exported = testInfo.outputPath("exported.fes");
  await download.saveAs(exported);
  await page.getByRole("button", { name: "Code" }).click();
  await page.locator("#cart-name").fill("Unsaved");
  await typeCode(page, "-- unsaved");

  await page.locator("#cart-import-file").setInputFiles(exported);
  await expect(page.locator("#cart-status")).toHaveText("Imported Ünï:a/b as a new cart.");
  await expect(savedCartTitles(page)).toHaveText(["Ünï:a/b", "Ünï:a/b"]);

  const [original, imported] = await page.evaluate(async (fileNames) => {
    const folders = await fesStorage.listCartFolders();
    return Promise.all(folders.map((folder) => Promise.all(fileNames.map((name) => fesStorage.readCartFile(folder, name)))));
  }, cartFileNames);
  expect(imported).toEqual(original);

  await expect(page.locator("#cart-name")).toHaveValue("Unsaved");
  await expect(page.locator(".cm-line")).toHaveText(["-- unsaved"]);
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Unsaved.");
  expect(await savedFolders(page)).toHaveLength(2);
});

test("a cart with code files besides main.lua keeps every file through Import, Load, Save, reload, Load and Export", async ({ page }, testInfo) => {
  await openBooted(page);
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Demo.");
  const fixedFiles = await page.evaluate(async (fileNames) => {
    const [folder] = await fesStorage.listCartFolders();
    return Object.fromEntries(await Promise.all(fileNames.map(async (name) => [name, await fesStorage.readCartFile(folder, name)])));
  }, cartFileNames);
  const codeFiles = { "player.lua": 'local p = {name = "ä"}\nreturn p\n', "enemy.lua": "return {hp = 3}\n" };
  await page.locator("#cart-import-file").setInputFiles({
    name: "two.fes",
    mimeType: "application/zip",
    buffer: storedZip({ ...fixedFiles, "cart.json": '{"format": 3, "name": "Two files"}', ...codeFiles }),
  });
  await expect(page.locator("#cart-status")).toHaveText("Imported Two files as a new cart.");

  const loadTwoFiles = async () => {
    await loadCartFromShelf(page, "Two files");
    await expect(page.locator("#cart-status")).toHaveText("Loaded Two files.");
  };
  await loadTwoFiles();
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Two files.");
  await openBooted(page);
  await loadTwoFiles();
  const downloading = page.waitForEvent("download");
  await openShelf(page);
  await selectOnShelf(page, "Two files");
  await page.getByRole("button", { name: "Export" }).click();
  const exported = testInfo.outputPath("exported.fes");
  await (await downloading).saveAs(exported);
  await page.locator("#cart-import-file").setInputFiles(exported);
  await expect(page.locator("#cart-status")).toHaveText("Imported Two files as a new cart.");

  const folderFiles = await page.evaluate(async () => {
    const folders = await fesStorage.listCartFolders();
    return Promise.all(
      folders.map(async (folder) => {
        const names = (await fesStorage.listCartFiles(folder)).sort();
        return Object.fromEntries(await Promise.all(names.map(async (name) => [name, await fesStorage.readCartFile(folder, name)])));
      }),
    );
  });
  const withPlayer = folderFiles.filter((files) => "player.lua" in files);
  expect(withPlayer).toHaveLength(2);
  const [saved, reimported] = withPlayer;
  expect(reimported).toEqual(saved);
  expect(Object.keys(saved).sort()).toEqual([...cartFileNames, "enemy.lua", "player.lua"].sort());
  expect(saved["player.lua"]).toBe(codeFiles["player.lua"]);
  expect(saved["enemy.lua"]).toBe(codeFiles["enemy.lua"]);
});

test("importing a file that isn't a .fes reports why and saves nothing", async ({ page }) => {
  await openBooted(page);
  await page.locator("#cart-import-file").setInputFiles({ name: "picture.png", mimeType: "image/png", buffer: Buffer.from("PNG") });
  await expect(page.locator("#cart-status")).toHaveText("Can't import picture.png: not a .fes file");
  expect(await savedFolders(page)).toEqual([]);
});

test("a file over 8 MiB is refused without reading its bytes", async ({ page }) => {
  await page.addInitScript(() => {
    window.bytesRead = 0;
    const arrayBuffer = Blob.prototype.arrayBuffer;
    Blob.prototype.arrayBuffer = function () {
      window.bytesRead += this.size;
      return arrayBuffer.call(this);
    };
  });
  await openBooted(page);
  await page.locator("#cart-import-file").setInputFiles({ name: "big.fes", mimeType: "application/zip", buffer: Buffer.alloc((8 << 20) + 1) });
  await expect(page.locator("#cart-status")).toHaveText("Can't import big.fes: larger than 8 MiB");
  expect(await page.evaluate(() => window.bytesRead)).toBe(0);
});

test("a saved cart whose archive would be over 8 MiB is not exported", async ({ page }) => {
  await page.addInitScript(() => {
    window.testCartMainLua = "--" + "x".repeat(8 << 20);
  });
  let downloads = 0;
  page.on("download", () => downloads++);
  await openBooted(page);
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Demo.");
  await openShelf(page);
  await selectOnShelf(page, "Demo");
  await page.getByRole("button", { name: "Export" }).click();
  await expect(page.locator("#cart-status")).toHaveText("Can't export: the cart is larger than 8 MiB, so it couldn't be imported");
  expect(downloads).toBe(0);
});
