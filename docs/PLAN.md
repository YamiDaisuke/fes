# Plan

Proof of concept first. Milestones M0–M2 are broken into tasks now. Later milestones are outlines: when the last task of the previous milestone reaches `stage:ready`, the architect breaks the next milestone into tasks of the same size, adds them to this file in the first PR of that milestone, and creates their issues.

Each task is one PR, small enough to read in one sitting. `Depends` decides what the branch stacks on (see `docs/WORKFLOW.md`).

Done means: the acceptance checks pass, QA and review passed, and the owner merged it.

## M0 — Foundations

The riskiest assumptions get proven before anything else is built on them.

### T01 Scaffold
Depends: none
- SwiftPM package with the targets named in SPEC (`Console`, `Runtime`, `App`; others are added when first needed, not before).
- `web/` with `index.html` and a small boot module that loads the wasm and draws a solid color into a 192×144 canvas, integer-scaled.
- One build script producing `web/dist/`, and one command to serve it locally.
- README: toolchain setup (Swift 6.4, Wasm SDK, Node), build, serve.

Accept: fresh clone + README steps shows the colored canvas in Safari/WebKit.

### T02 Lua in wasm spike
Depends: T01
- Vendor Lua 5.4 as a SwiftPM C target and compile it for wasm.
- From Swift: run a chunk that returns a value, and a chunk that raises an error caught with `pcall`. Show both results on the page.
- Lua errors use `setjmp`/`longjmp`. On WASI that needs wasm exception handling support from the toolchain and the browser. This task exists to prove it works in Safari; if it doesn't, compile Lua as C++ (errors become C++ exceptions) or find another route, and record the outcome.
- Decision record: `docs/decisions/001-lua-on-wasm.md`.

Accept: both results visible in WebKit, including the caught error message.

### T03 CI and previews
Depends: T01
- GitHub Actions: build, `swift test`, Playwright smoke test on WebKit with an iPad profile (page loads, canvas renders, no console errors).
- Deploy `main` to GitHub Pages. Deploy each PR to `/pr/<number>/` on Pages and post the URL on the PR, so the owner can try every PR on the iPad.

Accept: a PR shows a working preview link; CI fails when the smoke test fails.

## M1 — Something moves on screen

PoC milestone: a Lua cart moves a sprite with the D-pad on an iPad.

### T04 Palettes and tiles
Depends: T01
- `Console` types for the master palette (placeholder until the owner picks one), the 8+8 sub-palettes and 3bpp 8×8 tiles in tile memory.
- Decoding a tile row to palette indices.

Accept: tests for tile decoding and palette lookup, including out-of-range handling.

### T05 Background layer
Depends: T04
- 192×144 RGBA framebuffer. Render one background layer from a tilemap with scroll X/Y, wrapping.
- Golden-image test harness (render natively, compare with a checked-in PNG, write the actual image on failure).

Accept: golden tests for an unscrolled, a scrolled and a wrapping scene.

### T06 Display loop
Depends: T05, T03
- JS blits the framebuffer from wasm memory to the canvas each frame (Canvas 2D). Swift exposes `frame()`.
- A hardcoded test scene scrolls on its own.

Accept: smooth scrolling in WebKit; Playwright screenshot of a known frame matches.

### T07 Sprites
Depends: T05
- 64-entry sprite table: position, tile, palette, flip H/V, priority. Color 0 transparent. 16 sprites per scanline, extras dropped in table order.

Accept: golden tests for flip, transparency, priority and the scanline limit.

### T08 Input
Depends: T06
- Keyboard and a touch overlay (D-pad, A, B, Start, Select) in HTML/CSS, reduced to one bitmask per frame. `btn` (held) and `btnp` (pressed this frame) in Swift.

Accept: `btnp` edge detection tested in Swift; Playwright taps the overlay and a test scene reacts.

### T09 Cart runtime
Depends: T02, T06
- Load a cart's `main.lua` (embedded test cart for now), run it in the sandbox, call `_init`, then `_update` and `_draw` each frame.
- Lua errors stop the cart and show the message and line on screen.

Accept: a cart with a deliberate runtime error shows the correct line; the sandbox blocks `io`, `os`, `load` of bytecode.

### T10 Console API v0
Depends: T07, T08, T09
- `cls`, `spr`, `btn`, `btnp`, `mset`, `mget`, `camera` bound to Lua. Document them in `docs/API.md`.
- Demo cart: walk a sprite around a tile room with the D-pad.

Accept: the demo works on iPad via the PR preview. **PoC reached.**

### T11 CPU and RAM budgets
Depends: T09
- Instruction-count hook per frame and capped allocator, both with clear on-screen errors. Placeholder limits until the owner sets them.

Accept: tests for an infinite loop and an allocation bomb, both stopped with the right error.

## M2 — Write code on the iPad

### T12 Cart storage
Depends: T09
- OPFS wrapper (JS, async) and the cart folder model in Swift: `cart.json` (name, format version), `main.lua`, text-based files for graphics and map. Ask the owner about format details.
- Save, load, list carts. Request persistent storage.

Accept: round-trip test of the cart serializer; Playwright saves, reloads the page, and finds the cart.

### T13 Code editor
Depends: T12
- CodeMirror 6 bundled with esbuild, Lua highlighting, touch-friendly settings. Editor and game as two views with a run button.

Accept: on iPad preview, edit `main.lua`, run, see the change; text input works with a hardware keyboard.

### T14 Live diagnostics
Depends: T13
- Parse on change (load without running) and show syntax errors in CodeMirror. Runtime errors jump to the line in the editor.

Accept: a syntax error appears as a diagnostic on the right line within a moment of typing.

### T15 PWA
Depends: T12
- Manifest, icons, service worker for offline. Prompt to add to Home Screen, explaining why (Safari storage eviction). Zip export and import of a cart through the Files app.

Accept: installed to Home Screen, works in airplane mode; export then import restores a cart exactly.

## M3 — Tile and palette editor (outline)

Master palette choice with the owner; palette editor; tile editor (pencil, fill, picker, flip, copy/paste); sprite sheet saved in the cart and used by `spr`.

## M4 — Map and scene editor (outline)

Second background layer and window layer in the PPU; map editor for both layers; scene objects (named entities with type and position, readable from Lua); `map` API; map sizes decided with the owner.

## M5 — Audio (outline)

AudioWorklet + synth wasm spike with one pulse tone (iOS needs a user tap to start audio); the four channels; sfx tracker with effects; music patterns; `sfx` and `music` API.

## M6 — Version history (outline)

Content-addressed store; snapshots with messages; history view, restore; text diff for code, visual diff for tiles and maps.

## M7 — Teal (outline)

Vendor the pinned Teal compiler; compile `.tl` in a separate VM on save; `console.d.tl`; `require` searcher across `.tl` and `.lua`; diagnostics in CodeMirror; runtime error line mapping.

## M8 — Hardware extras (outline)

Overlay layer and primitives, metasprites, blending, palette cycling and per-scanline palette changes, scanline callback, numeric limits finalized.
