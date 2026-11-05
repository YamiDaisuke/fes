const installHintDismissedKey = "fes-install-hint-dismissed";
const installHintPause = 7 * 24 * 60 * 60 * 1000;

export function startPWA() {
  if ("serviceWorker" in navigator) registerServiceWorker();
  showInstallHint();
}

async function registerServiceWorker() {
  const ownWorkerURL = new URL("sw.js", location.href).href;
  let hadController = navigator.serviceWorker.controller?.scriptURL === ownWorkerURL;
  navigator.serviceWorker.addEventListener("controllerchange", () => {
    if (hadController) document.getElementById("update-notice").hidden = false;
    hadController = true;
  });
  document.getElementById("update-reload").addEventListener("click", () => location.reload());

  let registration;
  try {
    registration = await navigator.serviceWorker.register("sw.js");
  } catch (error) {
    console.warn(`FES can't work offline: ${error}`);
    return;
  }
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible") registration.update().catch(() => {});
  });
}

function showInstallHint() {
  if (matchMedia("(display-mode: standalone)").matches) return;
  const dismissedAt = Number(localStorage.getItem(installHintDismissedKey));
  const dismissedRecently = dismissedAt <= Date.now() && Date.now() - dismissedAt < installHintPause;
  if (dismissedRecently) return;
  const hint = document.getElementById("install-hint");
  hint.hidden = false;
  document.getElementById("install-hint-dismiss").addEventListener("click", () => {
    localStorage.setItem(installHintDismissedKey, String(Date.now()));
    document.getElementById("run").focus();
    hint.hidden = true;
  });
}
