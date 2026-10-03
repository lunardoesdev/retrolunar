#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <dirent.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/types.h>

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#ifndef RETROLUNAR_DEFAULT_SYSTEM
#define RETROLUNAR_DEFAULT_SYSTEM "clang-native"
#endif

/* Bare `retrolunar` prints usage on stdout and exits 0; there is no REPL. */

#define PACKAGES_REPO "https://github.com/lunardoesdev/retrolunar-packages"

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

/* Fallback nest root when --nest is omitted: $HOME/.cache/retrolunar/nestdir.
 * Returns NULL when HOME is unset, which sends the caller to the usage
 * message rather than guessing a location. */
static const char *default_nest(void) {
  const char *home = getenv("HOME");
  if (home == NULL || home[0] == '\0')
    return NULL;
  static char buf[PATH_MAX];
  if (snprintf(buf, sizeof buf, "%s/.cache/retrolunar/nestdir", home) >=
      (int)sizeof buf)
    return NULL;
  return buf;
}

/* True when dir exists and holds at least one entry. An empty directory is
 * not a usable packages tree: the loader would resolve nothing, and an
 * interrupted clone leaves exactly that behind. */
static int dir_has_entries(const char *path) {
  DIR *d = opendir(path);
  if (d == NULL)
    return 0;
  int found = 0;
  struct dirent *e;
  while ((e = readdir(d)) != NULL) {
    if (strcmp(e->d_name, ".") == 0 || strcmp(e->d_name, "..") == 0)
      continue;
    found = 1;
    break;
  }
  closedir(d);
  return found;
}

/* Packages tree when --packages is omitted:
 * $HOME/.cache/retrolunar/packages. Cloned on first use, updated in place
 * afterwards. A failed update is ignored — an already-populated tree is
 * still good enough to resolve recipes against — but an unusable tree is
 * fatal, so a half-finished clone cannot masquerade as a working one.
 * Returns NULL when no tree could be obtained, which sends the caller to
 * an error message. */
static const char *default_packages(void) {
  const char *home = getenv("HOME");
  if (home == NULL || home[0] == '\0')
    return NULL;
  static char dir[PATH_MAX], root[PATH_MAX], cache[PATH_MAX];
  if (snprintf(cache, sizeof cache, "%s/.cache", home) >= (int)sizeof cache)
    return NULL;
  if (snprintf(root, sizeof root, "%s/retrolunar", cache) >= (int)sizeof root)
    return NULL;
  if (snprintf(dir, sizeof dir, "%s/packages", root) >= (int)sizeof dir)
    return NULL;
  /* Both levels, since ~/.cache is itself absent on a fresh account. */
  if (mkdir(cache, 0755) != 0 && errno != EEXIST)
    return NULL;
  if (mkdir(root, 0755) != 0 && errno != EEXIST)
    return NULL;
  if (dir_has_entries(dir)) {
    /* Best-effort refresh. Any failure here is deliberately non-fatal. */
    char pull[PATH_MAX];
    if (snprintf(pull, sizeof pull, "git -C '%s' pull --ff-only >/dev/null 2>&1", dir) <
        (int)sizeof pull)
      if (system(pull) == -1) { /* ignored on purpose */ }
  } else {
    char clone[PATH_MAX];
    if (snprintf(clone, sizeof clone,
                 "git clone --depth=1 '%s' '%s' >/dev/null 2>&1",
                 PACKAGES_REPO, dir) < (int)sizeof clone)
      if (system(clone) == -1) { /* ignored; checked below */ }
  }
  return dir_has_entries(dir) ? dir : NULL;
}

/* The tree to resolve recipes from: --packages when given, otherwise the
 * bootstrapped default. Reports why it failed and returns NULL. */
static const char *resolve_packages(const char *given) {
  if (given != NULL)
    return given;
  const char *dir = default_packages();
  if (dir == NULL) {
    fprintf(stderr,
      "retrolunar: no packages tree and could not get one from %s\n"
      "  pass --packages DIR, or clone %s yourself\n",
      PACKAGES_REPO, PACKAGES_REPO);
    return NULL;
  }
  return dir;
}

static int do_install(lua_State *L, int argc, char **argv, const char *pkgs) {
  const char *nest = NULL;
  int first = -1;
  for (int i = 2; i < argc; i++) {
    if (strcmp(argv[i], "--nest") == 0) {
      if (++i >= argc) goto usage;
      nest = argv[i];
    } else if (strcmp(argv[i], "--packages") == 0) {
      /* Already resolved and passed in; skip the flag and its value. */
      if (++i >= argc) goto usage;
    } else if (first < 0) {
      first = i;
    }
  }
  if (nest == NULL)
    nest = default_nest();
  if (nest == NULL || first < 0)
    goto usage;
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

/* deps [--packages DIR] <pack[@sys]>... — resolve the same queue install
 * would build, and print it instead of emitting a build script. Queue
 * order is dependency order: leaves first, requested packages last. */
static int do_deps(lua_State *L, int argc, char **argv) {
  int first = -1;
  for (int i = 2; i < argc; i++) {
    if (strcmp(argv[i], "--packages") == 0) {
      if (++i >= argc) goto usage;
    } else if (first < 0) {
      first = i;
    }
  }
  if (first < 0)
    goto usage;
  lua_getglobal(L, "require");
  if (!lua_isfunction(L, -1)) {
    fprintf(stderr, "deps: loader not ready\n");
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
  lua_getglobal(L, "require_queue");
  if (!lua_isfunction(L, -1)) {
    fprintf(stderr, "deps: require_queue not ready\n");
    return LUA_ERRERR;
  }
  if (lua_pcall(L, 0, 1, 0) != LUA_OK) {
    fprintf(stderr, "%s\n", lua_tostring(L, -1));
    return LUA_ERRRUN;
  }
  /* require_queue returns an array snapshot; walk it by index. Each entry
   * is a recipe table carrying name, sys, and version when set. */
  lua_Integer n = luaL_len(L, -1);
  for (lua_Integer i = 1; i <= n; i++) {
    lua_geti(L, -1, i);
    lua_getfield(L, -1, "name");
    lua_getfield(L, -2, "sys");
    lua_getfield(L, -3, "version");
    int have_ver = lua_isstring(L, -1);
    printf("%s@%s%s%s\n",
           lua_isstring(L, -3) ? lua_tostring(L, -3) : "?",
           lua_isstring(L, -2) ? lua_tostring(L, -2) : "?",
           have_ver ? " " : "", have_ver ? lua_tostring(L, -1) : "");
    lua_pop(L, 4); /* version, sys, name, entry */
  }
  lua_pop(L, 1); /* queue table */
  return ferror(stdout) ? LUA_ERRFILE : LUA_OK;
usage:
  usage(stderr, argv[0]);
  return LUA_ERRERR;
}

static void usage(FILE *out, const char *prog) {
  fprintf(out,
    "usage: %s [script | -e chunk]\n"
    "       %s install [--nest DIR] --packages DIR <pack[@sys]...>\n"
    "       %s deps --packages DIR <pack[@sys]...>\n"
    "       %s --help\n"
    "\n"
    "Commands:\n"
    "  install   print a POSIX sh script that builds the queued recipes for\n"
    "            <pack[@sys]> targets into per-system prefixes under --nest.\n"
    "            'pack' uses the compile-time default system (DEFAULT_SYSTEM,\n"
    "            %s by default); '@native' is an alias for that same system.\n"
    "            Dependencies resolve automatically and are emitted first.\n"
    "  deps      print each <pack[@sys]> target and all of its dependencies\n"
    "            in dependency order (leaves first), then exit. Resolves the\n"
    "            same queue 'install' would build but writes no script and\n"
    "            touches no nest: no downloads, no builds, no stamps.\n"
    "  -e chunk  run a Lua chunk.\n"
    "  script    run a Lua file.\n"
    "\n"
    "Example:\n"
    "  %s deps 'python@aarch64-android24'\n"
    "  %s install 'python@aarch64-android24' > build.sh\n"
    "\n"
    "  # --nest defaults to $HOME/.cache/retrolunar/nestdir\n"
    "\n"
    "  # for a packages tree of your own:\n"
    "  git clone https://github.com/lunardoesdev/retrolunar-packages\n"
    "  %s deps --packages ./retrolunar-packages 'python@aarch64-android24'\n"
    "\n"
    "With no arguments, print this help.\n"
    "\n"
    "Options:\n"
    "  --nest DIR       output root for per-system prefixes (install);\n"
    "                   defaults to $HOME/.cache/retrolunar/nestdir\n"
    "  --packages DIR   packages tree to resolve recipes from;\n"
    "                   defaults to $HOME/.cache/retrolunar/packages, cloned\n"
    "                   from %s on first use and refreshed on later runs\n"
    "  -h, --help       show this help and exit\n",
    prog, prog, prog, prog, RETROLUNAR_DEFAULT_SYSTEM, prog, prog, prog,
    PACKAGES_REPO);
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
  /* Resolve the packages tree before the loader runs: it reads
   * RETROLUNAR_PKGS_BOOT once at init and closes over the result, so a
   * global set afterwards would not change where recipes are looked up. */
  const char *pkgs_boot = NULL;
  if (argc >= 2 && (strcmp(argv[1], "install") == 0 ||
                    strcmp(argv[1], "deps") == 0)) {
    /* Require at least one target before touching the network: a plain
     * `deps` with no package should not clone the tree just to then fail
     * on the usage message. */
    int targets = 0, bad = 0;
    pkgs_boot = NULL;
    for (int i = 2; i < argc; i++) {
      if (strcmp(argv[i], "--packages") == 0) {
        if (++i >= argc) { bad = 1; break; }
        pkgs_boot = argv[i];
      } else if (strcmp(argv[i], "--nest") == 0) {
        if (++i >= argc) { bad = 1; break; }
      } else {
        targets++;
      }
    }
    if (bad || targets == 0) {
      usage(stderr, argv[0]);
      lua_close(L);
      return 1;
    }
    pkgs_boot = resolve_packages(pkgs_boot);
    if (pkgs_boot == NULL) {
      lua_close(L);
      return 1;
    }
    lua_pushstring(L, pkgs_boot);
    lua_setglobal(L, "RETROLUNAR_PKGS_BOOT");
  }
  if (run_chunk(L, luaL_loadstring(L, loader_lua)) != LUA_OK) {
    lua_close(L);
    return 1;
  }

  int status;
  if (argc >= 2 && strcmp(argv[1], "install") == 0)
    status = do_install(L, argc, argv, pkgs_boot);
  else if (argc >= 2 && strcmp(argv[1], "deps") == 0)
    status = do_deps(L, argc, argv);
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
