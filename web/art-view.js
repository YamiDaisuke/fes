export function createArtView(wasmBuffer) {
  return {
    blit(canvas, address) {
      const pixels = new Uint8ClampedArray(wasmBuffer(), address, canvas.width * canvas.height * 4);
      canvas.getContext("2d").putImageData(new ImageData(pixels, canvas.width, canvas.height), 0, 0);
    },
    onTap(canvas, listener) {
      canvas.addEventListener("pointerdown", (event) => {
        // Without this, WebKit's touch adjustment sends a tap near the canvas edge's click and focus to the nearest control (decision 024).
        event.preventDefault();
        const box = canvas.getBoundingClientRect();
        listener(Math.floor(event.clientX - box.left), Math.floor(event.clientY - box.top));
      });
    },
    onStroke(canvas, listener) {
      let stroke = null;
      const positions = (events) => {
        const box = canvas.getBoundingClientRect();
        return events.flatMap((event) => [Math.floor(event.clientX - box.left), Math.floor(event.clientY - box.top)]);
      };
      canvas.addEventListener("pointerdown", (event) => {
        // Without this, WebKit's touch adjustment sends a tap near the canvas edge's click and focus to the nearest control (decision 024).
        event.preventDefault();
        if (event.button !== 0) return;
        if (stroke) {
          // A palm lands as a touch before the Pencil, and iPadOS sends no more finger events once the Pencil touches.
          if (event.pointerType !== "pen" || stroke.pointerType === "pen") return;
          listener("cancel", []);
        }
        canvas.setPointerCapture(event.pointerId);
        stroke = { pointerId: event.pointerId, pointerType: event.pointerType };
        listener("start", positions([event]));
      });
      canvas.addEventListener("pointermove", (event) => {
        if (event.pointerId !== stroke?.pointerId) return;
        // WebKit's coalesced events have no pointerId, so only the parent event is checked.
        const coalesced = event.getCoalescedEvents?.() ?? [];
        listener("move", positions(coalesced.length > 0 ? coalesced : [event]));
      });
      const finishStroke = (kind) => (event) => {
        if (event.pointerId !== stroke?.pointerId) return;
        stroke = null;
        listener(kind, []);
      };
      canvas.addEventListener("pointerup", finishStroke("end"));
      canvas.addEventListener("pointercancel", finishStroke("cancel"));
    },
  };
}
