#include <stdio.h>
#include <string.h>

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#ifndef RETROLUNAR_DEFAULT_SYSTEM
#define RETROLUNAR_DEFAULT_SYSTEM "clang-native"
#endif

/* Bare `retrolunar` prints usage on stdout and exits 0; there is no REPL. */

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

/* install --nest DIR --packages DIR <pack[@sys]...> — print the POSIX sh
 * install script for the queued recipes to stdout. */
static void usage(FILE *out, const char *prog);

static int do_install(lua_State *L, int argc, char **argv) {
  const char *nest = NULL;
  const char *pkgs = NULL;
  int first = -1;
  for (int i = 2; i < argc; i++) {
    if (strcmp(argv[i], "--nest") == 0) {
      if (++i >= argc) goto usage;
      nest = argv[i];
    } else if (strcmp(argv[i], "--packages") == 0) {
      if (++i >= argc) goto usage;
      pkgs = argv[i];
    } else if (first < 0) {
      first = i;
    }
  }
  if (nest == NULL || pkgs == NULL || first < 0)
    goto usage;
  lua_pushstring(L, pkgs);
  lua_setglobal(L, "RETROLUNAR_PKGS_BOOT");
  lua_getglobal(L, "require");
  if (!lua_isfunction(L, -1)) {
    fprintf(stderr, "install: loader not ready\n");
    return LUA_ERRERR;
  }
  for (int i = first; i < argc; i++) {
    lua_pushvalue(L, -1);
    lua_pushstring(L, argv[i]);
    if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
      fprintf(stderr, "%s\n", lua_tostring(L, -1));
      return LUA_ERRRUN;
    }
    lua_pop(L, 1);
  }
  lua_pop(L, 1);
  lua_getglobal(L, "require_script");
  if (!lua_isfunction(L, -1)) {
    fprintf(stderr, "install: require_script not ready\n");
    return LUA_ERRERR;
  }
  /* Pass nest/packages dirs as header assignments, not baked paths. */
  lua_pushstring(L, nest);
  lua_pushstring(L, pkgs);
  if (lua_pcall(L, 2, 1, 0) != LUA_OK) {
    fprintf(stderr, "%s\n", lua_tostring(L, -1));
    return LUA_ERRRUN;
  }
  {
    size_t len = 0;
    const char *s = lua_tolstring(L, -1, &len);
    if (len > 0 && fwrite(s, 1, len, stdout) != len) {
      fprintf(stderr, "install: write failed\n");
      return LUA_ERRFILE;
    }
  }
  return LUA_OK;
usage:
  usage(stderr, argv[0]);
  return LUA_ERRERR;
}

static void usage(FILE *out, const char *prog) {
  fprintf(out,
    "usage: %s [script | -e chunk]\n"
    "       %s install --nest DIR --packages DIR <pack[@sys]...>\n"
    "       %s --help\n"
    "\n"
    "Commands:\n"
    "  install   print a POSIX sh script that builds the queued recipes for\n"
    "            <pack[@sys]> targets into per-system prefixes under --nest.\n"
    "            'pack' uses the compile-time default system (DEFAULT_SYSTEM,\n"
    "            %s by default); '@native' is an alias for that same system.\n"
    "            Dependencies resolve automatically and are emitted first.\n"
    "  -e chunk  run a Lua chunk.\n"
    "  script    run a Lua file.\n"
    "\n"
    "With no arguments, read Lua from stdin as a REPL.\n"
    "\n"
    "Options:\n"
    "  --nest DIR       output root for per-system prefixes (install)\n"
    "  --packages DIR   packages tree to resolve recipes from\n"
    "  -h, --help       show this help and exit\n",
    prog, prog, prog, RETROLUNAR_DEFAULT_SYSTEM);
}

int main(int argc, char **argv) {
  for (int i = 1; i < argc; i++) {
    if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
      usage(stdout, argv[0]);
      return 0;
    }
  }
  if (argc < 2) {
    usage(stdout, argv[0]);
    return 0;
  }
  lua_State *L = luaL_newstate();
  if (!L) {
    fprintf(stderr, "out of memory\n");
    return 1;
  }
  luaL_openlibs(L);
  lua_pushstring(L, RETROLUNAR_DEFAULT_SYSTEM);
  lua_setglobal(L, "DEFAULT_SYSTEM");
  for (int i = 1; i < argc - 1; i++) {
    if (strcmp(argv[i], "--packages") == 0) {
      lua_pushstring(L, argv[i + 1]);
      lua_setglobal(L, "RETROLUNAR_PKGS_BOOT");
      break;
    }
  }
  if (run_chunk(L, luaL_loadstring(L, loader_lua)) != LUA_OK) {
    lua_close(L);
    return 1;
  }

  int status;
  if (argc >= 2 && strcmp(argv[1], "install") == 0)
    status = do_install(L, argc, argv);
  else if (argc == 3 && strcmp(argv[1], "-e") == 0)
    status = run_chunk(L, luaL_loadstring(L, argv[2]));
  else if (argc == 2)
    status = run_chunk(L, luaL_loadfile(L, argv[1]));
  else {
    usage(stderr, argv[0]);
    status = LUA_ERRERR;
  }

  lua_close(L);
  return status != LUA_OK;
}
