import { init } from "../.build/js/index.js";

const canvas = document.getElementById("screen");

function fitCanvas() {
  const scale = Math.max(1, Math.floor(Math.min(innerWidth / canvas.width, innerHeight / canvas.height)));
  canvas.style.width = `${canvas.width * scale}px`;
  canvas.style.height = `${canvas.height * scale}px`;
}

await init();
fitCanvas();
addEventListener("resize", fitCanvas);
