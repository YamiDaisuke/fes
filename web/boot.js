import { init } from "../.build/js/index.js";
import { listenForInput, buttonsForFrame } from "./input.js";
import * as storage from "./storage.js";
import * as files from "./files.js";
import { createCodeEditor } from "./code-editor.js";
import { createArtView } from "./art-view.js";
import { startPWA } from "./pwa.js";

startPWA();

const canvas = document.getElementById("screen");
const gameView = document.getElementById("game-view");

function fitCanvas() {
  const fit = Math.min(gameView.clientWidth / canvas.width, gameView.clientHeight / canvas.height);
  const scale = Math.max(1, Math.floor(fit));
  canvas.style.width = `${canvas.width * scale}px`;
  canvas.style.height = `${canvas.height * scale}px`;
}

globalThis.fesStorage = storage;
globalThis.fesFiles = files;
globalThis.fesCodeEditor = createCodeEditor(document.getElementById("code-editor"));
let wasmMemory;
globalThis.fesArtView = createArtView(() => wasmMemory.buffer);
const { instance } = await init();
wasmMemory = instance.exports.memory;
new ResizeObserver(fitCanvas).observe(gameView);

const context = canvas.getContext("2d");
listenForInput(document.getElementById("pad"));

function drawFrame() {
  let address;
  try {
    address = instance.exports.frame(buttonsForFrame());
  } catch (error) {
    document.getElementById("cart-error").textContent = `FES stopped: ${error}\nReload the page to start again.`;
    throw error;
  }
  // Memory growth detaches the old buffer, so take a fresh view every frame.
  const pixels = new Uint8ClampedArray(instance.exports.memory.buffer, address, canvas.width * canvas.height * 4);
  context.putImageData(new ImageData(pixels, canvas.width, canvas.height), 0, 0);
  requestAnimationFrame(drawFrame);
}
requestAnimationFrame(drawFrame);
