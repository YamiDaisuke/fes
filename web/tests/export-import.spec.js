import { test, expect } from "./persistent-context.js";

const cartFileNames = ["cart.json", "main.lua", "palettes.pal", "background.tiles", "sprites.tiles", "map.map"];

async function openBooted(page) {
  await page.goto("/");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  await page.getByRole("button", { name: "Code" }).click();
}

function savedFolders(page) {
  return page.evaluate(() => fesStorage.listCartFolders());
}

test("an exported cart imports as a new cart with identical files", async ({ page }, testInfo) => {
  await page.addInitScript(() => {
    window.testCartMainLua = 'x = "ä\0b"\nfunction frame() end\n';
  });
  await openBooted(page);
  await page.locator("#cart-name").fill("Ünï:a/b");
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect(page.locator("#cart-status")).toHaveText("Saved Ünï:a/b.");

  const downloading = page.waitForEvent("download");
  await page.getByRole("button", { name: "Export" }).click();
  const download = await downloading;
  expect(download.suggestedFilename()).toBe("Ünï-a-b.fes");
  await expect(page.locator("#cart-status")).toHaveText("Exported Ünï-a-b.fes.");
  const exported = testInfo.outputPath("exported.fes");
  await download.saveAs(exported);

  await page.locator("#cart-import-file").setInputFiles(exported);
  await expect(page.locator("#cart-status")).toHaveText("Imported Ünï:a/b as a new cart.");
  await expect(page.locator("#cart-list").getByRole("button", { name: "Ünï:a/b" })).toHaveCount(2);

  const [original, imported] = await page.evaluate(async (fileNames) => {
    const folders = await fesStorage.listCartFolders();
    return Promise.all(folders.map((folder) => Promise.all(fileNames.map((name) => fesStorage.readCartFile(folder, name)))));
  }, cartFileNames);
  expect(imported).toEqual(original);
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

test("a cart whose archive would be over 8 MiB is not exported", async ({ page }) => {
  await page.addInitScript(() => {
    window.testCartMainLua = "--" + "x".repeat(8 << 20);
  });
  let downloads = 0;
  page.on("download", () => downloads++);
  await openBooted(page);
  await page.getByRole("button", { name: "Export" }).click();
  await expect(page.locator("#cart-status")).toHaveText("Can't export: the cart is larger than 8 MiB, so it couldn't be imported");
  expect(downloads).toBe(0);
});
