#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
    int sweep_val = 20;

    if (argc > 1) {
        sweep_val = atoi(argv[1]);
        if (sweep_val <= 0) sweep_val = 20;
    }

    lua_State *L = luaL_newstate();
    if (!L) {
        fprintf(stderr, "Failed to create Lua state\n");
        return 1;
    }
    luaL_openlibs(L);

    /* Use incremental GC — the only mode where sweep granularity matters */
    lua_gc(L, LUA_GCINC, 0, 0, 0);

    /* Tune the sweep granularity */
    setsweepstep(L, sweep_val);
    printf("Sweep step set to %d\n", sweep_val);

    /* Run testbench */
    if (luaL_dofile(L, "testbench.lua") != LUA_OK) {
        fprintf(stderr, "Error: %s\n", lua_tostring(L, -1));
        lua_close(L);
        return 1;
    }

    printf("Testbench completed successfully\n");
    lua_close(L);
    return 0;
}