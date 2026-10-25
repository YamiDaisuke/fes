# Spec

## Goal

FES (Frank Entertainment System): a PICO-8-style fantasy console with built-in code, tile, map/scene and sound editors that runs entirely in Safari on iPad, offline, with no server. Its hardware sits between the NES and the Game Boy Color: restrictive enough to push small, focused ideas, with enough color and effects that games can look like modern pixel art rather than strictly NES-era.

## Platform

- Installable PWA, served as static files. Works offline after first load.
- Target: Safari on iPad (current iPadOS). Develop and test against WebKit.
- No backend. All data lives on the device.

## Architecture

Swift owns all state and logic. JavaScript is a thin layer that renders, captures input, plays sound and hosts browser APIs. JS never holds cart or editor data.

### Swift (compiled to wasm with the Swift 6.4 Wasm SDK, bridged with JavaScriptKit)

- **Console**: the "hardware". PPU, APU register model, cart model, input state. Pure Swift with no browser dependencies, so it builds and tests natively.
- **Runtime**: the Lua VM host. Loads carts, calls `_init`, `_update`, `_draw`, exposes the console API, enforces CPU and RAM budgets.
- **Editors**: data models and pixel rendering for the tile, palette, map/scene and tracker editors. They draw into canvases.
- **Storage**: cart format, content-addressed snapshot history, zip export and import.
- **App**: the wasm entry point and the bridge to JavaScript.

### JavaScript

- Boot: load the wasm module, run the frame loop with `requestAnimationFrame`.
- Display: blit the framebuffer from wasm memory to a canvas with integer scaling. Start with Canvas 2D and `image-rendering: pixelated`; move to WebGL only if profiling demands it or for an optional CRT/LCD shader.
- Code editor: CodeMirror 6 with Lua highlighting, diagnostics fed from the Lua or Teal compiler running in wasm.
- Input: keyboard, touch overlay (D-pad, A, B, Start, Select) drawn in HTML/CSS, Gamepad API. All reduced to one button bitmask passed to Swift each frame.
- Audio: an AudioWorklet that hosts a second, tiny Swift wasm module containing only the synth. The main thread sends APU register writes through the worklet's message port. No SharedArrayBuffer.
- PWA shell: manifest, service worker, a small async OPFS wrapper.
- Editor chrome: plain HTML and CSS.

### Storage

- OPFS (Origin Private File System). Request persistent storage with `navigator.storage.persist()`.
- Safari may evict data of sites not added to the Home Screen after about 7 days of disuse. The app must prompt to install to Home Screen and offer zip export to the Files app as backup.

### Versioning

A small built-in version history, not git. Files are stored by content hash. A snapshot is a manifest: parent snapshot, timestamp, message, map of path to hash. Supports list, restore, and diff (text diff for code, side-by-side visual diff for tiles and maps). Cart files stay text-based so git export can be added later.

## Cart language

- Lua 5.4, vendored C sources compiled through a SwiftPM C target.
- Sandbox: only `base` (minus `dofile`, `loadfile`), `string`, `table`, `math`, `utf8`, `coroutine`. No `io`, `os`, `package` (a custom `require` replaces it).
- CPU budget: instruction-count hook (`lua_sethook` with `LUA_MASKCOUNT`) per frame. Exceeding it ends the frame with an on-screen error.
- RAM budget: custom allocator passed to `lua_newstate` with a hard cap. Exceeding it raises a Lua memory error shown on screen.
- Code size limit measured on the Lua the runtime executes.
- `require` is a custom searcher over cart files: `name.tl`, then `name.lua`.

### Teal (optional, milestone M7)

- Per file by extension: `.lua` runs as-is, `.tl` is type-checked and compiled to Lua.
- The vendored Teal compiler runs in a separate Lua VM inside the editor, never against the cart's budgets.
- Compiled Lua is cached next to the source; exported carts ship compiled Lua only.
- `console.d.tl` declares the console API types.
- The Teal version is pinned and recorded in cart metadata.
- Runtime errors in Teal-compiled code must point to the `.tl` line (use a line map if Teal's output doesn't preserve lines).

## Hardware

| | |
|---|---|
| Screen | 192×144, 60 fps |
| Tiles | 8×8, 3 bits per pixel (8 colors per tile) |
| Tile memory | 256 background tiles, 256 sprite tiles |
| Master palette | 64 fixed, curated colors with good shading ramps |
| Palettes | 8 background, 8 sprite, 8 colors each. Sprite color 0 is transparent |
| Background | 2 scrolling tile layers + a non-scrolling window layer for HUDs |
| Overlay | Small framebuffer layer above everything, 4 colors from its own palette, with `pset`, `line`, `rect`, `circ`, `print` |
| Sprites | 64 on screen, 16 per scanline, flip H/V, priority vs background. Metasprites group several hardware sprites into one object |
| Blending | One global mode (half-transparent or additive) applied to chosen layers or sprites |
| Palette tricks | Palette swap, palette cycling, per-scanline palette changes |
| Raster | Optional per-scanline callback (scroll, palette changes) |
| Audio | 4 channels: 2 pulse (duty, sweep), 1 wavetable (32 samples × 4 bits), 1 noise. Volume envelopes. Tracker effects: slide, vibrato, arpeggio, volume |
| Input | D-pad, A, B, Start, Select |
| Assets | Everything is made in the built-in editors. No image or audio import |

## Console API (initial, grows per milestone)

`cls`, `spr`, `btn`, `btnp`, `mget`, `mset`, `map`, `camera`, `pal`, `print`, `sfx`, `music`. Exact signatures are decided in the task that introduces each call and recorded in `docs/API.md`.

## Open decisions

Ask the owner when the task that needs them begins:
- The 64-color master palette. The owner is a pixel artist: propose two or three candidates, let them choose or supply their own.
- Cart file format details (text sections, single-file export).
- Map dimensions in cart storage and VRAM.
- Numeric limits: code size, CPU instructions per frame, RAM cap.
- Whether a PICO-8-style `peek`/`poke` memory map exists at all. Default: no.
