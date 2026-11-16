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
  KeyZ: "a",
  KeyX: "b",
  Enter: "start",
  ShiftLeft: "select",
  ShiftRight: "select",
};

const CLICK_PRESS_FRAMES = 6;
const FINGER_CLICK_WINDOW_MS = 500;

const heldKeys = new Set();
const pointerButtons = new Map();
const clickPresses = new Map();
let pressedSinceLastFrame = 0;
let lastPointerEnd = -Infinity;
let padButtons = [];

function buttonBits(control) {
  return control.dataset.buttons.split(" ").reduce((bits, name) => bits | BUTTON_BITS[name], 0);
}

function buttonsAt(x, y) {
  const control = document.elementFromPoint(x, y)?.closest("[data-buttons]");
  return control ? buttonBits(control) : 0;
}

function trackPointer(event) {
  const bits = buttonsAt(event.clientX, event.clientY);
  pointerButtons.set(event.pointerId, bits);
  pressedSinceLastFrame |= bits;
}

function releasePointer(event) {
  // iPadOS follows a finger's tap with a click; the tap already pressed the button.
  if (pointerButtons.delete(event.pointerId)) lastPointerEnd = performance.now();
}

function pressForClick(event) {
  const button = event.target.closest("button[data-buttons]");
  if (!button || pointerButtons.size > 0 || performance.now() - lastPointerEnd < FINGER_CLICK_WINDOW_MS) return;
  clickPresses.set(buttonBits(button), CLICK_PRESS_FRAMES);
}

function isPageKey(event) {
  const isTextField = event.target.isContentEditable || event.target.matches("input, textarea");
  const isButtonPress = event.code === "Enter" && event.target.matches("button") && !event.target.closest("#pad");
  const isInDialog = event.target.closest("dialog") !== null;
  return isTextField || isButtonPress || isInDialog;
}

export function listenForInput(overlay) {
  addEventListener("keydown", (event) => {
    const button = KEY_BUTTONS[event.code];
    if (!button || isPageKey(event) || event.metaKey || event.ctrlKey || event.altKey) return;
    event.preventDefault();
    heldKeys.add(event.code);
    pressedSinceLastFrame |= BUTTON_BITS[button];
  });
  addEventListener("keyup", (event) => {
    if (heldKeys.delete(event.code)) event.preventDefault();
  });
  padButtons = [...overlay.querySelectorAll("button[data-buttons]")];
  overlay.addEventListener("pointerdown", trackPointer);
  overlay.addEventListener("click", pressForClick);
  addEventListener("pointermove", (event) => {
    if (pointerButtons.has(event.pointerId)) trackPointer(event);
  });
  addEventListener("pointerup", releasePointer);
  addEventListener("pointercancel", releasePointer);
  addEventListener("blur", () => {
    heldKeys.clear();
    pointerButtons.clear();
    clickPresses.clear();
  });
}

export function showHeldButtons(bits) {
  for (const button of padButtons) button.toggleAttribute("data-held", (bits & buttonBits(button)) !== 0);
}

export function buttonsForFrame() {
  let bits = pressedSinceLastFrame;
  for (const code of heldKeys) bits |= BUTTON_BITS[KEY_BUTTONS[code]];
  for (const pointerBits of pointerButtons.values()) bits |= pointerBits;
  for (const [clickBits, framesLeft] of clickPresses) {
    bits |= clickBits;
    if (framesLeft === 1) clickPresses.delete(clickBits);
    else clickPresses.set(clickBits, framesLeft - 1);
  }
  pressedSinceLastFrame = 0;
  return bits;
}
