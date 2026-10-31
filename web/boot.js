import { init } from "../.build/js/index.js";
import { listenForInput, buttonsForFrame } from "./input.js";

const canvas = document.getElementById("screen");

function fitCanvas() {
  const scale = Math.max(1, Math.floor(Math.min(innerWidth / canvas.width, innerHeight / canvas.height)));
  canvas.style.width = `${canvas.width * scale}px`;
  canvas.style.height = `${canvas.height * scale}px`;
}

const { instance } = await init();
fitCanvas();
addEventListener("resize", fitCanvas);

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
