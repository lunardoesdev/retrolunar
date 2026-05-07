#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

static int l_get_build_triplet(lua_State *L) {
    const char* build_triplet = "x86_64-unknown-linux-gnu";
    lua_pushstring(L, build_triplet);
    return 1;
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s recipe.lua\n", argv[0]);
        return 1;
    }
    lua_State *L = luaL_newstate();
    if (!L) {
        fprintf(stderr, "failed to create lua state\n");
        return 1;
    }

    luaL_openlibs(L);

    lua_register(L, "getBuildTriplet", l_get_build_triplet);

    int rc = luaL_dofile(L, argv[1]);
    if (rc != LUA_OK) {
        const char *err = lua_tostring(L, -1);
        fprintf(stderr, "error: %s\n", err);
        lua_close(L);
        return 1;
    }

    lua_close(L);
    return 0;
}