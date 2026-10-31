/* Included by lua.h through LUA_USER_H; see docs/decisions/012-cpu-and-memory-budgets.md. */
#define FES_LUA_STACK_SLOTS 15000
#undef LUAI_MAXSTACK
#define LUAI_MAXSTACK FES_LUA_STACK_SLOTS
