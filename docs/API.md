# Console API

The API reference lives in the manual, section **API reference**: [`web/manual/index.html#api`](../web/manual/index.html#api). Each call has its own entry with the id `api-<name>`. The manual is the one source of truth, so this file keeps no copy (decision 057). To read it, open Help in FES, or open `manual/#api` on the running site.

A task that adds, removes or changes a Lua call updates its manual entry in the same PR. `web/tests/api-reference.spec.js` fails when a console global has no entry or an entry has no global.
