# Debt

Deliberate shortcuts, one line each: what, why, when to revisit.
- App.wasm ships without wasm-opt (9.1 MB, 2.4 MB gzipped): binaryen isn't installed or approved; revisit in T15 when offline first-load size matters.
- A cancelled pending deploy leaves its PR's check cancelled and can skip that PR's first preview comment: the `pages` concurrency group keeps only one pending job, so restacking three or more PRs cancels some; revisit if restacks often leave PRs without a preview link.
- Master palette is a generated 2-bit-per-channel placeholder: the owner picks the curated 64 colors (SPEC open decision); revisit at the start of M3.
- Background tilemap is a fixed 32×32 cells: map dimensions are a SPEC open decision the owner takes in M4; revisit then (change Tilemap.columns/rows, keep powers of two, re-record goldens).
- One console frame per requestAnimationFrame callback: Safari on iPad delivers rAF at 60 Hz by default, but with the "Prefer Page Rendering Updates near 60fps" feature flag off ProMotion iPads call it at 120 Hz and the game runs at double speed; revisit when input or the cart runtime needs real-time pacing (fixed timestep driven by rAF timestamps).
- The touch overlay is a plain placeholder look and is always shown, even with a hardware keyboard: the owner styles it; revisit at the owner's review of T08 or with T13's editor chrome.
- Keyboard input is read on window and mapped keys call preventDefault: there is no editor yet; revisit in T13 when the code editor needs those keys.
- The overlay buttons listen only for pointer events, not `click`, so VoiceOver and Switch Control activation does nothing: it is a placeholder pad; revisit with the T15 PWA work or when the owner restyles the overlay.
- App runs `window.testCartMainLua` instead of the embedded demo cart when the page sets it, so Playwright specs can run their own carts: nothing loads carts yet; revisit in T12 when carts load from storage.
- Demo graphics are Swift string art in Runtime/DemoCart.swift, loaded for every cart: no sprite sheet or cart format yet; revisit in T12/M3.
- CPU budget of 500,000 instructions (per frame, and for the main chunk + `_init` together) and an 8 MiB memory cap are placeholders in `Runtime/Budgets.swift`: the owner sets SPEC's numeric limits; revisit when the owner decides them.
- The Lua stack is limited to 15,000 slots (`CLua/fes_lua_user.h`) so a `__call` cycle stops in about 0.1 s, which caps recursion at about 1,500–7,500 levels: the stall grows with the square of the limit; revisit if a cart needs deeper recursion.
- One C library call can still freeze the tab, for example `string.find(string.rep("a", 300), ".-.-.-.-b")`: the count hook cannot fire inside C, and main-thread wasm cannot be interrupted; revisit before T13, when a freeze would lose unsaved editor code (fix: run the console in a Worker the page can terminate).
- CPU and memory errors give no hint of which budget number was hit or how close the cart came: there is no usage display yet; revisit with the owner's limits.
