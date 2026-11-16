export function rgb(cssColor) {
  return cssColor.match(/\d+/g).slice(0, 3).map(Number);
}

export async function pixelColors(page, png) {
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
