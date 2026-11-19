import { instantiate } from "../.build/js/instantiate.js";
import { defaultBrowserSetup } from "../.build/js/platforms/browser.js";
import { listenForInput, buttonsForFrame, showHeldButtons } from "./input.js";
import * as storage from "./storage.js";
import * as files from "./files.js";
import { createCodeEditor } from "./code-editor.js";
import { createArtView } from "./art-view.js";
import { startPWA } from "./pwa.js";
import { startCRTSwitch } from "./crt.js";

startPWA();
startCRTSwitch();

const canvas = document.getElementById("screen");
const bezel = document.getElementById("bezel");
const screenSlot = document.getElementById("screen-slot");
const gameView = document.getElementById("game-view");
const smallestScaleWithScanlines = 3;

function fitCanvas() {
  const chromeWidth = bezel.offsetWidth - canvas.offsetWidth;
  const chromeHeight = bezel.offsetHeight - canvas.offsetHeight;
  const fit = Math.min((screenSlot.clientWidth - chromeWidth) / canvas.width, (screenSlot.clientHeight - chromeHeight) / canvas.height);
  const scale = Math.max(1, Math.floor(fit));
  canvas.style.width = `${canvas.width * scale}px`;
  canvas.style.height = `${canvas.height * scale}px`;
  gameView.style.setProperty("--screen-scale", scale);
  gameView.toggleAttribute("data-scanlines", scale >= smallestScaleWithScanlines);
}

globalThis.fesStorage = storage;
globalThis.fesFiles = files;
globalThis.fesCodeEditor = createCodeEditor(document.getElementById("code-editor"));
let wasmMemory;
globalThis.fesArtView = createArtView(() => wasmMemory.buffer);
const { instance } = await instantiate({
  ...(await defaultBrowserSetup({ module: fetch(new URL("App.wasm", import.meta.url)) })),
  // main() draws the shelf's demo picture through fesArtView, so it needs the memory before main() runs.
  instrumentInstance(instance) {
    wasmMemory = instance.exports.memory;
    return instance;
  },
});
new ResizeObserver(fitCanvas).observe(screenSlot);

const helpFrame = document.getElementById("help-frame");
window.addEventListener("message", (event) => {
  const name = event.data?.fesExample;
  // No event.source check: WebKit gives the parent window as the source of a message posted from a module script.
  if (event.origin !== location.origin || typeof name !== "string") return;
  const pres = [...helpFrame.contentDocument.querySelectorAll("pre[data-example]")].filter((pre) => pre.dataset.example === name);
  if (pres.length === 0) return;
  const heading = pres[0].closest("section").querySelector("h3").textContent;
  globalThis.fesOpenExample(heading, pres.map((pre) => ({ file: pre.dataset.file ?? "main.lua", text: pre.textContent })));
});

const context = canvas.getContext("2d");
listenForInput(document.getElementById("pad"));

const framePeriod = 1000 / 60;
const mostFramesPerCallback = 4;
let lastTime;
let owedMs = framePeriod;

function drawFrame(now) {
  owedMs += now - (lastTime ?? now);
  lastTime = now;
  // The 1 ms slack keeps a 60 Hz display's timer jitter from alternating 0 and 2 frames.
  const framesDue = Math.floor((owedMs + 1) / framePeriod);
  const framesToRun = Math.min(framesDue, mostFramesPerCallback);
  if (framesToRun > 0) {
    let address;
    try {
      for (let i = 0; i < framesToRun; i++) {
        const buttons = buttonsForFrame();
        showHeldButtons(buttons);
        address = instance.exports.frame(buttons);
      }
    } catch (error) {
      document.getElementById("cart-error").textContent = `FES stopped: ${error}\nReload the page to start again.`;
      throw error;
    }
    // Memory growth detaches the old buffer, so take a fresh view every frame.
    const pixels = new Uint8ClampedArray(instance.exports.memory.buffer, address, canvas.width * canvas.height * 4);
    context.putImageData(new ImageData(pixels, canvas.width, canvas.height), 0, 0);
  }
  owedMs = framesDue > mostFramesPerCallback ? 0 : owedMs - framesDue * framePeriod;
  requestAnimationFrame(drawFrame);
}
requestAnimationFrame(drawFrame);

const bootLogo = document.getElementById("boot-logo");
// A view switch cancels a CSS animation, which rejects its finished promise.
Promise.allSettled(bootLogo.getAnimations().map((animation) => animation.finished)).then(() => document.body.removeAttribute("data-booting"));
