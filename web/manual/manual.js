const contents = document.getElementById("contents");
const landscape = matchMedia("(orientation: landscape)");
contents.open = landscape.matches;
landscape.addEventListener("change", () => { contents.open = landscape.matches; });
document.getElementById("back-to-fes").hidden = window.top !== window;
