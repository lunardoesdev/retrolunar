#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

extern const char *loader_lua;

static int run_chunk(lua_State *L, int status) {
  if (status == LUA_OK)
    status = lua_pcall(L, 0, LUA_MULTRET, 0);
  if (status != LUA_OK) {
    fprintf(stderr, "%s\n", lua_tostring(L, -1));
    lua_pop(L, 1);
  }
  return status;
}

static int repl(lua_State *L) {
  char line[4096];
  int status = LUA_OK;
  int tty = isatty(STDIN_FILENO);
  for (;;) {
    if (tty) {
      fputs("> ", stdout);
      fflush(stdout);
    }
    if (!fgets(line, sizeof line, stdin))
      break;
    if (line[0] == '\n')
      continue;
    status = run_chunk(L, luaL_loadstring(L, line));
  }
  if (tty)
    putchar('\n');
  return status;
}

int main(int argc, char **argv) {
  lua_State *L = luaL_newstate();
  if (!L) {
    fprintf(stderr, "out of memory\n");
    return 1;
  }
  luaL_openlibs(L);
  if (run_chunk(L, luaL_loadstring(L, loader_lua)) != LUA_OK) {
    lua_close(L);
    return 1;
  }

  int status;
  if (argc < 2)
    status = repl(L);
  else if (argc == 3 && strcmp(argv[1], "-e") == 0)
    status = run_chunk(L, luaL_loadstring(L, argv[2]));
  else if (argc == 2)
    status = run_chunk(L, luaL_loadfile(L, argv[1]));
  else {
    fprintf(stderr, "usage: %s [script | -e chunk]\n", argv[0]);
    status = LUA_ERRERR;
  }

  lua_close(L);
  return status != LUA_OK;
}
