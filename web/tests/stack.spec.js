import { test, expect } from "@playwright/test";
import { openPaused, runFrames } from "./frames.js";

const recursingCarts = {
  "string.gsub calling itself": `
    local function f(s) return (string.gsub(s, ".", f)) end
    function _update() f("x") end`,
  "string.gsub through an __index metamethod": `
    local function f(s) return (string.gsub(s, ".", setmetatable({}, {__index = function() return f("x") end}))) end
    function _update() f("x") end`,
  "string.format through __tostring": `
    local mt = {}
    mt.__tostring = function() return string.format("%s", setmetatable({}, mt)) end
    function _update() tostring(setmetatable({}, mt)) end`,
  "a table.sort comparator sorting again": `
    local function f() table.sort({3, 1, 2}, function(a, b) f() return a < b end) end
    function _update() f() end`,
  "nested pcall": `
    local function f() local ok, message = pcall(f) error(message, 0) end
    function _update() f() end`,
  "load calling a reader that loads again": `
    local function f() local chunk, message = load(function() f() return nil end) if not chunk then error(message, 0) end end
    function _update() f() end`,
};

for (const [name, mainLua] of Object.entries(recursingCarts)) {
  test(`C recursion through ${name} stops the cart with a stack overflow and the loop keeps running`, async ({ page }) => {
    await page.addInitScript((mainLua) => { window.testCartMainLua = mainLua; }, mainLua);
    await openPaused(page);

    await runFrames(page, 2);
    await expect(page.locator("#cart-error")).toContainText("stack overflow");
  });
}
