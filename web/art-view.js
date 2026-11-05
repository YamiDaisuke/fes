export function createArtView(wasmBuffer) {
  return {
    blit(canvas, address) {
      const pixels = new Uint8ClampedArray(wasmBuffer(), address, canvas.width * canvas.height * 4);
      canvas.getContext("2d").putImageData(new ImageData(pixels, canvas.width, canvas.height), 0, 0);
    },
    onTap(canvas, listener) {
      canvas.addEventListener("pointerdown", (event) => {
        const box = canvas.getBoundingClientRect();
        listener(Math.floor(event.clientX - box.left), Math.floor(event.clientY - box.top));
      });
    },
  };
}
