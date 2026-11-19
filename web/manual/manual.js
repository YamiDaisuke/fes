const contents = document.getElementById("contents");
const landscape = matchMedia("(orientation: landscape)");
contents.open = landscape.matches;
landscape.addEventListener("change", () => { contents.open = landscape.matches; });
document.getElementById("back-to-fes").hidden = window.top !== window;

function exampleHeading(pre) {
  return pre.closest("section").querySelector("h3").textContent;
}

if (window.top !== window) {
  const lastPreOfEachExample = new Map();
  for (const pre of document.querySelectorAll("pre[data-example]")) {
    lastPreOfEachExample.set(pre.dataset.example, pre);
  }
  for (const [name, pre] of lastPreOfEachExample) {
    const key = document.createElement("button");
    key.type = "button";
    key.className = "key key-go";
    key.textContent = "Open in FES";
    key.setAttribute("aria-label", `Open ${exampleHeading(pre)} in FES`);
    key.addEventListener("click", () => window.parent.postMessage({ fesExample: name }, location.origin));
    pre.after(key);
  }
}
