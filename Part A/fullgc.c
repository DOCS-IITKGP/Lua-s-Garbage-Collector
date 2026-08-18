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

    /* Stop the automatic GC so we control it manually */
    lua_gc(L, LUA_GCSTOP);

    /* Load and run the testbench */
    if (luaL_dofile(L, "testbench.lua") != LUA_OK) {
        fprintf(stderr, "Error: %s\n", lua_tostring(L, -1));
        lua_close(L);
        return 1;
    }

    /* Now force a full stop-the-world collection */
    lua_gc(L, LUA_GCCOLLECT);

    lua_close(L);
    return 0;
}