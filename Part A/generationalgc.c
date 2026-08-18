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
     * Switch to generational GC mode BEFORE running the testbench.
     * lua_gc(L, LUA_GCGEN, minormul, majormul)
     *   minormul = controls frequency of minor (young-gen) collections
     *              (0 = default = 20, meaning minor GC when memory grows 20%)
     *   majormul = controls frequency of major (full-gen) collections
     *              (0 = default = 100, meaning major GC when memory doubles)
     *
     * Passing 0,0 uses Lua's built-in defaults.
     */
    lua_gc(L, LUA_GCGEN, 0, 0);

    /* Load and run the testbench — GC runs generationally during execution */
    if (luaL_dofile(L, "testbench.lua") != LUA_OK) {
        fprintf(stderr, "Error: %s\n", lua_tostring(L, -1));
        lua_close(L);
        return 1;
    }

    lua_close(L);
    return 0;
}