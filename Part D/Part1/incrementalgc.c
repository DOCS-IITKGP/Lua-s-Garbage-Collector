#include <stdio.h>
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

int main() {
    // 1. Initialize the Lua State
    lua_State *L = luaL_newstate();
    luaL_openlibs(L);

    // 2. Configure the Garbage Collector
    // Use LUA_GCCOLLECT for fullgc.c
    lua_gc(L, LUA_GCINC); 

    // 3. Load and execute the testbench
    if (luaL_dofile(L, "testbench.lua") != LUA_OK) {
        fprintf(stderr, "Error: %s\n", lua_tostring(L, -1));
        lua_close(L);
        return 1;
    }

    // 4. Cleanup
    lua_close(L);
    return 0;
}