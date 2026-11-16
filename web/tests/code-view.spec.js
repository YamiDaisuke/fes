import { test, expect } from "@playwright/test";
import { typeCode } from "./code-editor.js";
import { contrastRatio } from "./contrast.js";
import { rgb } from "./pixels.js";

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

test("every kind of code text keeps 7:1 contrast on the screen and on the current line, comments 4.5:1", async ({ page }) => {
  await openCodeView(page);
  const sample = 'local s = "hi" .. 12 print(s) -- note';
  await typeCode(page, `${sample}\n${sample}`);
  await expect(page.locator(".cm-line").nth(1)).toHaveClass(/cm-activeLine/);

  const pairs = await page.evaluate(() => {
    const backgroundOf = (element) => {
      for (let current = element; current; current = current.parentElement) {
        const background = getComputedStyle(current).backgroundColor;
        if (background !== "rgba(0, 0, 0, 0)" && background !== "transparent") return background;
      }
    };
    const lines = [...document.querySelectorAll(".cm-line")];
    const texts = lines.flatMap((line) => [line, ...line.querySelectorAll("span:not(:has(span))")]);
    const lineNumbers = [...document.querySelectorAll(".cm-lineNumbers .cm-gutterElement")].filter((element) => element.textContent);
    return [...texts, ...lineNumbers].map((element) => ({
      text: element.textContent,
      isComment: element.textContent.startsWith("--"),
      color: getComputedStyle(element).color,
      background: backgroundOf(element),
    }));
  });

  expect(pairs.filter((pair) => pair.isComment)).toHaveLength(2);
  for (const pair of pairs) {
    const minimum = pair.isComment ? 4.5 : 7;
    expect(contrastRatio(rgb(pair.color), rgb(pair.background)), `${pair.text} ${pair.color} on ${pair.background}`).toBeGreaterThanOrEqual(minimum);
  }
});

test("the cursor stops blinking when reduced motion is asked for", async ({ page }) => {
  await openCodeView(page);
  await page.locator(".cm-content").focus();
  const cursorAnimation = () => page.locator(".cm-cursorLayer").evaluate((layer) => getComputedStyle(layer).animationName);

  expect(await cursorAnimation()).not.toBe("none");
  await page.emulateMedia({ reducedMotion: "reduce" });
  expect(await cursorAnimation()).toBe("none");
});
