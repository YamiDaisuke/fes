// Bit order matches Swift's Button enum: docs/decisions/009-input.md
const BUTTON_BITS = {
  left: 1 << 0,
  right: 1 << 1,
  up: 1 << 2,
  down: 1 << 3,
  a: 1 << 4,
  b: 1 << 5,
  start: 1 << 6,
  select: 1 << 7,
};

const KEY_BUTTONS = {
  ArrowLeft: "left",
  ArrowRight: "right",
  ArrowUp: "up",
  ArrowDown: "down",
  KeyX: "a",
  KeyZ: "b",
  Enter: "start",
  ShiftLeft: "select",
  ShiftRight: "select",
};

const heldKeys = new Set();
const pointerButtons = new Map();
let pressedSinceLastFrame = 0;

function buttonsAt(x, y) {
  const control = document.elementFromPoint(x, y)?.closest("[data-buttons]");
  if (!control) return 0;
  return control.dataset.buttons.split(" ").reduce((bits, name) => bits | BUTTON_BITS[name], 0);
}

function press(bits) {
  pressedSinceLastFrame |= bits;
}

function trackPointer(event) {
  const bits = buttonsAt(event.clientX, event.clientY);
  pointerButtons.set(event.pointerId, bits);
  press(bits);
}

function releasePointer(event) {
  pointerButtons.delete(event.pointerId);
}

export function listenForInput(overlay) {
  addEventListener("keydown", (event) => {
    const button = KEY_BUTTONS[event.code];
    if (!button) return;
    event.preventDefault();
    heldKeys.add(event.code);
    press(BUTTON_BITS[button]);
  });
  addEventListener("keyup", (event) => {
    if (!KEY_BUTTONS[event.code]) return;
    event.preventDefault();
    heldKeys.delete(event.code);
  });
  overlay.addEventListener("pointerdown", trackPointer);
  addEventListener("pointermove", (event) => {
    if (pointerButtons.has(event.pointerId)) trackPointer(event);
  });
  addEventListener("pointerup", releasePointer);
  addEventListener("pointercancel", releasePointer);
  addEventListener("blur", () => {
    heldKeys.clear();
    pointerButtons.clear();
  });
}

export function buttonsForFrame() {
  let bits = pressedSinceLastFrame;
  for (const code of heldKeys) bits |= BUTTON_BITS[KEY_BUTTONS[code]];
  for (const pointerBits of pointerButtons.values()) bits |= pointerBits;
  pressedSinceLastFrame = 0;
  return bits;
}
