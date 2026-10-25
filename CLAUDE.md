# FES — Frank Entertainment System

FES is a fantasy console that runs in the browser on iPad as an installable PWA. Swift compiled to WebAssembly owns all state and logic; a thin layer of JavaScript does what the browser does best. Carts are written in Lua 5.4, optionally Teal.

- What we are building: `docs/SPEC.md`
- What to build, in order: `docs/PLAN.md`
- How agents work, hand off and resume: `docs/WORKFLOW.md`
- Why things are the way they are: `docs/decisions/`
- Owner's one-time setup: `docs/SETUP.md`

To continue the work from wherever it stopped, run `/continue`. To see where things stand, run `/status`.

## The reader

The owner is a solo developer who reads every PR to learn how the system works, and must be able to take over the codebase alone. Write for that reader: code a competent developer new to this domain can follow top to bottom.

## Code rules

Ponytail is installed and applies to all code. Before writing anything, climb its ladder: does this need to exist, is it already in the codebase, does the standard library or the platform do it, does an installed dependency do it, can it be one line. Only then write the minimum that works.

- Simple and explicit over clever. A longer obvious function beats a short puzzle.
- No abstraction until it has two real users. No protocols with one conformer, no "Manager"/"Service"/"Helper" types, no dependency injection frameworks, no configuration for things that never vary.
- Small files with one clear job. Names say what things are and do.
- Value types and plain functions by default in Swift. Plain ES modules in JavaScript, no framework, no TypeScript.
- JavaScript only where `docs/SPEC.md` assigns it. JS never owns cart or editor state.
- Never cut validation at trust boundaries (cart files, user input, storage reads), error handling that prevents data loss, or accessibility of the editor UI.

### Comments

Don't write comments. If code needs explaining, rename or restructure it until it doesn't. A comment is allowed only for something the code cannot say: a browser or Safari quirk, a hardware-spec reason for a magic number, a non-obvious constraint from a spec or decision record (link it). One line, saying why, never what.

Do not write ponytail `shortcut:` comments. Record deliberate shortcuts in `docs/DEBT.md` (one line each: what, why, when to revisit) in the same PR.

### Tests

A test must be able to catch a real bug. Write tests for:
- logic with branches, loops or arithmetic: PPU composition, palette and tile decoding, budgets and limits, parsers and serializers, the snapshot store
- rendering, as golden-image tests of the framebuffer against a checked-in PNG
- every defect QA finds, as a regression test when it can be reproduced in a test

Don't write tests for getters, initializers, trivial forwarding, glue that only calls the browser, or anything that only restates the implementation. No mocks of our own code. Coverage is not a goal. Each test name states the behavior it protects.

Swift core tests run natively with `swift test`. Browser behavior is checked by Playwright on WebKit with an iPad device profile.

## Dependencies

Approved: JavaScriptKit, Lua 5.4 (vendored C sources), CodeMirror 6 and its legacy Lua mode, esbuild (bundling), Playwright (tests), Teal (vendored, milestone M7). Anything else needs a decision record and the owner's approval through a `needs-input` question.

## Git and GitHub

- GitHub: `gh api` REST calls only; GraphQL is blocked in cloud sessions. Recipes in `docs/WORKFLOW.md` → GitHub commands.
- Never push to `main`, never merge, never mark a PR ready yourself unless you are the orchestrator following `docs/WORKFLOW.md`.
- One task, one branch, one PR, stacked on its dependency. Branch name: `t<NN>-<slug>`.
- Fixes are new commits. Never rewrite pushed history except when restacking, and then push with `--force-with-lease`.
- Target under ~300 changed lines per PR, not counting vendored code, generated files and golden images.
