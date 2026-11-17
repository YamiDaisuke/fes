import { readPreference, writePreference } from "./preferences.js";

const crtPreferenceKey = "fes-crt";

export function startCRTSwitch() {
  const crtKey = document.getElementById("crt-toggle");
  const showCRT = (on) => {
    document.body.dataset.crt = on ? "on" : "off";
    crtKey.setAttribute("aria-pressed", String(on));
  };
  showCRT(readPreference(crtPreferenceKey) === "on");
  crtKey.addEventListener("click", () => {
    const on = document.body.dataset.crt !== "on";
    showCRT(on);
    writePreference(crtPreferenceKey, on ? "on" : "off");
  });
}
