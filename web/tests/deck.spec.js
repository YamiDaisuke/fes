import { test, expect } from "@playwright/test";
import { openPaused, runFrames } from "./frames.js";
import { pixelColors, rgb } from "./pixels.js";

const erroringOnThirdFrame = `frames = 0
function _update()
  frames = frames + 1
  if frames == 3 then error("third frame", 0) end
end`;

async function openApp(page) {
  await page.goto("/");
  await expect(page.locator("#shelf-list").getByRole("button", { name: "Built-in demo" })).toBeVisible();
}

async function openWithErroringCart(page) {
  await page.addInitScript((mainLua) => {
    window.testCartMainLua = mainLua;
  }, erroringOnThirdFrame);
  await openPaused(page);
}

test("each view switch shows its view and is the only pressed switch", async ({ page }) => {
  await openApp(page);
  const switches = page.getByRole("group", { name: "View", exact: true });

  for (const [name, view] of [["Code", "code"], ["Art", "art"], ["Game", "game"], ["Carts", "shelf"]]) {
    await switches.getByRole("button", { name, exact: true }).click();
    await expect(page.locator("body")).toHaveAttribute("data-view", view);
    await expect(switches.getByRole("button", { pressed: true })).toHaveCount(1);
    await expect(switches.getByRole("button", { pressed: true })).toHaveText(name);
  }
});

test("the Game switch resumes the running cart without restarting it, and an error turns the power LED red", async ({ page }) => {
  await openWithErroringCart(page);

  await runFrames(page, 2);
  await page.getByRole("button", { name: "Code" }).click();
  await page.getByRole("button", { name: "Game" }).click();
  await runFrames(page, 1);

  await expect(page.locator("#cart-error")).toContainText("third frame");
  await expect(page.locator("body")).toHaveAttribute("data-led", "error");
});

test("after another cart is opened, the Game switch runs that cart instead of resuming the old one", async ({ page }) => {
  await openWithErroringCart(page);
  await runFrames(page, 3);
  await expect(page.locator("#cart-error")).toContainText("third frame");

  await page.getByRole("button", { name: "Carts" }).click();
  await page.getByRole("button", { name: "New cart" }).click();
  await expect(page.locator("body")).toHaveAttribute("data-view", "code");
  await page.getByRole("button", { name: "Game" }).click();

  await expect(page.locator("#cart-error")).toBeEmpty();
  await expect(page.locator("body")).toHaveAttribute("data-led", "on");
});

test("the power LED is off on the shelf and on in the game", async ({ page }) => {
  await openApp(page);
  const body = page.locator("body");
  await expect(body).toHaveAttribute("data-led", "off");

  await page.getByRole("button", { name: "Game" }).click();
  await expect(body).toHaveAttribute("data-led", "on");

  await page.getByRole("button", { name: "Carts" }).click();
  await expect(body).toHaveAttribute("data-led", "off");
});

const deckLayouts = [
  { width: 1194, height: 834, readoutBesideKeys: true },
  { width: 1133, height: 744, readoutBesideKeys: true },
  { width: 834, height: 1194, readoutBesideKeys: false },
  { width: 744, height: 1133, readoutBesideKeys: false },
  { width: 678, height: 1024, readoutBesideKeys: false },
];

for (const { readoutBesideKeys, ...viewport } of deckLayouts) {
  test(`at ${viewport.width}×${viewport.height} the deck's keys are one row that fits, with the readout ${readoutBesideKeys ? "beside them" : "under them"}, keys of at least 44 px and everything on whole pixels`, async ({ page }) => {
    await page.setViewportSize(viewport);
    await openApp(page);
    await page.getByRole("button", { name: "Game" }).click();
    const readout = page.locator("#cart-status");
    await readout.evaluate((status) => { status.textContent = "short"; });
    const shortHeight = (await readout.boundingBox()).height;
    await readout.evaluate((status) => { status.textContent = "A long status message. ".repeat(14); });

    const deck = await page.locator("#toolbar").evaluate((toolbar) => {
      const box = (element) => {
        const { x, y, width, height } = element.getBoundingClientRect();
        return { name: element.id, x, y, width, height };
      };
      return {
        buttons: [...toolbar.querySelectorAll("button")].filter((button) => button.checkVisibility()).map(box),
        readout: box(toolbar.querySelector("#cart-status")),
        overflow: toolbar.scrollWidth - toolbar.clientWidth,
        right: toolbar.getBoundingClientRect().right,
        page: { width: document.documentElement.scrollWidth, height: document.documentElement.scrollHeight },
        window: { width: innerWidth, height: innerHeight },
      };
    });

    const carts = deck.buttons.find((button) => button.name === "show-shelf");
    expect(deck.buttons.map((button) => button.name)).toEqual(["show-shelf", "show-code", "show-art", "show-game", "run", "cart-save", "set-label"]);
    for (const button of deck.buttons) {
      expect(button.y < carts.y + carts.height && carts.y < button.y + button.height, `${button.name} shares the row`).toBe(true);
      expect(button.width, button.name).toBeGreaterThanOrEqual(44);
      expect(button.height, button.name).toBeGreaterThanOrEqual(44);
    }
    expect(deck.readout.y < carts.y + carts.height, "the readout shares the keys' row").toBe(readoutBesideKeys);
    expect(deck.overflow).toBeLessThanOrEqual(0);
    expect(deck.right).toBeLessThanOrEqual(deck.window.width);
    expect(deck.page.width).toBeLessThanOrEqual(deck.window.width);
    expect(deck.page.height).toBeLessThanOrEqual(deck.window.height);
    expect(deck.readout.height).toBe(shortHeight);
    for (const box of [...deck.buttons, deck.readout]) {
      for (const edge of ["x", "y", "width", "height"]) expect(Number.isInteger(box[edge]), `${box.name} ${edge} ${box[edge]}`).toBe(true);
    }
  });
}

for (const viewport of [{ width: 744, height: 1133 }, { width: 678, height: 1024 }]) {
  test(`at ${viewport.width}×${viewport.height} the readout shows the Set label message in full`, async ({ page }) => {
    await page.setViewportSize(viewport);
    await openApp(page);
    await page.getByRole("button", { name: "Game" }).click();
    await page.getByRole("button", { name: "Set label" }).click();
    const readout = page.locator("#cart-status");
    await expect(readout).toHaveText("Label set. Save to keep it.");

    const { textBottom, contentBottom } = await readout.evaluate((status) => {
      const text = document.createRange();
      text.selectNodeContents(status);
      const style = getComputedStyle(status);
      return {
        textBottom: text.getBoundingClientRect().bottom,
        contentBottom: status.getBoundingClientRect().bottom - parseFloat(style.borderBottomWidth) - parseFloat(style.paddingBottom),
      };
    });
    expect(textBottom).toBeLessThanOrEqual(contentBottom);
  });
}

test("at 600×834, the narrowest supported width, the game view's deck wraps instead of overflowing", async ({ page }) => {
  await page.setViewportSize({ width: 600, height: 834 });
  await openApp(page);
  await page.getByRole("button", { name: "Game" }).click();

  const overflow = await page.locator("#toolbar").evaluate((toolbar) => ({
    deck: toolbar.scrollWidth - toolbar.clientWidth,
    page: document.documentElement.scrollWidth - innerWidth,
  }));
  expect(overflow).toEqual({ deck: 0, page: 0 });
});

for (const name of ["Carts", "Run", "Not now"]) {
  test(`a focused ${name} key is framed in ink on all four sides, outside its butter ring`, async ({ page }) => {
    await openApp(page);
    const key = page.getByRole("button", { name, exact: true });
    for (let presses = 0; presses < 40 && !(await key.evaluate((element) => element === document.activeElement)); presses += 1) {
      await page.keyboard.press("Tab");
    }
    await expect(key).toBeFocused();
    const ink = rgb(await key.evaluate((element) => getComputedStyle(element).borderTopColor)).join();

    const { x, y, width, height } = await key.boundingBox();
    const frameSides = [
      { x, y: y - 4, width, height: 2 },
      { x, y: y + height + 2, width, height: 2 },
      { x: x - 4, y, width: 2, height },
      { x: x + width + 2, y, width: 2, height },
    ];
    for (const clip of frameSides) {
      expect(new Set(await pixelColors(page, await page.screenshot({ clip })))).toEqual(new Set([ink]));
    }
  });
}
