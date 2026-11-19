import { test, expect } from "@playwright/test";
import { openPaused, runFrames } from "./frames.js";

// base_funcs in Sources/CLua/lbaselib.c: docs/decisions/057-the-manual-is-the-api-reference.md
const luaBaseLibrary = [
  "assert", "collectgarbage", "dofile", "error", "getmetatable", "ipairs", "load", "loadfile", "next", "pairs", "pcall",
  "print", "rawequal", "rawget", "rawlen", "rawset", "select", "setmetatable", "tonumber", "tostring", "type", "warn", "xpcall",
];

const listConsoleGlobals = `
local standard = {}
for name in ("${luaBaseLibrary.join(" ")}"):gmatch("%S+") do standard[name] = true end
local names = {}
for name, value in pairs(_G) do
  if type(value) == "function" and not standard[name] then names[#names + 1] = name end
end
table.sort(names)
error("console globals: " .. table.concat(names, " "), 0)`;

test("every console global has an API entry in the manual, and every entry a global", async ({ page }) => {
  await page.goto("/manual/");
  const documented = await page.evaluate(() =>
    [...document.querySelectorAll('#api [id^="api-"]')].map((entry) => entry.id.slice("api-".length)).sort(),
  );

  await page.addInitScript((mainLua) => { window.testCartMainLua = mainLua; }, listConsoleGlobals);
  await openPaused(page);
  await runFrames(page, 1);

  const answer = (await page.locator("#cart-error").textContent()).match(/^console globals: (.*)$/m);
  expect(answer).not.toBeNull();
  expect(answer[1].split(" ")).toEqual(documented);
});
