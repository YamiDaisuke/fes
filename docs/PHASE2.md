# Phase 2

What comes after M3: many Lua files per cart, a cart shelf, a pixel-art "physical device" look, an optional CRT filter, a manual, and the fixes a review of the code turned up. Written on 2026-11-14 against `main` at T22, with T23–T26 in the pipeline.

This file is the task text and the design head start for milestones M9–M14. `docs/PLAN.md` lists the tasks and their order; the issue for each task copies its section from here. The architect still writes the implementation guide per task (`docs/WORKFLOW.md`), but should only need to confirm what is written here against the code as it is then, not design from scratch. Where this file and the code disagree, the code is right: say so in the guide.

## How to use this file (for the orchestrator and the architect)

1. Phase 2 starts when T26 is `stage:ready`. Its first PR adds nothing but issues: create milestones M9–M14 and one issue per task below (title `T27 Boot when localStorage throws`, body = the task's section).
2. Run order is M9, M10, M11, M12, M13, M14, then the old outlines M4–M8. Reasons: the fixes are cheap and one of them (T29) changes how tests drive frames; `require` must exist before Teal (M7); the shelf and the file tabs add UI that the restyle then covers once; the map editor and tracker (M4, M5) are then built in the new look instead of being restyled later.
3. Every task keeps the repo rules in `CLAUDE.md`: Swift owns state, no comments, tests that can catch a real bug, ~300 changed lines, DEBT lines for shortcuts, a decision record for anything worth remembering. Decision records continue from the highest number in `docs/decisions/`.
4. A task marked **Ask the owner** opens with a `needs-input` question (WORKFLOW → Asking the owner). The recommendation given here is the default to offer.
5. Tasks touching `web/index.html`, `Sources/App/ArtView.swift` or `web/tests/art.spec.js` conflict easily with each other. Keep them in the order given; never run two of them in parallel.

## Owner decisions

These are the owner's to take. Each has a default so work is never blocked: the first task that needs one asks, and uses the default if the run is unattended and the question is still open when everything else is done.

| # | Decision | Default | Asked in |
|---|---|---|---|
| 1 | Run Phase 2 before M4–M8? | Yes, in the order above | before T27 |
| 2 | Boot into the shelf instead of the running demo | Yes | T41 |
| 3 | Fonts: which two, and approving them as vendored dependencies | Chrome: Pixel Operator 8. Code: Print Char 21 (Apple II) | T42 |
| 4 | The color tokens | The table in "The look" | T42 |
| 5 | Code editor screen: C64 indigo, Apple II green or amber | C64 indigo | T46 |
| 6 | CRT filter default | Off | T51 |
| 7 | Manual body text in the pixel font or the system font | Pixel font at 16 px, system font as fallback token | T52 |
| 8 | `docs/API.md` becomes a pointer to the manual | Yes | T53 |

---

# M9 — Groundwork and fixes

Small tasks, each independent unless `Depends` says otherwise. They come first because later milestones lean on them.

### T27 Boot when localStorage throws
Depends: none · Closes issue #73

**Problem.** `web/pwa.js` calls `localStorage.getItem` unguarded in `showInstallHint`. With all site data blocked in Safari every `localStorage` call throws, `startPWA()` throws at the top of `web/boot.js`, and the wasm never loads.

**Do.**
- In `web/pwa.js`, read and write the hint's key inside `try`/`catch`. A failed read counts as "never dismissed"; a failed write is ignored (the hint just hides for this visit).
- Check `web/storage.js`: `readRecoveryCopy`, `writeRecoveryCopy`, `removeRecoveryCopy` already throw to Swift, and `Sources/App/CartRecovery.swift` catches them. Leave those.
- Any later task that adds a `localStorage` key (T51) follows the same pattern. If a second key appears, move the guarded read and write into two small functions in one module instead of repeating the `try`.

**Accept.** A Playwright spec whose init script replaces `Storage.prototype.getItem`, `setItem` and `removeItem` with functions that throw; FES boots and the demo's canvas center pixel is opaque (same check as `web/tests/smoke.spec.js`); the page reports no uncaught error.

### T28 The same text rules for every way a cart arrives
Depends: none · Closes issues #64 and the QA-5 part of #37

**Problem.** A cart file with a leading UTF-8 BOM is accepted from OPFS (`TextDecoder` strips it in `web/storage.js` `readCartFile`) and refused from a `.fes` (`Cart(fesArchive:)`). A lone CR in a tile sheet is reported on the wrong line.

**Decision (record it, amending 013 and 020).** Strip one leading BOM in both paths. Reason: Files-app text editors on iPadOS and Windows add one, and refusing it makes a cart "damaged" for a byte the user can't see. Do it in one place in Swift so OPFS, `.fes` and the recovery copy agree: in `Cart.init(files:)`, drop a leading `\u{FEFF}` from every file's text before parsing. Then make `readCartFile` stop stripping it (`new TextDecoder("utf-8", { fatal: true, ignoreBOM: true })`), so Swift alone owns the rule.
- CR: in `Sources/Storage/TextLines.swift`, refuse the first line that contains `"\r"` (naming that line) before checking the line count, and show the character as `\r` in the message, never raw.

**Accept.** Storage tests: a BOM in each cart file loads from `files` and from a `.fes`; a tile sheet with a lone CR names the line holding it. Don't touch QA-2 and QA-6 of #37; close #37 with a note that they stay as they are.

### T29 Sixty console frames per second on any display
Depends: none · Removes the "One console frame per requestAnimationFrame" DEBT line

**Problem.** `web/boot.js` `drawFrame` runs one console frame per `requestAnimationFrame` callback. A ProMotion iPad with the 60 fps flag off runs carts at double speed; Low Power Mode (30 Hz) runs them at half speed.

**Do (all in `web/boot.js`; the frame loop is JavaScript's job in SPEC).**
- `drawFrame(now)` uses the callback's timestamp. Keep `lastTime` and `owedMs`. Each callback: `owedMs += now - lastTime`, then `framesDue = Math.floor((owedMs + 1) / framePeriod)` with `framePeriod = 1000 / 60`. The `+ 1` ms slack stops a 60 Hz display's timer jitter from alternating 0 and 2 frames.
- Run `instance.exports.frame(...)` `min(framesDue, 4)` times, blit once after the last, subtract what ran. If more than 4 were due (the tab was in the background, a breakpoint), set `owedMs = 0`: never try to catch up.
- `buttonsForFrame()` is read once per console frame, as now, so a tap is seen by exactly one frame.
- When `framesDue` is 0 skip the call and the blit.
- `web/tests/frames.js` `runAnimationFrames` calls each queued callback with `performance.now()`. Change it to pass a synthetic clock that advances exactly `1000 / 60` per call, so "one callback is one console frame" stays true for every existing spec. Add `runAnimationFramesAt(count, periodMs)` only if the new tests need it.

**Accept.** Playwright, with the paused harness: 120 callbacks spaced 8.33 ms advance a counting cart by 60 frames (±1); 30 callbacks spaced 33.3 ms advance it by 60 (±1); one callback after a 5-second gap advances it by at most 4. A counting cart: `n = 0 function _update() n = n + 1 end function _draw() cls() spr(0, n % 192, 0) end` and read the sprite's column from the canvas, the way `web/tests/display.spec.js` reads pixels.

**Pitfall.** `Budgets.wallTimePerPeriod` (250 ms) is per console frame and unaffected.

### T30 A stylesheet file and a generated offline file list
Depends: none

**Problem.** All CSS is a `<style>` block in `web/index.html`; M12 will grow it several times over. `web/sw.js` lists the precached files by hand, so every new asset (fonts, the manual, UI images) is one forgotten line away from breaking offline use.

**Do.**
- Move the `<style>` block to `web/style.css`, linked from `index.html`. No rule changes in this PR.
- `scripts/build.sh`: copy `style.css`. After everything is in `web/dist/`, build the list of files there (every file except `sw.js`, as paths relative to `dist`, plus `"./"`, with `index.html` left out because `"./"` is it) and substitute it for a `PRECACHE_FILES` token in `sw.js`, next to the existing `BUILD_VERSION` substitution. `sw.js` then reads `const files = PRECACHE_FILES;`.
- Keep the version hash computed over the same files, as now.

**Accept.** `web/tests/offline.spec.js` still passes, extended to assert that `style.css` is served offline. A build with an extra file dropped into `web/` and copied by `build.sh` precaches it with no edit to `sw.js` (checked by the manual task later; here the generated list in `web/dist/sw.js` is asserted to contain every file in `dist`, by a small Node check run in CI after the build, or inside the offline spec).

### T31 One storage operation at a time
Depends: none

**Problem.** In `Sources/App/SavedCarts.swift` every save, load and import is its own `Task`. Double-tapping Save runs two `writeCart` calls into the same files at once. Tapping a cart in the list while a save is in flight lets `openCart` run first and the save then sets `lastSavedCart = saving`, so the newly opened cart shows as unsaved (or worse, unsaved edits show as saved).

**Do.** One serial queue for cart storage work, in `SavedCarts.swift`:

```swift
nonisolated(unsafe) private var lastStorageTask: Task<Void, Never>?

func afterEarlierStorageWork(_ work: @escaping () async -> Void) {
    let earlier = lastStorageTask
    lastStorageTask = Task {
        await earlier?.value
        await work()
    }
}
```

Route `saveCart`, `loadCart`, `importCart`, and later delete, duplicate and new (M11) through it. Export stays outside (it must run inside the click, see the comment in `ExportAndImport.swift`).

**Accept.** Playwright (persistent context, like `web/tests/storage.spec.js`): click Save twice without waiting, reload, the cart loads and equals what was saved; click Save then immediately a different cart in the list, and the status ends as "Loaded …" with no unsaved prompt on the next load.

---

# M10 — Many Lua files

A cart's code becomes `main.lua` plus any number of other `.lua` files, loaded with `require`. SPEC already describes `require` as "a custom searcher over cart files: `name.tl`, then `name.lua`"; this milestone builds the `.lua` half so M7 only adds `.tl`.

## Design

- **Model.** `Cart` gets `codeFiles: [CodeFile]`, where `struct CodeFile: Equatable { var name: String; var text: String }`. `main.lua` is always present and first; the rest are sorted by name. Keep `mainLua` as a computed property over `codeFiles[0].text` until T35 removes its last user.
- **File names.** Flat, no folders. A code file name is a stem of 1–32 characters from `a–z`, `0–9`, `_`, not starting with a digit, plus `.lua`. Lower case only, because an exported cart may be unzipped on a case-insensitive file system and because the stem is the module name. At most 32 code files. One function, `codeFileNameProblem(_ name: String) -> String?`, in `Storage`, is the single place these rules live (same shape as `nameProblem`).
- **No manifest.** The code files of a cart are whichever of its files have valid code file names. `cart.json` does not list them: the hand-written JSON parser (`Sources/Storage/JSON.swift`) has no arrays, a list could disagree with the folder, and the order is fixed by the sort anyway. The cost is that a deleted file must be removed from OPFS on save (T33).
- **Format 3.** `cart.json` writes `"format": 3`. Formats 1 and 2 load unchanged (they have only `main.lua`). An older FES refuses a format 3 cart with the existing "made with a newer FES" message, which is what we want for a cart that calls `require`.
- **`require(name)`.** `name` is the stem: `require("player")` runs `player.lua` once and returns what its chunk returns, or `true` if it returns nothing. Later calls return the same value without running it again. The chunk receives `name` as its one argument, as in standard Lua. Chunk name is `=player.lua`, so errors read `player.lua:12: …`. `require("main")` is an error. A file that requires itself, directly or through others, is an error: `player.lua:1: module 'enemy' is still loading (circular require)`. A missing module: `main.lua:3: module 'plyer' not found: this cart has no file plyer.lua`. No `package` table.
- **Budgets.** Required chunks run inside whichever budget period called them (usually main chunk + `_init`). Nothing new to meter.
- **Editor.** One CodeMirror view. A tab strip above it lists the files. JavaScript keeps one `EditorState` per file name, so undo history and scroll position survive switching tabs; this is view state, as decision 015 already allows for the single document. Swift owns the texts, which file is shown, and every add, rename and delete.

### T32 Code files in the cart
Depends: T28

**Files.** `Sources/Storage/Cart.swift`, `CartFiles.swift`, `CartArchive.swift`, `RecoveryCopy.swift`; tests in `Tests/StorageTests/`.

**Do.**
1. Add `CodeFile`, `Cart.codeFiles`, the computed `mainLua`, `codeFileNameProblem`, and `Cart.largestCodeFileCount = 32`.
2. Add mutators on `Cart` that keep the invariants (main first, others sorted, names valid and unique), each returning a problem string or `nil`: `addCodeFile(named:)`, `renameCodeFile(_:to:)`, `removeCodeFile(named:)`. Renaming or removing `main.lua` is refused.
3. `Cart.fileNames` (static) is used by `CartArchive.swift`, `RecoveryCopy.swift` and `Sources/App/SavedCarts.swift`. Rename it to `Cart.fixedFileNames` (everything except code files other than `main.lua`) and add an instance `fileNames` = fixed names followed by the other code files. `files` returns every code file.
4. `Cart.init(files:)`: `main.lua` is required as now. Every other key with a valid code file name becomes a code file, its line endings normalised like `main.lua`'s. A key that ends in `.lua` (any case) but is not a valid name is refused: `Player.lua: code file names use a–z, 0–9 and _, such as player.lua`. More than 32 is refused. Other unknown keys are ignored, as now.
5. `formatVersion` becomes 3.
6. `fesArchive` writes `cart.fileNames` in order. `Cart(fesArchive:)` takes every entry that is a fixed name or a valid code file name; an entry whose path ends in `.lua` but isn't one (a folder prefix, upper case) is an `ArchiveError` naming it, extending the existing `cartFileUnzippedInPlace` check rather than adding a second mechanism.
7. `RecoveryCopy.text` iterates `cart.fileNames`. Reading already goes through `Cart(files:)`. A copy written before this task has only the fixed files and still restores.

**Tests worth writing.** Name rules (table of good and bad names); round trip of a three-file cart through `files`, through a `.fes`, and through a recovery copy; `main.lua` first and the rest sorted whatever the input order; refusals for a bad `.lua` name, 33 files, a duplicate after rename, removing `main.lua`; a format 2 fixture still loads and saves as format 3; a format 3 cart refused by nothing here (the "newer FES" path is already tested).

**Out of scope.** Anything in `App` beyond what is needed to compile (`Cart.fileNames` call sites switch to `cart.fileNames`/`Cart.fixedFileNames`; behaviour for extra files comes in T33).

### T33 Save, load and import carts with many files
Depends: T32, T31

**Files.** `web/storage.js`, `Sources/App/SavedCarts.swift`, `web/tests/storage.spec.js`, a new fixture `.fes`.

**Do.**
1. `web/storage.js`: add `listCartFiles(folder)` (names of the files in the folder) and `removeCartFile(folder, name)` (`removeEntry`; a missing file is not an error).
2. `readSavedCart(folder:)`: list the folder, read each file that is in `Cart.fixedFileNames` or ends in `.lua`, hand the lot to `Cart(files:)`. Passing bad `.lua` names through lets `Cart(files:)` report them instead of hiding them.
3. `writeCart(_:folder:)`: write every file, `cart.json` last as now, then remove `.lua` files in the folder that the cart no longer has. Removal comes after `cart.json` so an interrupted save never loses a file the saved cart still needs. A failed removal shows a status but does not fail the save.
4. Import and export need no change beyond T32, but check `ExportAndImport.swift` compiles and the 8 MiB check still runs on the whole archive.

**Accept.** Playwright (persistent context): import a fixture `.fes` holding `main.lua` and `player.lua`, load it, save it, reload the page, load it again, export it, and the exported archive has both files with the same bytes. Until T36 there is no UI to delete a file, so step 3's removal is covered there.

**Fixture.** Make the `.fes` the way `Tests/StorageTests/Fixtures/made-by-zip.fes` was made (`zip -0`), and say so in the PR.

### T34 require
Depends: T32

**Files.** `Sources/Runtime/RunningCart.swift`, `MainLua.swift` (rename to `CodeFiles.swift` if little of "main" is left), `Sandbox.swift` or a new `Require.swift`, `Sources/App/CodeAndGameViews.swift`, `Sources/App/CodeDiagnostics.swift`, tests in `Tests/RuntimeTests/`.

**Do.**
1. `Runtime` does not depend on `Storage` (see `Package.swift`), so `RunningCart.init` takes plain values: `init(mainLua: String, modules: [String: String] = [:], ppu: PPU = PPU())`, where the key is the stem. `App` builds `modules` from `cart.codeFiles.dropFirst()`.
2. Register a global `require` as a C closure with the cart as upvalue, the way `registerConsoleAPI` does. Keep the loaded-modules table in the Lua registry under a fixed key. Steps inside it: check the argument is a string; return the cached value if there is one; raise the circular error if the entry is the "loading" marker; find the source; load it with `luaL_loadbufferx(…, "=name.lua", "t")`; mark as loading; call it with the name; store the result (or `true`); return it.
3. **The longjmp rule (decision 011, and the comment at the top of `ConsoleAPI.swift`).** A Lua error longjmps past Swift frames and skips their releases. So: no Swift `String`, array or class reference may be alive across a call that can raise (`lua_callk`, `lua_error`, `luaL_error`). Do the lookup and the load in a helper that returns only a status code with every Swift value already gone, push error text onto the Lua stack before returning, and only then, from a frame that holds nothing, call or raise. `Sandbox.swift`'s `setmetatableWithoutFinalizers` shows the `luaL_where` + `lua_concat` + `lua_error` pattern for an error with a position.
4. A load error in a required file raises a normal Lua error carrying Lua's message (`player.lua:4: unexpected symbol near '='`), so it reaches the cart's error screen through the existing path.
5. `syntaxError(inMainLua:)` becomes `syntaxError(inLua:named:)`. `mainLuaLine(inError:)` becomes `codePosition(inError:files:) -> (file: String, line: Int)?`: the first line of the message or traceback that starts with `<a cart file name>:<digits>:`. Update the two callers in `App` to keep today's behaviour for `main.lua` (file tabs come in T35).
6. `docs/API.md`: add `require`, and a short "Many files" section.

**Tests worth writing.** A module's return value arrives; a module runs once across two `require`s (count a global); no return value gives `true`; the name argument arrives; missing module error text and line; circular require (direct and through a second file) is an error and not a hang; a runtime error inside a module names `player.lua` and its line; a syntax error in a module does the same; `require` of a non-string; the CPU budget stops an endless loop in a module's top level; `codePosition` picks the module's file from a traceback that also contains `main.lua` lines.

**Skip.** Tests that `require` exists or that `package` is nil (the sandbox test already covers globals).

### T35 File tabs in the code editor
Depends: T33, T34

**Files.** `web/code-editor.js`, `web/index.html`, `web/style.css`, `Sources/App/CodeAndGameViews.swift`, `CodeDiagnostics.swift`, a new `Sources/App/CodeFileTabs.swift`, `web/tests/`.

**Do.**
1. `web/code-editor.js`: replace `setCode(doc)` with `openFile(name, text)` and add `forgetFiles()`. Keep a `Map` from name to `EditorState`. `openFile` reuses the stored state when its document equals `text`, otherwise makes a fresh one; either way it stores the state of the file being left first. The `aria-label` content attribute becomes the file name, so make the extensions a function of the name. `forgetFiles()` empties the map; Swift calls it when another cart opens.
2. HTML: a `<div id="code-files" role="tablist" aria-label="Code files">` above `#code-editor`. Swift fills it with one `<button role="tab" aria-selected data-file="player.lua">` per file, the way `refreshCartList` builds the cart list.
3. Swift: a global for the shown file's name. A tab click stores it and calls `openFile`. `codeChanged` writes to that file's text in `cart.codeFiles`. Opening a cart shows `main.lua`.
4. Diagnostics: on change, check the shown file (the 500 ms timer stays). On Run, check every file and show the first problem. `showRuntimeErrorInCode` switches to the file `codePosition` names, then moves the cursor. `#code-error` shows the message with its file name; the CodeMirror diagnostic is set only when the error's file is the one shown.
5. Remove `Cart.mainLua` if nothing uses it now.

**Accept.** Playwright, on a two-file fixture cart: tapping the `player.lua` tab shows its text; typing there, switching to `main.lua` and back keeps the text and one Cmd+Z undoes only that file's last edit; a runtime error raised in `player.lua` lands on the Code view with the `player.lua` tab selected and the cursor on the line; a syntax error typed into `player.lua` shows as a diagnostic there within a moment; Save, reload, load keeps both files.

**Pitfall.** `web/tests/code-editor.js` and several specs type through CodeMirror or call `fesCodeEditor`; keep them working by updating that helper, not each spec.

### T36 Add, rename and delete code files
Depends: T35

**Do.**
- Three buttons at the end of the tab strip: New file, Rename, Delete. Rename and Delete are disabled while `main.lua` is shown.
- Names are asked with `window.prompt` and deletes confirmed with `window.confirm`, like the existing unsaved-changes prompt. Add a DEBT line: native dialogs, replaced in T45.
- The user types the stem; `.lua` is added if missing, the text is lower-cased, and `codeFileNameProblem` or the mutator's problem string is shown in `#cart-status` (for example `Can't add player.lua: this cart already has it`).
- A new file opens empty and is shown. Renaming keeps the text, drops that file's stored editor state under the old name, and does **not** rewrite `require` calls in other files; the manual says so. Deleting shows `main.lua`.
- Each change calls `keepRecoveryCopy()` and marks the cart unsaved through the existing `cart != lastSavedCart` comparison.

**Accept.** Playwright: add `enemy.lua`, type a module, `require` it from `main.lua`, run and see its effect; rename it and the old `require` fails with the "not found" message; delete it, save, reload, and the file is gone from the loaded cart and from the OPFS folder (covers T33 step 3); a bad name and a duplicate name each show their message and change nothing; an unsaved added file comes back from the recovery copy after a reload.

---

# M11 — The cart shelf

Picking a cart becomes a full-screen view, like PICO-8's SPLORE: every saved cart is a cartridge with a label picture, chosen with the D-pad, a finger or the keyboard. It replaces the list in the Code view's side panel, and adds what that list never had: new, duplicate and delete.

## Design

- **A fourth view, `shelf`.** `ShownView` gets a case; `body[data-view="shelf"]`; a toolbar button "Carts" (`#show-shelf`).
- **Entries are buttons.** `#shelf-list` is a list of `<button data-folder="…">`, one per saved cart, plus a first entry for the built-in demo (`data-folder=""`). Tapping selects (`aria-pressed`); it does not load. This keeps VoiceOver and the keyboard working and gives delete a target.
- **Actions on the selected cart.** Play (load and run), Edit (load and show the code), Duplicate, Delete, Export. And two that need no selection: New cart, Import. Loading still asks before discarding unsaved changes.
- **Where the old panel's controls go.** The cart list, Import and Export move to the shelf. The cart name field stays in the Code view, in a row above the editor next to the file tabs, because Save reads it.
- **Labels.** A cart may carry a label: a 192×144 picture captured from the running game with a button, like PICO-8's F7. It is stored as a text file, `label.hex`, so carts stay text-based: 144 lines of 384 hex digits, two per pixel, each a main palette index `00`–`3f`. The file is optional; a cart without one shows a blank cartridge with its name. Indices, not RGB, keep the file small (55 KB) and make the label follow the cart's palette.
- **Swift renders, JS blits.** Each entry holds a `<canvas width="192" height="144">`; Swift turns the label and the cart's main palette into RGBA and JS blits it with the existing `fesArtView.blit`.
- **Reading the shelf must be cheap.** For each folder read only `cart.json`, `label.hex` and `main-palette.hex`, not the whole cart.

### T37 Shelf view
Depends: T36 (for the Code view row), T31

**Files.** `web/index.html`, `web/style.css`, `Sources/App/ShownView.swift`, `SavedCarts.swift` (split the list out into `Sources/App/Shelf.swift`), `ExportAndImport.swift`, most storage-using specs.

**Do.**
1. Add the view, the toolbar button and the markup: `<section id="shelf-view" aria-label="Carts">` with `#shelf-list` and a `role="group"` of action buttons (`#shelf-play`, `#shelf-edit`, `#shelf-export`, `#shelf-import`).
2. Move `refreshCartList` and the list click handling to `Shelf.swift`. Selection is Swift state (the selected folder). Play and Edit are disabled with nothing selected.
3. Play = today's `loadCart` followed by `runCart()`. Edit = `loadCart` followed by `showCodeView()`. The demo entry opens a fresh `demoCart()` with `cartFolder = nil`.
4. Export exports the **selected** cart read from OPFS (not the open one); the Code view keeps no Export button. Import stays as it is and refreshes the shelf.
5. Remove `#carts` from the Code view; put `#cart-name` and its label in the new row above the editor. The Code view's grid loses its 240 px column.
6. Tests: add a helper in `web/tests/` (`openShelf(page)`, `loadCartFromShelf(page, name)`) and move every spec that clicks `#cart-list` to it. Six specs use the list today: `recovery`, `palette-editor`, `storage`, `main-colors`, `art`, `export-import`.

**Accept.** The existing storage, recovery and export/import specs pass through the shelf; a new spec selects a cart, taps Play, and the game view shows that cart running; Edit shows its code.

### T38 New, duplicate and delete carts
Depends: T37 · Removes the two DEBT lines about "Damaged cart" folders that can't be deleted

**Do.**
- `web/storage.js`: `removeCartFolder(folder)` (`removeEntry(folder, { recursive: true })`).
- **New cart**: after the unsaved-changes prompt, opens a blank cart named "New cart" with `cartFolder = nil` and this `main.lua`, and shows the Code view:

  ```lua
  function _init()
  end

  function _update()
  end

  function _draw()
    cls()
  end
  ```

- **Duplicate**: reads the selected cart whole, names the copy `<name> copy` (cut to fit the 64-character limit), writes it to a new folder, refreshes the shelf and selects the copy.
- **Delete**: confirm naming the cart (`Delete Space Cats? This can't be undone. Export it first if you want a backup.`), remove the folder, refresh. If it was the open cart, open the demo cart afterwards. "Damaged cart" entries can be deleted too; Play, Edit, Duplicate and Export are disabled for them.
- All three go through `afterEarlierStorageWork` (T31).

**Accept.** Playwright: new cart, type, save, it appears on the shelf; duplicate it and both load with equal content; delete one, reload the page, only the other is listed; a folder with no `cart.json` (written by the test through `fesStorage.writeCartFile`) shows as damaged and can be deleted.

### T39 Cart label
Depends: T32

**Files.** new `Sources/Storage/CartLabel.swift` and `LabelText.swift`, `Cart.swift`, `CartFiles.swift`, `Sources/App/Frame.swift`, `web/index.html`; Storage tests.

**Do.**
1. `struct CartLabel: Equatable` holding 192×144 main palette indices (`[UInt8]`, row-major). `Cart.label: CartLabel?`.
2. `label.hex` text: write and parse in the style of `TileSheetText.swift` (use `textLines(_:count:file:)`; errors name file, line and column). Optional on read in every format; written only when the cart has a label. Add it to the fixed file names as an optional one: `files` omits it when `label` is nil, and `Cart(files:)`, the archive and `readSavedCart` must not treat its absence as "file is missing".
3. `CartLabel(framebuffer:mainPalette:)`: each RGBA pixel becomes the index of the equal main palette color, or of the nearest (smallest sum of squared channel differences) when none is equal, which will happen once M8 adds blending.
4. A "Set label" button, shown in the game view only. It captures the last rendered frame (`framebuffer` in `Frame.swift` is private: add a function there that returns the label, rather than exposing the buffer), stores it in `cart.label`, calls `keepRecoveryCopy()` and shows `Label set. Save to keep it.`

**Tests worth writing.** Round trip; each refusal (line count, line length, a digit pair over `3f`, a non-hex character) with its position; a cart without the file loads with `label == nil` from `files` and from a `.fes`; exact colors map to their index and an off-palette color maps to the nearest; when two palette entries hold the same color the lower index wins (so the round trip is stable).

**Measure.** The recovery copy is rewritten on every keystroke (`keepRecoveryCopy`), and the label adds 55 KB to it. Time `RecoveryCopy.text` plus the `localStorage` write on the iPad preview with a labelled cart and report it in the PR. If it is over 4 ms, stop and raise it: the fix (write the label under its own key only when it changes) is its own task.

### T40 Labels on the shelf and D-pad selection
Depends: T38, T39

**Do.**
- Each shelf entry: a button holding a canvas (the label, or left blank) and the cart's name. Reading an entry reads only `cart.json`, `label.hex`, `main-palette.hex`; a bad label or palette shows the blank cartridge, not "damaged".
- A Swift function renders a `CartLabel` with a `MainPalette` to RGBA (`RGBAImage` in `Editors` already exists for this). Golden test of one rendered label.
- D-pad: in the shelf view `frame()` still receives the button bitmask. Use `Input`'s pressed-this-frame edge: Left and Right move the selection (stopping at the ends), A plays, B edits. The selected button gets `focus()` and `scrollIntoView({ block: "nearest", inline: "nearest" })`. `web/input.js` already sends arrow keys as controller buttons unless a text field has focus, so the keyboard works the same way with no new key handling.
- The demo entry shows a label rendered from the demo's first frame, produced once at build or checked in as `label.hex` text in `Runtime/DemoCart.swift`'s style; pick whichever is less code.

**Accept.** Golden test for label rendering; Playwright: set a label in a running cart, save, open the shelf, and the entry's canvas center pixel equals the game canvas's at capture time; Right, Right, A with the keyboard runs the third cart.

### T41 Boot into the shelf
Depends: T40 · **Ask the owner** (decision 2)

**Do.**
- `<body data-view="shelf">`, `shownView = .shelf` initially. The demo no longer runs until chosen.
- Specs boot their own code through `window.testCartMainLua` (see the DEBT line). When it is set, boot into the game as today, so the specs don't each grow a shelf step. Update that DEBT line to say so.
- The restore prompt (`offerRecoveryCopy`) still shows the Code view after a restore.
- `web/tests/smoke.spec.js` becomes: boots to the shelf with no console errors, Play on the demo draws to the canvas.

**Accept.** The smoke spec above; every other spec unchanged.

---

# M12 — The device look

The owner's brief: pixel art everywhere; it should feel like operating a physical device, with controls that look like real ones (brutalism, Star Wars ship consoles, old Game Boys and handhelds); colorful but easy on the eye, high-contrast pastels; a legible 8 px font that is not PICO-8's; the code editor like an Apple II or Commodore screen.

## The look

This section is the design system. T42 turns it into CSS tokens and proves the risky parts on an iPad; the tasks after it apply it view by view. The owner is a pixel artist and will tune it: everything visual must be a token or a small text grid that is easy to change, never a value repeated through the stylesheet.

### Rules

1. **One UI pixel.** `--u: 2px`. Every length in the chrome is a whole number of `--u`: `calc(22 * var(--u))`, never `44px` or `0.5rem`. Borders are `1u` or `2u`. Text is the 8 px font at `8u` (16 CSS px).
2. **Nothing soft.** No `border-radius`, no blurred `box-shadow`, no smooth gradients, no opacity fades, no `transition` except `steps()`. Rounded things are stepped: corners are notched with `clip-path: polygon(...)` by `1u` or `2u`.
3. **Depth is drawn with flat bands.** A raised key is: a `1u` ink outline, a `1u` highlight band along the top and left, a `1u` shade band along the bottom and right (both `box-shadow: inset` with zero blur), and a `2u` "skirt" in the darker tone below it. Pressed: the face moves down `1u` and the skirt shrinks to `1u`. Recessed things (the screen, text fields, readouts) are the reverse: shade top-left, highlight bottom-right.
4. **No art files for surfaces.** Plates, keys, switches, fields and LEDs are CSS built from rules 2 and 3, so they scale and recolor from tokens. Image files are used only for icons (T48) and the app icon (T50), generated from text grids by a script like `scripts/make-icons.js`.
5. **It is still an app for fingers and VoiceOver.** Every control stays a real `<button>`, `<input>` or `<a>` with its label. Touch targets stay at least `22u` (44 px). Focus is a `1u` ink + `1u` butter double outline, drawn with `outline`, never removed. Decorations (screws, grilles, badge) are `aria-hidden` pseudo-elements or elements. `prefers-reduced-motion` turns off the blink and the boot animation. Nothing in CLAUDE.md's "never cut accessibility of the editor UI" is relaxed.
6. **Text inputs stay at 16 CSS px or more**, which `8u` is. Safari zooms the page when a smaller field takes focus.
7. **Canvases are untouched.** The game screen and the Art view's canvases keep `image-rendering: pixelated` and integer scaling.

### Color tokens (decision 4: the owner tunes these)

Pastel surfaces, one dark ink. Computed WCAG contrast: ink on the shell and on every bright pastel is between 8.7:1 and 14:1, and the readout pair is 9.2:1. Text never sits on a `-dark` or `-deep` tone (ink on those is 5–6.5:1): they are for bands, skirts and grooves only.

| Token | Value | Use |
|---|---|---|
| `--ink` | `#2a2438` | text, outlines, icons |
| `--shell` | `#cfc6e0` | the device body (lilac grey) |
| `--shell-light` | `#ece7f5` | highlight band on the body, plates |
| `--shell-dark` | `#a79bc4` | shade band, skirts |
| `--shell-deep` | `#7a6e9a` | deepest shade, grooves, the speaker grille |
| `--well` | `#3a3350` | recessed areas: screen bezel, field backgrounds on dark |
| `--screen-off` | `#1c1a26` | behind the game canvas |
| `--mint` / `--mint-dark` | `#a8e6cf` / `#6dba9b` | go: Run, Play, Save |
| `--coral` / `--coral-dark` | `#ffb3a7` / `#d6857a` | stop and destroy: Delete, errors, the A button |
| `--butter` / `--butter-dark` | `#ffe9a8` / `#d6ba68` | selection, pressed toggles, focus, the B button |
| `--sky` / `--sky-dark` | `#a9d8f5` / `#74a8cc` | navigation: view switches, tabs, links |
| `--pink` / `--pink-dark` | `#f7b7d8` / `#cc85aa` | accents: Start/Select, badge |
| `--readout` / `--readout-ink` | `#2e3b34` / `#b9f0cf` | the status readout (LCD) |
| `--led-on` / `--led-error` / `--led-off` | `#7dffb0` / `#ff6b6b` / `#5a5470` | LEDs |
| `--paper` | `#fff8e7` | label tape, cartridge labels, manual page |

Color never carries meaning alone: a pressed toggle is also physically down and has a lit LED dot; an error has text.

### Type (decision 3: **new dependencies, the owner approves**)

Fonts are vendored files, so each needs a decision record and the owner's yes (CLAUDE.md → Dependencies). Candidates, with what must be checked before vendoring. The license notes below come from a web search on 2026-11-14 and are leads, not proof: T42 reads each font's own license file and vendors that file next to the font.

| Role | Recommendation | Why | Alternatives | Check |
|---|---|---|---|---|
| Chrome (labels, buttons, status) | **Pixel Operator 8** by Jayvee Enaguas | Drawn on an 8 px grid, proportional, mixed case, clear at 16 px; reported CC0 | Silkscreen (OFL; caps only), Press Start 2P (OFL; wide, eats space), m5x7 by Daniel Linssen | The author's readme confirms CC0 for the `8` variants |
| Code editor | **Print Char 21** by Kreative Korp (the Apple II 40-column character set) | It is the Apple II font, monospaced, 7×8 cells, mixed case | Pet Me 64 (the Commodore 64 set, same foundry), Departure Mono by Helena Zhang (OFL, confirmed; an 11 px grid, so 22 px text) | Whether the file is under the OFL in `kreativekorp/open-relay` or under Kreative's separate Free Use License, which has its own redistribution terms |

Rules for using them: only sizes that are whole multiples of the design grid (8, 16, 24 px for 8 px fonts); `@font-face` with `font-display: block`; WOFF2 files in `web/fonts/` with their license files; precached (T30 makes that automatic); a system monospace fallback in the stack so text never disappears. `-webkit-font-smoothing` does nothing on iPadOS, so crispness depends on whole-pixel sizes and positions, which is what T42 proves.

### Components

Each is a class in `style.css`, written once.

- **Plate** (`.plate`): a raised panel that groups controls, with a `1u` outline, light and shade bands, and optional corner screws (`::before`/`::after`, a 3u square with a 1u slot).
- **Key** (`.key`, the default for `button`): rule 3. Variants by token: `.key-go` (mint), `.key-stop` (coral), `.key-nav` (sky). Disabled: flat, no skirt, ink at the shell-deep tone, still readable.
- **Toggle** (`button[aria-pressed]`): a key that stays down when pressed, face in butter, with a `2u` LED dot in its top-right corner (`--led-off` → `--led-on`).
- **Switch row** (`[role="group"].switches`): toggles joined edge to edge in one recessed slot, for one-of-many choices (view, bank, tool, block size, palette).
- **Readout** (`.readout`): recessed dark-green LCD strip with pale mint text, for `#cart-status` and other one-line states.
- **LED** (`.led`): a 3u square with a 1u outline; on, off or error.
- **Field** (`input[type="text"]`, `.field`): recessed, paper background, ink text, block caret color.
- **Fader** (`input[type="range"]`): a recessed groove with a key-shaped thumb (`::-webkit-slider-thumb`, `appearance: none`).
- **Swatch** (`.swatches button`): a recessed square of the color; selected is a `1u` ink + `1u` butter double outline; the transparent swatch keeps its checker, in tokens.
- **Tab** (`[role="tab"]`): a key with no skirt whose selected state joins the surface below it.
- **Label tape** (`.tape`): paper strip with a stepped torn end, for notices.
- **Dialog** (`dialog`): a plate with a sky title strip, over a flat `--ink` at 60% backdrop (the one allowed translucency).
- **Cartridge** (`.cartridge`): T49.

### The device

In every view the page is the face of one machine: the shell color fills the viewport, a top "control deck" plate holds the view switches, the transport keys (Run, Save) and the status readout, and the rest is that view's panel. Landscape is the primary orientation; portrait must work without scrolling the page.

### T42 Look foundation: tokens, type, the pixel grid
Depends: T41, T30 · **Ask the owner** (decisions 3 and 4) · a spike: it exists to prove the fonts stay crisp in Safari on an iPad before five more tasks build on them

**Do.**
1. Ask the owner the font and color questions, with a picture: a PR preview page (step 4) is the way to show the choices.
2. Vendor the two fonts as WOFF2 in `web/fonts/` with license files. `scripts/build.sh` copies the folder. Decision record: which fonts, their authors, licenses and source URLs, the rule about whole-multiple sizes.
3. `web/style.css`: the tokens above on `:root`, `--u`, the two `@font-face` rules, `--font-ui` and `--font-code` stacks, and the component classes from "Components" (they can be applied to nothing yet).
4. A static page `web/look.html` (copied by the build, linked from nowhere in the app) that shows every component in every state, both fonts at 16 and 24 px, and the token swatches with their names. It is the owner's proofing sheet and QA's reference; it stays in the repo.
5. On the iPad preview, QA checks at 100% zoom that the fonts have no grey edges (compare a screenshot at 2× against the font's own pixels) in landscape and portrait, and reports with screenshots. If text is blurry where an element sits at a half pixel, find the cause (usually centering with `place-items: center` or a percentage width) and write the rule that avoids it into the decision record.
6. If the fonts can't be made crisp: stop, and put the fallback to the owner (larger whole multiples only; or text drawn into canvases by Swift for the few fixed labels, which costs accessibility and is the last resort).

**Accept.** A Playwright spec on `look.html`: every token pair listed as text-on-surface in the table above has a WCAG contrast ratio of at least 7 (compute it in the spec from the computed colors, so retuning a token can't silently break legibility); every `.key` on the page is at least 44×44 CSS px; `document.fonts.check` is true for both families. The app itself looks the same as before this PR.

### T43 The control deck
Depends: T42

**Do.**
- Body background becomes `--shell`. `#toolbar` becomes the deck: a plate across the top holding, left to right: a switch row for the views (Carts, Code, Art, Game; today's `#show-code` and `#show-art` are hidden in their own view, which stops; they become toggles with `aria-pressed`, driven by `show(_:)` in `ShownView.swift`), then Run (`.key-go`) and Save, then `#cart-status` as a readout that takes the remaining width.
- A power LED at the deck's left end: on while a cart is running without error, error color when `runningCart.error` is set, off in the shelf. Swift sets a `data-led` attribute on `body`; CSS colors it. Decorative, `aria-hidden`.
- Notices (`#install-hint`, `#update-notice`) become label tape under the deck. Their text and behaviour don't change.
- The readout cuts long messages with an ellipsis but keeps the full text for VoiceOver (`role="status"` stays; add `title`).

**Accept.** Playwright: each view switch shows its view and is the only one with `aria-pressed="true"`; the Game switch shows the game without restarting the cart (today only Run reaches the game view: a new `gameClicked` that calls `show(.game)`); the LED attribute is `error` after a cart error; at 1194×834, 1133×744 and 834×1194 the deck is one row and the page doesn't scroll.

### T44 Screen bezel and controller
Depends: T43 · Removes the two DEBT lines about the touch overlay

**Do.**
- The game canvas sits in a recessed bezel (`--well`), stepped corners, with a small "FES" badge and the LED mirrored under it. `fitCanvas` in `web/boot.js` must fit the canvas inside the bezel's inner box; keep integer scaling.
- The pad becomes hardware: a one-piece cross D-pad (stepped, with a center dimple), A (coral) and B (butter) as stepped-round keys set on a diagonal like a Game Boy, Start and Select as small slanted pink pills. All are raised keys that visibly go down while held: `web/input.js` sets `data-held` on the pressed elements from `pointerButtons`, and CSS uses that (`:active` doesn't follow a finger that slides between buttons).
- Layout: in landscape the D-pad and face buttons sit left and right of the screen in the shell, below center, where thumbs rest; in portrait they sit under the screen. They no longer overlap the picture.
- VoiceOver and Switch Control: pad buttons also answer `click` with a short press (held for 6 console frames), so assistive activation works. Remove `tabindex="-1"` only if keyboard focus on them doesn't steal controller keys; `isPageKey` in `input.js` already excludes `#pad` buttons from the Enter rule.
- `#cart-error` becomes a coral plate over the top of the screen with the code font.

**Accept.** `web/tests/input.spec.js` passes unchanged (the D-pad corners still press two directions); a new check that a `click()` dispatched on the A button makes `btnp(4)` true for exactly one frame; the canvas width is still a whole multiple of 192 at the three viewport sizes; the pad does not intersect the canvas's box in any of them.

### T45 Own dialogs instead of confirm and prompt
Depends: T43 · Removes the DEBT line added in T36

**Do.** One `<dialog id="ask">` in `index.html`, styled as the dialog component, and one Swift function that shows it and awaits the answer:

```swift
func ask(_ question: String, confirm: String, cancel: String = "Cancel", textField: String? = nil) async -> String?
```

It returns `nil` on cancel, the field's text (or `""`) on confirm. `showModal()` gives focus trapping and Escape for free. Replace every `JSObject.global.confirm!` and `prompt` in `App` (unsaved changes, restore, delete cart, delete and name file, import confirm from T25). Callers that were synchronous become `async`; they are already inside `Task`s or go through `afterEarlierStorageWork`. Destructive confirms use `.key-stop` and are not the default button.

**Accept.** The recovery, storage and file specs pass with their dialog handling switched from Playwright's `page.on("dialog")` to clicking the dialog's buttons (one helper); Escape cancels; focus returns to the control that opened it.

**Pitfall.** `offerRecoveryCopy` runs at boot before anything else may replace the copy: keep the "read before the first await" order described in `startSavedCarts`.

### T46 The code view as an old computer
Depends: T43 · **Ask the owner** (decision 5)

**Do.**
- A CodeMirror theme in `web/code-editor.js` with `EditorView.theme` and a `HighlightStyle` (from `@codemirror/language`; the tags come from `@lezer/highlight`, which CodeMirror already depends on: add it to `package.json` explicitly, same family as the approved CodeMirror dependency, and say so in the PR).
- Default (C64 indigo): background `#2b2a5c`, text `#d6d4ff`, gutter `#232250` with `#a9a6ee` numbers, active line `#34337a`, selection `#5552b0`. Syntax, all pastel on indigo, each between 7.7:1 and 11:1 (text itself is 9.3:1): keyword `--pink`, string `--butter`, number `--coral`, comment `#9d99d9` (5.0:1, the one exception, and never below 4.5:1), function names and calls `--mint`, operators and punctuation the text color. Alternates to offer: Apple II green (`#0f1a12` / `#7dffb0`) and amber (`#1a1408` / `#ffcc66`), one fixed theme, not a setting.
- A block cursor: `.cm-cursor` as a `1ch`-wide block in the text color with `mix-blend-mode: difference`, blinking with `steps(1)`; no blink under `prefers-reduced-motion`.
- `--font-code` at 16 px, line height 20 px (whole pixels). The lint gutter's marker and tooltip restyled as a coral plate.
- The editor sits in a monitor bezel like the game screen. The file tabs become the tab component, shaped like disk labels; the name field and the file buttons sit in the row above.
- `#code-error` becomes a coral readout under the editor.

**Accept.** The diagnostics and editor specs pass; a spec asserts the editor's computed font family is the code font and its line height is a whole number of pixels; typing with a hardware keyboard still works on the iPad preview (QA).

### T47 Art view layout
Depends: T45, and T26 merged · Removes the three DEBT lines about the Art view scrolling or cutting off (narrow windows, the Pixel group, the palette grids)

The Art view today is three columns with a tools column that scrolls on smaller iPads. Rebuild the layout so nothing scrolls at the sizes we support, then style it.

**Do.**
- Supported sizes, none of which may scroll or clip: 1194×834 and 1133×744 landscape, 834×1194 and 744×1133 portrait. Under 600 px wide (Slide Over) the tools may scroll, and the DEBT line is rewritten to say exactly that.
- Landscape: sheet (left), edit area (center), and tools split into two plates: a narrow tool rail between sheet and edit area (tool, block size, flip, copy, paste, undo, redo, import: icon keys from T48, text keys until then) and a right plate (bank, preview palette, the color strip, the tile fader, the Pixel group). Portrait: edit area on top, sheet and tools below side by side.
- The palette editor panel (`#art-palettes`) uses `16u` swatches with `1u` gaps where the 44 px grid doesn't fit, but each swatch keeps a 44 px hit area through padding on a wrapper or `::after`; verify with the target-size check.
- Sizes of the two canvases are chosen by Swift (`GridLayout`, `ArtView.swift` reads the areas' sizes); check what it reads still exists after the markup moves.

**Accept.** Playwright at the four sizes: `scrollHeight <= clientHeight` for `#art-view`, `#art-tools` and `#art-palettes`; every button in the Art view is at least 44×44; `web/tests/art.spec.js`, `palette-editor.spec.js` and `main-colors.spec.js` pass.

### T48 Art view colors and tool icons
Depends: T47

**Do.**
- `Sources/Editors/ArtPixel.swift` holds the grid, tile-border, selection and checker colors as placeholder greys. Set them from the look: grid `--shell-deep`, tile border `--ink`, selection butter over ink (a 2-pixel ring: ink outside, butter inside), checker in two shell tones. They are Swift constants because Swift draws those pixels; add a line in the decision record that these five mirror the CSS tokens by hand. Re-record the six `Tests/EditorsTests/Golden` images (decision 006 says how).
- Icons: `scripts/make-ui-icons.js`, in the style of `scripts/make-icons.js`: each icon is a 12×12 text grid of `.` and `#`; the script writes one PNG sprite sheet to `web/ui/icons.png`. Icons are shown with `mask-image` (and `-webkit-mask-image`) so they take `--ink`, scaled by a whole number, `image-rendering: pixelated`. Icons for: pencil, picker, fill, flip H, flip V, copy, paste, undo, redo, import, palettes. Every icon key keeps its text as `aria-label` and gets a `title`.
- The generated PNG is checked in (like `web/icons/`), and the script is how it is redrawn.

**Accept.** The re-recorded goldens; `art.spec.js` passes (it finds buttons by role and name, so labels must not change); a check that each icon key has a non-empty accessible name.

### T49 Cartridges on the shelf
Depends: T45, T40

**Do.**
- Each shelf entry becomes a cartridge: a stepped body in one of five pastel tones chosen from the folder name (stable per cart: `folder`'s first hex digit mod 5), a paper label area holding the label canvas at half size (96×72, a whole divisor) or the cart's name in the UI font when there is no label, grip ridges below, and the name on a tape strip.
- The shelf is a horizontally scrolling row of cartridges standing in a slot (a recessed band). The selected one is raised `4u` and outlined with the focus ring. A large preview plate above shows the selected cart's label at an integer scale with its name; under it the action keys (Play mint, Edit sky, Duplicate, Export, Delete coral) and, apart, New cart and Import.
- The empty shelf (no saved carts) says so on tape: `No carts yet. Play the demo or make a New cart.`

**Accept.** The shelf specs pass; at the four sizes the action keys are all visible without scrolling the page; the selected cartridge is scrolled into view after D-pad moves.

### T50 App icon, boot animation and theme color
Depends: T44 · Removes the DEBT line about the placeholder icon if the owner supplies or accepts the art

**Do.**
- `web/manifest.webmanifest` `theme_color` and `background_color`, and `<meta name="theme-color">`, become `--shell`, so the status bar area matches the device.
- A boot animation while the wasm loads and for at most 1 second after: the game bezel shows "FES" assembling in a few stepped frames with the LED blinking, pure CSS `steps()`. Skipped under `prefers-reduced-motion` and when `window.testCartMainLua` is set.
- `scripts/make-icons.js`: redraw the icon grid as the device's face (screen, D-pad, two buttons) in the tokens. It stays placeholder art until the owner draws one; keep the DEBT line unless they say otherwise.
- Sweep: search `style.css` and `index.html` for any remaining `system-ui`, `border-radius`, hex color not in the token table, or length not built from `--u`, and fix or justify each.

**Accept.** The smoke spec still passes with the animation in place (it must not delay the first frame by more than the 1 second, and never blocks input); a spec asserts the manifest's two colors equal the `--shell` token.

---

# M13 — CRT filter

### T51 Optional CRT filter
Depends: T44 · **Ask the owner** (decision 6)

**Decision (record it; it settles SPEC's "move to WebGL … for an optional CRT/LCD shader").** The filter is a CSS overlay above the canvas, not a WebGL shader. The display stays Canvas 2D, the framebuffer and every pixel-reading test are untouched, and there is no second renderer to keep working. What CSS can't do (barrel curvature, bloom, phosphor persistence) is left out; a WebGL filter can replace the overlay later behind the same switch.

**Do.**
- `web/boot.js` `fitCanvas` already computes the integer scale. Also set it as `--screen-scale` (a unitless number) on `#game-view`.
- An `aria-hidden` element `#screen-crt` exactly over the canvas, `pointer-events: none`, shown when `body[data-crt="on"]`:
  - scanlines: `repeating-linear-gradient` with hard stops, period `calc(var(--screen-scale) * 1px)`, the bottom third of each console pixel row darkened by 25%;
  - an aperture grille: a second repeating gradient across, same period, three faint vertical bands (red, green, blue tints at 8%);
  - a vignette: a `radial-gradient` darkening the corners by up to 35% (the one soft gradient the look allows, because it is the glass, not the chrome);
  - the bezel gets `2u` more stepped corner cut while the filter is on.
- Below scale 3 the scanlines and grille are off (they would alias); the vignette stays.
- A physical toggle labelled CRT on the bezel, with an LED, `aria-pressed`. It is a device preference, not cart data, so JavaScript owns it: `localStorage` key `fes-crt`, read and written with the guard from T27, default per decision 6.
- `docs/SPEC.md`: change the Display bullet to say the CRT filter is a CSS overlay (link the decision).

**Accept.** Playwright: toggling sets `data-crt`, survives a reload, and with `localStorage` throwing the toggle still works for the visit; the canvas's pixels (`getImageData`) are identical with the filter on and off; the overlay's box equals the canvas's box at the three viewport sizes.

---

# M14 — The manual

A static, offline page that takes someone from "what is this" to a small game: how the console works, a tour of the editors, the whole API with an example for each call, and complete example carts.

## Design

- **Where.** `web/manual/index.html`, one page with a sticky table of contents, plain HTML and the shared `style.css` tokens and fonts plus a small `manual.css`. Copied by the build, precached by T30's generated list.
- **How it opens.** A fifth view, Help, with a toolbar key. The view is an `<iframe src="manual/">` whose `src` is set the first time it is shown, so the manual costs nothing at boot and reading it doesn't unload the cart. The page also works on its own at `/manual/`, so it can be linked from the README and read on a phone.
- **One source for the API.** `docs/API.md` is today's reference, and CLAUDE.md and PLAN tell every task to update it. Two copies would drift, so the manual becomes the reference and `docs/API.md` shrinks to one paragraph pointing at `web/manual/index.html#api` (decision 8). Update the mentions in `docs/SPEC.md`, `docs/PLAN.md` and decision 011 with a "Later:" line.
- **Voice.** For someone who has never written a game: short sentences, "you", every term explained the first time (tile, palette, sprite, scanline), a runnable example before the rules. No inside references to tasks or decision numbers.
- **Examples are tested.** Every complete cart in the manual is in a `<pre data-example="name">`, and a Playwright spec runs each one for 120 frames and fails on a cart error. An example that stops working after an API change breaks CI.

### T52 Manual page and Help view
Depends: T50, T30 · **Ask the owner** (decision 7)

**Do.**
- `ShownView` gets `help`; a Help key in the deck's switch row; `#help-view` holding the iframe, titled "FES manual".
- `web/manual/index.html` with the full section list as headings and these sections written: **Welcome** (what FES is, in five sentences), **Your first cart** (New cart → type eight lines → Run → move the sprite; then draw the sprite in Art; then Save), **The console** (the Hardware table from SPEC, limited to what works today, in plain words), **Buttons** (the table from `docs/API.md`). The remaining headings carry "Coming in this manual soon" only until T53–T55, which are in the same milestone.
- `manual.css`: a paper page inside the shell, body text 16 px with 24 px line height and a 68-character measure, code in `--font-code` on the editor's indigo, tables as plates, a table of contents that is a column in landscape and a `<details>` in portrait.
- The page has a "Back to FES" link when it is not inside the iframe (`window.top === window`).
- `scripts/build.sh` copies `web/manual/`.

**Accept.** Playwright: Help shows the manual; the iframe has no `src` before the first visit; with the network off (the offline spec's method) the manual still loads; switching Help → Code → Help keeps the code and the manual's scroll position; every `href="#…"` in the manual points at an id that exists.

### T53 The API reference moves to the manual
Depends: T52

**Do.**
- Section **API reference**: first "Rules for every call", "When things show" and "Budgets and errors", rewritten from `docs/API.md` for a beginner (keep every fact; move the deep budget details, such as `xpcall` and `__gc`, into a collapsed "For the curious" block). Then one entry per call (`cls`, `spr`, `btn`, `btnp`, `mset`, `mget`, `camera`, `require`, and whatever exists by then), each with: signature, one sentence, a parameter table (name, meaning, range, default), what it returns, a three-to-eight-line example, and "Common mistakes" where `docs/API.md` already records one (for example `spr(n, x, y, 0, 1)` being an error).
- Each entry has `id="api-<name>"`.
- A short **Lua in ten minutes** section: variables, tables, functions, `if`/`for`, `local`, integer division `//`, what is and isn't in the sandbox, with links to lua.org's manual for the rest.
- Replace `docs/API.md`'s content with the pointer. `CLAUDE.md` doesn't name the file and needs no change; `docs/PLAN.md` T10's line and decision 011 get the "Later:" note.

**Accept.** A Playwright spec runs a cart that lists the console's own globals (everything in `_G` whose value is a function and that standard Lua doesn't define; the spec holds the list of standard names) and asserts each has an `#api-<name>` section in the manual, so a new call can't ship undocumented. Reading the cart's answer needs no new API: have the cart place one sprite per name at a known position, or compare against a list inside the cart; the architect picks the smaller.

### T54 Example carts, tested
Depends: T53

**Do.** Section **Examples**, each a complete `main.lua` with a paragraph on what it shows and the lines worth noticing. Use the demo cart's tiles (`Runtime/DemoCart.swift`) so they run on a new cart's default art, or say which tile to draw first.
1. Move a sprite with the D-pad (the first-cart tutorial's finished form).
2. Animation: switch tiles on a frame counter, flip to face left.
3. A room from `mset`, and stopping at walls with `mget`.
4. A camera that follows the player across the map.
5. Many sprites and the 64-sprite and 16-per-line limits, shown on purpose.
6. Two files: `main.lua` and a `player.lua` module with `require`.

The spec: for each `pre[data-example]`, boot with `window.testCartMainLua` set to its text (and its second file where there is one: extend the boot hook to take a table of files only if example 6 needs it; otherwise run example 6 through the editor UI), run 120 frames with `runFrames`, assert `#cart-error` is empty.

**Accept.** That spec, and the PR preview: QA types example 1 from the manual by hand on the iPad and it works.

### T55 Guides: editors, carts and files
Depends: T53

**Do.** The remaining sections.
- **The code editor**: files and tabs, errors and where they point, the keyboard.
- **Drawing**: tiles and banks, the 8 palettes of 8 colors and the 64-color main palette (with a diagram made of HTML swatches, not an image), pencil, picker, fill, blocks, flip, copy and paste, undo, editing main colors, importing a sprite sheet and reading its report.
- **Carts**: the shelf, labels, new, duplicate and delete, saving, what the unsaved-changes restore is.
- **Keeping your carts safe**: why to add FES to the Home Screen (Safari's 7-day eviction), exporting a `.fes` to Files, importing, that a `.fes` is a zip of text files.
- **When something goes wrong**: the error messages a beginner will meet (`CPU budget exceeded`, `memory budget exceeded`, `attempt to call a nil value`, `module … not found`, a damaged cart) with what each means and what to do.
- **What's coming**: one paragraph on maps, sound and history, without dates.

**Accept.** The anchor check from T52; a review pass by the reviewer agent specifically for accuracy against the running app (every described button exists under that name: a spec collects each `<kbd data-control>` in the manual and asserts a control with that accessible name exists in the app).

### T56 Open an example in FES
Depends: T54

**Do.** Each example gets an "Open in FES" key, shown only inside the iframe. It posts `{ fesExample: name }` to the parent; `web/boot.js` checks the message's origin is its own and hands the example's text to Swift (a `globalThis.fesOpenExample` closure set by `App`), which asks about unsaved changes (T45), opens it as an unsaved cart named after the example with the demo's art, and shows the Code view. The example text is read from the manual's DOM by the parent, so there is one copy.

**Accept.** Playwright: open example 1 from the manual, Run, the sprite moves on input; with unsaved edits the dialog appears first and Cancel leaves the cart alone; a message from another origin is ignored.

---

# Review of what exists

A read of `main` at T22. Bugs and gaps that became tasks above are marked with the task. The rest are recommendations for the old outlines and for `docs/DEBT.md`.

## Became tasks

| Finding | Where | Task |
|---|---|---|
| No boot when `localStorage` throws | `web/pwa.js` | T27 |
| BOM accepted from OPFS, refused from `.fes`; CR reported on the wrong line | `web/storage.js`, `Storage/CartArchive.swift`, `Storage/TextLines.swift` | T28 |
| Game speed follows the display's refresh rate | `web/boot.js` | T29 |
| Hand-kept precache list; all CSS inline | `web/sw.js`, `web/index.html` | T30 |
| Concurrent saves and loads can interleave and mislabel the cart as saved | `App/SavedCarts.swift` | T31 |
| No way to start a new cart, duplicate or delete one; damaged folders stay forever | `App/SavedCarts.swift` | T38 |
| The Game view can only be reached by Run, which restarts the cart | `App/CodeAndGameViews.swift` | T43 |
| Pad buttons ignore VoiceOver and Switch Control | `web/input.js` | T44 |
| Art view scrolls or clips on smaller iPads | `web/index.html` | T47 |
| Error positions only understand `main.lua` | `Runtime/MainLua.swift` | T34 |

## Recommendations for the old outlines (M4–M8)

Put these to the owner when each milestone is broken into tasks; none is decided here.

1. **Carts can't show text or debug.** `print` is removed from the sandbox and the overlay layer with `print` is in M8, last. A beginner's first question is "how do I show the score" and the second is "how do I see a value". Pull the overlay layer and `print` forward to right after M4, and add a `log(...)` call that writes to a console strip in the Code view (it costs one small task and makes the manual's examples much better).
2. **Run the console in a Worker before M5.** Three DEBT lines describe tab freezes that main-thread wasm can't stop (a long C library call, a `<close>` loop). M5 already needs a second wasm module and message passing for audio; doing the Worker move first means audio is designed against the final threading model. It is a large change (the DOM bridge stays on the main thread, the console and Lua move), so it needs its own spike task like T02.
3. **Decide the numeric limits (SPEC open decision) before the manual's Budgets text is final**, and add the usage display DEBT mentions (CPU and memory as two small bars on the deck). The manual currently has to say "placeholder" three times.
4. **Code size limit.** SPEC says it is measured on the Lua the runtime executes; with many files that is the sum of all code files. Decide it with the other limits.
5. **M4 map size.** The fixed 32×32 map (DEBT) is smaller than two screens tall (144 px = 18 rows; 32 rows = 256 px) and barely over one wide. The API reference documents wrapping at 256 px; whatever M4 chooses, the manual's map text and example 4 change with it.
6. **M6 makes saves whole.** T33 adds a second non-atomic step (removing deleted files). The content-addressed store in M6 should replace `writeCart` entirely; until then the DEBT line about partial saves gains "and a deleted code file may reappear if the save is interrupted".
7. **M7 Teal** builds on M10: the `modules` dictionary in `RunningCart` becomes the compiled Lua for `.tl` files, the tab strip shows `.tl` names, and `codeFileNameProblem` accepts the second extension.
8. **Recovery copy cost.** `keepRecoveryCopy` serialises the whole cart to JSON and compares two whole `Cart` values on every keystroke and every picker value (decision 029 chose that on purpose). Labels and many files make the cart bigger. T39 measures it; if it shows up, write only the changed file under its own key.
9. **`App.wasm` size** (10.6 MB, 3.0 MB gzipped, DEBT): fonts and the manual add little, but first load on cellular is already the slowest part of the product. `wasm-opt` is a build-time tool, not a shipped dependency; worth one `needs-input` question.
10. **`PPU.render` allocates an array per scanline** (`drawBackground` returns `[Int]`, `drawSprites` filters and reverses arrays). It is fine at one layer; M4 adds two more layers and M8 a per-scanline callback. Measure a frame on the iPad before M4 and, if it matters, reuse one buffer per frame.

## DEBT lines Phase 2 removes or changes

- Removed: frame pacing (T29); both touch overlay lines (T44); both "Damaged cart" lines (T38); Art view narrow window, Pixel group and palette grid lines (T47, the first rewritten); Art view placeholder look (T48); native dialogs (added in T36, removed in T45).
- Changed: the `window.testCartMainLua` line (T41); the partial-save line (T33); the app icon line (T50, kept unless the owner accepts the art); the Home Screen hint wording line stays, and T55's manual text should be read by the owner together with it.
