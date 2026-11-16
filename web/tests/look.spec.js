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

      const png = (await sample.screenshot()).toString("base64");
      const counts = await sample.evaluate(async (element, png) => {
        const style = getComputedStyle(element);
        const bitmap = await createImageBitmap(await (await fetch(`data:image/png;base64,${png}`)).blob());
        const canvas = new OffscreenCanvas(bitmap.width, bitmap.height);
        const context = canvas.getContext("2d");
        context.drawImage(bitmap, 0, 0);
        const pixels = context.getImageData(0, 0, bitmap.width, bitmap.height).data;
        const ink = style.color.match(/\d+/g).slice(0, 3).join();
        const surface = style.backgroundColor.match(/\d+/g).slice(0, 3).join();
        let inkCount = 0;
        let otherCount = 0;
        for (let i = 0; i < pixels.length; i += 4) {
          const pixel = `${pixels[i]},${pixels[i + 1]},${pixels[i + 2]}`;
          if (pixel === ink) inkCount += 1;
          else if (pixel !== surface) otherCount += 1;
        }
        return { inkCount, otherCount };
      }, png);

      expect(counts.inkCount, id).toBeGreaterThan(0);
      expect(counts.otherCount, id).toBe(0);
    }
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
