import { test, expect, devices } from "@playwright/test";
import { typeCode } from "./code-editor.js";
import { contrastRatio } from "./contrast.js";
import { pixelColors, rgb } from "./pixels.js";

async function openCodeView(page) {
  await page.goto("/");
  await expect(page.locator("#cart-name")).toHaveValue("Demo");
  await page.getByRole("button", { name: "Code" }).click();
  await page.evaluate(() => document.fonts.ready);
}

const viewports = [
  { width: 1194, height: 834 },
  { width: 1133, height: 744 },
  { width: 834, height: 1194 },
  { width: 744, height: 1133 },
  { width: 600, height: 834 },
];

for (const viewport of viewports) {
  test(`code is Departure Mono at 22 px on 28 px lines, and every line starts on a whole pixel, at ${viewport.width}×${viewport.height}`, async ({ page }) => {
    await page.setViewportSize(viewport);
    await openCodeView(page);

    const layout = await page.evaluate(() => {
      const line = getComputedStyle(document.querySelector(".cm-line"));
      const codeView = document.getElementById("code-view");
      const page = document.documentElement;
      return {
        font: { family: line.fontFamily, size: line.fontSize, lineHeight: line.lineHeight },
        fontLoaded: document.fonts.check('22px "Departure Mono"'),
        lineStarts: [...document.querySelectorAll(".cm-line")].map((element) => {
          const box = element.getBoundingClientRect();
          return [box.x, box.y];
        }),
        overflow: {
          codeViewX: codeView.scrollWidth - codeView.clientWidth,
          pageX: page.scrollWidth - page.clientWidth,
          pageY: page.scrollHeight - page.clientHeight,
        },
      };
    });

    expect(layout.font.family).toMatch(/^"?Departure Mono"?,/);
    expect(layout.font.size).toBe("22px");
    expect(layout.font.lineHeight).toBe("28px");
    expect(layout.fontLoaded).toBe(true);
    expect(layout.lineStarts.length).toBeGreaterThan(0);
    for (const [x, y] of layout.lineStarts) {
      expect(Number.isInteger(x), `line x ${x}`).toBe(true);
      expect(Number.isInteger(y), `line y ${y}`).toBe(true);
    }
    expect(layout.overflow).toEqual({ codeViewX: 0, pageX: 0, pageY: 0 });
  });
}

const sample = 'local s = "hi" .. 12 print(s) -- note';

async function codeTextColors(page, within = ".cm-line, .cm-lineNumbers") {
  return page.evaluate((within) => {
    const backgroundOf = (element) => {
      for (let current = element; current; current = current.parentElement) {
        const background = getComputedStyle(current).backgroundColor;
        if (background !== "rgba(0, 0, 0, 0)" && background !== "transparent") return background;
      }
    };
    const walker = document.createTreeWalker(document.querySelector(".cm-editor"), NodeFilter.SHOW_TEXT);
    const pairs = [];
    while (walker.nextNode()) {
      const element = walker.currentNode.parentElement;
      if (!walker.currentNode.data.trim() || !element.closest(within)) continue;
      pairs.push({
        text: walker.currentNode.data,
        isComment: element.textContent.startsWith("--"),
        mark: element.closest(".cm-selectionMatch, .cm-matchingBracket, .cm-nonmatchingBracket")?.className ?? "",
        color: getComputedStyle(element).color,
        background: backgroundOf(element),
      });
    }
    return pairs;
  }, within);
}

function expectReadable(pairs) {
  for (const pair of pairs) {
    expect(pair.background, `${pair.text} sits on a see-through band, so its contrast can't be read off one colour`).toMatch(/^rgb\(/);
    const minimum = pair.isComment ? 4.5 : 7;
    expect(contrastRatio(rgb(pair.color), rgb(pair.background)), `${pair.text} ${pair.color} on ${pair.background}`).toBeGreaterThanOrEqual(minimum);
  }
}

test("every kind of code text keeps 7:1 contrast on the screen and on the current line, comments 4.5:1", async ({ page }) => {
  await openCodeView(page);
  await typeCode(page, `${sample}\n${sample}`);
  await expect(page.locator(".cm-line").nth(1)).toHaveClass(/cm-activeLine/);

  const pairs = await codeTextColors(page);
  expect(pairs.filter((pair) => pair.isComment)).toHaveLength(2);
  expectReadable(pairs);
});

test("other copies of the selected text keep the same contrast as the screen", async ({ page }) => {
  await openCodeView(page);
  await typeCode(page, `${sample}\n${sample}`);
  await page.locator(".cm-line").first().click();
  await page.keyboard.press("Home");
  await page.keyboard.press("Shift+End");

  const pairs = await codeTextColors(page);
  const onMatch = pairs.filter((pair) => pair.mark.includes("cm-selectionMatch"));
  expect(onMatch.map((pair) => pair.text).join("").replaceAll(" ", "")).toBe(sample.replaceAll(" ", ""));
  expectReadable(onMatch);
});

test("text on a matching or unmatched bracket keeps 7:1 contrast", async ({ page }) => {
  await openCodeView(page);
  await typeCode(page, "local t = {\n  1,\n}\nlocal u = {\n  2,\n]");
  for (const [line, mark] of [[0, "cm-matchingBracket"], [3, "cm-nonmatchingBracket"]]) {
    await page.locator(".cm-line").nth(line).click();
    await page.keyboard.press("End");
    const onBrackets = (await codeTextColors(page)).filter((pair) => pair.mark.includes(mark));
    expect(onBrackets).toHaveLength(2);
    expectReadable(onBrackets);
  }
});

test.describe("on desktop WebKit, where CodeMirror draws the selection", () => {
  const { defaultBrowserType, ...desktopSafari } = devices["Desktop Safari"];
  test.use(desktopSafari);

  test("every kind of code text keeps 7:1 contrast on the selection, comments 4.5:1", async ({ page }) => {
    await openCodeView(page);
    await typeCode(page, `${sample}\n${sample}`);
    await page.locator(".cm-line").first().click();
    await page.keyboard.press("Home");
    await page.keyboard.press("Shift+ArrowDown");

    const selection = await page.locator(".cm-selectionBackground").first().evaluate((element) => getComputedStyle(element).backgroundColor);
    const firstLine = await codeTextColors(page, ".cm-line:first-child");
    expect(firstLine.filter((pair) => pair.isComment)).toHaveLength(1);
    expectReadable(firstLine.map((pair) => ({ ...pair, background: selection })));
  });

  test("a selection on the cursor's line shows over the current-line band, and the band returns when it collapses", async ({ page }) => {
    await openCodeView(page);
    await typeCode(page, `${sample}\n${sample}`);
    await page.keyboard.press("Home");
    await page.keyboard.press("Shift+End");
    const backgroundOf = async (selector) => rgb(await page.locator(selector).first().evaluate((element) => getComputedStyle(element).backgroundColor)).join();
    const selection = await backgroundOf(".cm-selectionBackground");
    const activeLine = await backgroundOf(".cm-activeLineGutter");

    const box = await page.locator(".cm-selectionBackground").first().boundingBox();
    const shown = await pixelColors(page, await page.screenshot({ clip: box }));
    expect(shown).toContain(selection);
    expect(shown).not.toContain(activeLine);

    await page.keyboard.press("End");
    expect(await backgroundOf(".cm-activeLine")).toBe(activeLine);
  });
});

test("the cursor stops blinking when reduced motion is asked for", async ({ page }) => {
  await openCodeView(page);
  await page.locator(".cm-content").focus();
  const cursorAnimation = () => page.locator(".cm-cursorLayer").evaluate((layer) => getComputedStyle(layer).animationName);

  expect(await cursorAnimation()).not.toBe("none");
  await page.emulateMedia({ reducedMotion: "reduce" });
  expect(await cursorAnimation()).toBe("none");
});
