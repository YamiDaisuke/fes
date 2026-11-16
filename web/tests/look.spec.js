import { test, expect } from "@playwright/test";

function contrastRatio(foreground, background) {
  const luminance = ([r, g, b]) => {
    const linear = (channel) => {
      const c = channel / 255;
      return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
    };
    return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b);
  };
  const [lighter, darker] = [luminance(foreground), luminance(background)].sort((a, b) => b - a);
  return (lighter + 0.05) / (darker + 0.05);
}

function rgb(cssColor) {
  return cssColor.match(/\d+/g).slice(0, 3).map(Number);
}

async function pixelColors(page, png) {
  return page.evaluate(async (base64) => {
    const bitmap = await createImageBitmap(await (await fetch(`data:image/png;base64,${base64}`)).blob());
    const canvas = new OffscreenCanvas(bitmap.width, bitmap.height);
    const context = canvas.getContext("2d");
    context.drawImage(bitmap, 0, 0);
    const pixels = context.getImageData(0, 0, bitmap.width, bitmap.height).data;
    const colors = [];
    for (let i = 0; i < pixels.length; i += 4) colors.push(`${pixels[i]},${pixels[i + 1]},${pixels[i + 2]}`);
    return colors;
  }, png.toString("base64"));
}

test.beforeEach(async ({ page }) => {
  await page.goto("/look.html");
  await page.evaluate(() => document.fonts.ready);
});

test("every text-on-surface token pair keeps a contrast of at least 7:1", async ({ page }) => {
  const pairs = await page.locator(".pair").evaluateAll((elements) =>
    elements.map((element) => {
      const style = getComputedStyle(element);
      return { text: element.textContent, color: style.color, background: style.backgroundColor };
    }),
  );

  expect(pairs).toHaveLength(9);
  for (const pair of pairs) {
    expect(contrastRatio(rgb(pair.color), rgb(pair.background)), pair.text).toBeGreaterThanOrEqual(7);
  }
});

test("every key on the proof sheet is at least 44×44 CSS px", async ({ page }) => {
  await page.getByRole("button", { name: "Show dialog" }).click();

  const sizes = await page.locator(".key").evaluateAll((keys) =>
    keys.map((key) => ({ text: key.textContent, width: key.getBoundingClientRect().width, height: key.getBoundingClientRect().height })),
  );

  expect(sizes.length).toBeGreaterThan(0);
  for (const size of sizes) {
    expect(size.width, size.text).toBeGreaterThanOrEqual(44);
    expect(size.height, size.text).toBeGreaterThanOrEqual(44);
  }
});

test("both pixel fonts load", async ({ page }) => {
  const fonts = await page.evaluate(() => ({
    checks: [document.fonts.check('16px "Pixel Operator 8"'), document.fonts.check('22px "Departure Mono"')],
    loaded: [...document.fonts].filter((face) => face.status === "loaded").map((face) => face.family.replaceAll('"', "")),
  }));

  expect(fonts.checks).toEqual([true, true]);
  expect(fonts.loaded).toEqual(expect.arrayContaining(["Pixel Operator 8", "Departure Mono"]));
});

async function tabTo(page, name) {
  const control = page.getByRole("button", { name, exact: true });
  for (let presses = 0; presses < 40 && !(await control.evaluate((element) => element === document.activeElement)); presses += 1) {
    await page.keyboard.press("Tab");
  }
  await expect(control).toBeFocused();
  return control;
}

async function screenshotAround(page, control, margin) {
  const box = await control.boundingBox();
  return page.screenshot({ clip: { x: box.x - margin, y: box.y - margin, width: box.width + 2 * margin, height: box.height + 2 * margin } });
}

test("the focus ring shows on the selected swatch", async ({ page }) => {
  const swatch = await tabTo(page, "Color 2");
  const focused = await screenshotAround(page, swatch, 4);
  await swatch.blur();
  const unfocused = await screenshotAround(page, swatch, 4);

  expect(focused.equals(unfocused)).toBe(false);
});

for (const [orientation, viewport] of [["landscape", { width: 1194, height: 834 }], ["portrait", { width: 834, height: 1194 }]]) {
  test(`pixel-font text is drawn only in ink and surface colour, with no grey edges, in ${orientation}`, async ({ page }) => {
    await page.setViewportSize(viewport);

    for (const id of ["crisp-ui", "crisp-code"]) {
      const sample = page.locator(`#${id}`);
      const fit = await sample.evaluate((element) => ({
        overflowX: element.scrollWidth - element.clientWidth,
        overflowY: element.scrollHeight - element.clientHeight,
      }));
      expect(fit, `${id} holds every line inside the screenshot`).toEqual({ overflowX: 0, overflowY: 0 });

      const style = await sample.evaluate((element) => ({ color: getComputedStyle(element).color, background: getComputedStyle(element).backgroundColor }));
      const ink = rgb(style.color).join();
      const surface = rgb(style.background).join();
      const colors = await pixelColors(page, await sample.screenshot());
      expect(colors.filter((color) => color === ink).length, id).toBeGreaterThan(0);
      expect(colors.filter((color) => color !== ink && color !== surface).length, id).toBe(0);
    }
  });

  test(`token chips keep their whole-pixel width when labels wrap, in ${orientation}`, async ({ page }) => {
    await page.setViewportSize(viewport);

    const widths = await page.locator(".chip").evaluateAll((chips) => chips.map((chip) => chip.getBoundingClientRect().width));

    expect(new Set(widths)).toEqual(new Set([36]));
  });
}

test("ten Departure Mono characters at 22 px are exactly 140 px wide", async ({ page }) => {
  const width = await page.evaluate(() => {
    const sample = document.createElement("span");
    sample.style.font = '22px "Departure Mono"';
    sample.textContent = "0123456789";
    document.body.append(sample);
    return sample.getBoundingClientRect().width;
  });

  expect(width).toBeCloseTo(140, 3);
});
