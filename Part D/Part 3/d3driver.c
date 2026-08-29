#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include <stdio.h>

int main(int argc, char **argv) {
    const char *script = "testbench.lua";
    if (argc > 1) script = argv[1];

    lua_State *L = luaL_newstate();
    if (!L) {
        fprintf(stderr, "Failed to create Lua state\n");
        return 1;
    }
    luaL_openlibs(L);

    /* Use incremental GC (default) */
    lua_gc(L, LUA_GCINC, 0, 0, 0);

    if (luaL_dofile(L, script) != LUA_OK) {
        fprintf(stderr, "Error: %s\n", lua_tostring(L, -1));
        lua_close(L);
        return 1;
    }

    lua_close(L);
    return 0;
}