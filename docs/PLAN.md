# Plan

Proof of concept first. Milestones M0–M3 are broken into tasks. Later milestones are outlines: when the last task of the previous milestone reaches `stage:ready`, the architect breaks the next milestone into tasks of the same size, adds them to this file in the first PR of that milestone, and creates their issues.

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
- `Console` types for the main palette (placeholder until the owner picks one), the 8+8 sub-palettes and 3bpp 8×8 tiles in tile memory.
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

## M3 — Tile and palette editor

Draw tiles and palettes on the iPad, or import a sprite sheet from Pixquare (or any pixel-art tool), and see them in a running cart. Each cart carries its own main palette.

Swift owns the art and every edit. JavaScript only blits Swift's pixel buffers into canvases, forwards pointer positions, hosts the system color picker and decodes image files. The editor's controls are labelled HTML buttons that VoiceOver and a hardware keyboard can use. Not planned: importing a whole level image into a tilemap, or reducing an image's colors automatically.

The owner answered the M3 questions in PR #51.

### T16 Main palette in the cart
Depends: T15
- The main palette becomes a value with 64 colors that the PPU and the cart carry, instead of a global. The default is Lospec's "Z64" by Jehkoba, 64 colors (https://lospec.com/palette-list/z64, the `.hex` download at https://lospec.com/palette-list/z64.hex), chosen by the owner; its decision record credits the author and link. Code identifiers named "master" (`MasterPalette`, master indices) are renamed to "main palette". Remove the DEBT line about the placeholder palette.
- New cart file `main-palette.hex`: 64 lines of `rrggbb`, lowercase on write, either case on read, as strictly shaped as the other cart files. `cart.json` moves to format 2. Format 1 carts load with the default palette and save as format 2. The `.fes` archive picks the file up through `Cart.fileNames`.
- Re-record the golden images (decision 006). A decision record replaces decision 013's "Later" line.

Accept: tests for the palette file's round trip and refusals naming file and line, a format 1 cart (from OPFS and from a `.fes`) loading with the default palette, and the goldens in the new colors.

### T17 Art view and tile sheet
Depends: T16
- An `Editors` target (SPEC). A third full-screen view, Art, next to Code and Game. Save is reachable from it.
- Swift renders a bank's 256 tiles as a 16×16 sheet and the edit area at the largest integer zoom that fits, with a pixel grid. JS blits both buffers into canvases and sends taps to Swift as canvas pixel positions.
- Switch bank (background or sprite) and preview palette (one of that bank's 8). Tap a tile to select it, and the edit area shows it.

Accept: golden tests of the sheet and the edit area, including sprite color 0 drawn as transparent; Playwright opens Art, taps a tile and sees it in the edit area.

### T18 Pencil and picker
Depends: T17
- A strip with the preview palette's 8 colors. The pencil paints the selected color while dragging, with finger or Pencil. A fast drag still draws a continuous line. The picker takes the color under the touch.
- Edits change the open cart: Save writes them, Run puts them in `spr` and the map, and the unsaved-changes prompt sees them.

Accept: Swift tests for stroke lines, including strokes that leave the edit area; Playwright draws a stroke, runs a cart whose `spr` shows the drawn tile, saves, reloads and finds the pixels.

### T19 Recovery copy of the whole cart
Depends: T18
- Decision 016's recovery copy grows from `main.lua` to every cart file, so unsaved tile, palette and code edits come back after a reload or a frozen tab. A copy written by the older FES still restores. Remove the DEBT line.

Accept: tests for the copy's round trip, an older copy and malformed copies dropped; Playwright draws, reloads without saving, restores, and finds the pixels and the code.

### T20 Blocks, fill, flip, copy and paste
Depends: T18
- The edit area shows a block of 1×1, 2×2 or 4×4 tiles starting at the selected one, and the pencil and picker work across its tile borders.
- Fill replaces the touched pixel's 4-connected same-color region inside the edit area.
- Flip H and V mirror the edit area's block in place, moving tiles as well as pixels.
- Copy and paste the block. The clipboard is Swift state, kept while FES runs and across carts; not the system clipboard.

Accept: tests for mapping block pixels to tiles, fill crossing tile borders inside a block but never leaving it, flipping a 2×2 block, and pasting at the sheet's edge; Playwright uses each tool once.

### T21 Palette editor
Depends: T18
- In the Art view: the 8 background and 8 sprite palettes and the 64 main palette colors as buttons whose labels name the entry and its color. Select a palette entry, then tap a main palette color to assign it. Selecting a palette also makes it the tile editor's preview palette. Sprite color 0 is marked transparent.

Accept: Playwright assigns a main palette color to a sprite palette entry, runs a cart and sees the sprite's new color, saves, reloads and finds it.

### T22 Edit main palette colors
Depends: T21
- Change the selected main palette color with the iPadOS color picker (`<input type="color">`). Every palette entry using that color changes with it. Reset the cart's main palette to the default.

Accept: tests for reading the picker's `#rrggbb` value and refusing anything else; Playwright edits a color, sees the sheet and the game change, saves, reloads and finds it.

### T23 Undo and redo
Depends: T20, T21, T22
- Every Art view edit (stroke, fill, flip, paste, palette and main palette color change) is one undo step. Redo, until the next new edit. The history is cleared when another cart opens and has a fixed limit.

Accept: tests for undo and redo order, redo dropped after a new edit, and the limit; Playwright undoes and redoes a stroke.

### T24 Sheet import core
Depends: T16
- In `Editors`, natively tested: turn a decoded RGBA image into a bank's 256 tiles. Each 8×8 tile keeps its position: image tile (column c, row r) becomes bank tile r × 16 + c, like PICO-8. The import replaces the whole bank; tiles the image doesn't reach are cleared.
- Each pixel must be exactly a color of the cart's main palette, or, in the sprite bank, fully transparent (color 0). Each tile must fit one of the bank's current sub-palettes: its pixel indices are the colors' positions there.
- Otherwise a report lists every broken rule with its tile column and row. The rules: a size that isn't a multiple of 8, a width or height over 128 pixels, half-transparent pixels, transparency in the background bank, colors missing from the main palette, more than 8 colors in a tile (7 plus transparent for sprites), and colors that fit no sub-palette. Dimensions are checked before any pixel is read.

Accept: a test per rule, a sheet that imports exactly, and a report with the right tile positions.

### T25 Import a sheet in the Art view
Depends: T24, T23
- An Import button in the Art view. JS reads the picked file and decodes it with the browser, with no color-space conversion or premultiplied alpha, then hands the RGBA bytes to Swift. Size and dimension limits apply before decoding.
- After a confirm, a clean import replaces the bank. It is one undo step and marks the cart unsaved.
- A rejected import shows the report: Swift draws the image with each offending tile outlined, next to the list of rules. A JPEG's report says to export PNG.

Accept: Playwright imports a fixture PNG and sees its tiles in the sheet and in a running cart, with every color exact; a fixture with a 9-color tile shows the report naming that tile; a JPEG shows the PNG hint.

### T26 Adopt the image's colors
Depends: T25
- Per import, an option: the image's colors (up to 64, in order of first appearance) become the cart's main palette, and the bank's 8 sub-palettes are built from the tiles' color sets. The confirm says that the other bank's colors change too.
- Over 64 colors, or tiles that need more than 8 sub-palettes, are refused with the same report.

Accept: tests for building sub-palettes (tiles sharing a palette, sprite color 0 kept transparent, too many colors, too many palettes); Playwright imports with the option and the running cart shows the image's colors.

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
