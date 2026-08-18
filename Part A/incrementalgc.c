#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include <stdio.h>
#include <stdlib.h>

int main(void) {
    lua_State *L = luaL_newstate();
    if (!L) {
        fprintf(stderr, "Failed to create Lua state\n");
        return 1;
    }
    luaL_openlibs(L);

    /*
     * Switch to incremental GC mode BEFORE running the testbench.
     * lua_gc(L, LUA_GCINC, pause, stepmul, stepsize)
     *   pause    = how long GC waits before starting a new cycle
     *              (as a percentage of memory in use; 0 = default = 200)
     *   stepmul  = speed of GC relative to allocation (0 = default = 100)
     *   stepsize = size of each incremental step in log2(bytes) (0 = default = 13)
     *
     * Passing 0,0,0 uses Lua's built-in defaults.
     */
    lua_gc(L, LUA_GCINC, 0, 0, 0);

    /* Load and run the testbench — GC runs incrementally during execution */
    if (luaL_dofile(L, "testbench.lua") != LUA_OK) {
        fprintf(stderr, "Error: %s\n", lua_tostring(L, -1));
        lua_close(L);
        return 1;
    }

    lua_close(L);
    return 0;
}