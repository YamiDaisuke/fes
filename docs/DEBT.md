# Debt

Deliberate shortcuts, one line each: what, why, when to revisit.
- App.wasm ships without wasm-opt (9.1 MB, 2.4 MB gzipped): binaryen isn't installed or approved; revisit in T15 when offline first-load size matters.
- runLuaChunk converts results and errors with luaL_tolstring outside a protected call, so an erroring `__tostring` metamethod aborts the process: the spike only needs plain values; revisit in T09 when conversion moves inside a protected call.
