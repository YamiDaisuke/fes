import { readFileSync, writeFileSync } from "node:fs";
import { encodePNG } from "../web/tests/png.js";

const art = [
  "................",
  "................",
  "..############..",
  "..#wwwwwwwwww#..",
  "..#wssssssssw#..",
  "..#wssssssbsw#..",
  "..#wsmmsssssw#..",
  "..#wsmmsssssw#..",
  "..#wkkkkkkkkw#..",
  "..#wwwwwwwwlw#..",
  "..############..",
  "................",
  "...#........aa..",
  "..###....bb.aa..",
  "...#.....bb.....",
  "................",
];

const tokenForSymbol = {
  ".": "shell",
  "#": "ink",
  w: "well",
  s: "screen-off",
  m: "mint",
  b: "butter",
  k: "sky",
  l: "led-on",
  a: "coral",
};

const style = readFileSync(new URL("../web/style.css", import.meta.url), "utf8");

function tokenRGB(name) {
  const match = style.match(new RegExp(`--${name}: #([0-9a-f]{6});`));
  if (!match) throw new Error(`web/style.css has no --${name}: #rrggbb; token`);
  return [0, 2, 4].map((start) => parseInt(match[1].slice(start, start + 2), 16));
}

const colorForSymbol = Object.fromEntries(Object.entries(tokenForSymbol).map(([symbol, token]) => [symbol, tokenRGB(token)]));

const isSquare = art.every((row) => row.length === art.length);
if (!isSquare) throw new Error(`every art row must be ${art.length} symbols long`);

function iconPNG(size) {
  const cell = Math.floor(size / art.length);
  const edge = Math.floor((size - art.length * cell) / 2);
  const rgba = new Uint8Array(size * size * 4);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const symbol = art[Math.floor((y - edge) / cell)]?.[Math.floor((x - edge) / cell)] ?? ".";
      const color = colorForSymbol[symbol];
      if (!color) throw new Error(`unknown art symbol "${symbol}"`);
      rgba.set([...color, 255], (y * size + x) * 4);
    }
  }
  return encodePNG(size, size, rgba);
}

// 152 and 167 are the sizes iPads ask for; each is a whole number of pixels per cell, so iPadOS never resamples the pixel art.
for (const size of [152, 167, 180, 512]) {
  writeFileSync(new URL(`../web/icons/icon-${size}.png`, import.meta.url), iconPNG(size));
}
