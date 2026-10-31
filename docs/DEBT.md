# Debt

Deliberate shortcuts, one line each: what, why, when to revisit.
- App.wasm ships without wasm-opt (9.1 MB, 2.4 MB gzipped): binaryen isn't installed or approved; revisit in T15 when offline first-load size matters.
- runLuaChunk converts results and errors with luaL_tolstring outside a protected call, so an erroring `__tostring` metamethod aborts the process: the spike only needs plain values; revisit in T09 when conversion moves inside a protected call.
- A cancelled pending deploy leaves its PR's check cancelled and can skip that PR's first preview comment: the `pages` concurrency group keeps only one pending job, so restacking three or more PRs cancels some; revisit if restacks often leave PRs without a preview link.
- Master palette is a generated 2-bit-per-channel placeholder: the owner picks the curated 64 colors (SPEC open decision); revisit at the start of M3.
- Background tilemap is a fixed 32×32 cells: map dimensions are a SPEC open decision the owner takes in M4; revisit then (change Tilemap.columns/rows, keep powers of two, re-record goldens).
