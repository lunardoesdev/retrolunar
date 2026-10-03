#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <dirent.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#ifndef RETROLUNAR_DEFAULT_SYSTEM
#define RETROLUNAR_DEFAULT_SYSTEM "clang-native"
#endif

/* Bare `retrolunar` prints usage on stdout and exits 0; there is no REPL. */

#define PACKAGES_REPO "https://github.com/lunardoesdev/retrolunar-packages"

extern const char *loader_lua;

/* Set by `generate -x` when the generated script exits non-zero, so main
 * can hand the script's own status back instead of collapsing it to 1. */
static int script_exit_status = 0;

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

/* Require every target, in order. Takes the list the option parser built,
 * not argv: argv still holds the flags, and re-walking it from the first
 * target meant an option written after a target was treated as a package
 * name ('module "--cores" not found'). */
static int resolve_targets(lua_State *L, char **targets, int n) {
  lua_getglobal(L, "require");
  if (!lua_isfunction(L, -1)) {
    fprintf(stderr, "loader not ready\n");
    return LUA_ERRERR;
  }
  for (int i = 0; i < n; i++) {
    lua_pushvalue(L, -1);
    lua_pushstring(L, targets[i]);
    if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
      fprintf(stderr, "%s\n", lua_tostring(L, -1));
      return LUA_ERRRUN;
    }
    lua_pop(L, 1);
  }
  lua_pop(L, 1);
  return LUA_OK;
}

/* Emit the build script for the queued targets. Caller frees. */
static char *build_script(lua_State *L, const char *nest, const char *pkgs,
                          int cores, size_t *out_len) {
  lua_getglobal(L, "require_script");
  if (!lua_isfunction(L, -1)) {
    fprintf(stderr, "require_script not ready\n");
    return NULL;
  }
  /* Pass nest/packages dirs as header assignments, not baked paths. */
  lua_pushstring(L, nest);
  lua_pushstring(L, pkgs);
  lua_pushinteger(L, cores);
  if (lua_pcall(L, 3, 1, 0) != LUA_OK) {
    fprintf(stderr, "%s\n", lua_tostring(L, -1));
    return NULL;
  }
  size_t len = 0;
  const char *s = lua_tolstring(L, -1, &len);
  char *copy = NULL;
  if (s != NULL && len > 0) {
    copy = malloc(len);
    if (copy == NULL) {
      fprintf(stderr, "out of memory\n");
      return NULL;
    }
    memcpy(copy, s, len);
  }
  lua_pop(L, 1);
  *out_len = len;
  return copy;
}

static int do_install(lua_State *L, int argc, char **argv, const char *pkgs) {
  const char *nest = NULL;
  char **targets = malloc(sizeof(char *) * (size_t)argc);
  int ntargets = 0, cores = 1;
  if (targets == NULL)
    return LUA_ERRERR;
  for (int i = 2; i < argc; i++) {
    if (strcmp(argv[i], "--nest") == 0) {
      if (++i >= argc) goto usage;
      nest = argv[i];
    } else if (strcmp(argv[i], "--packages") == 0) {
      /* Already resolved and passed in; skip the flag and its value. */
      if (++i >= argc) goto usage;
    } else if (strcmp(argv[i], "--cores") == 0) {
      if (++i >= argc) goto usage;
      char *end = NULL;
      long v = strtol(argv[i], &end, 10);
      if (end == argv[i] || *end != '\0' || v < 1 || v > 1024) {
        fprintf(stderr, "install: --cores wants a number from 1 to 1024\n");
        goto usage;
      }
      cores = (int)v;
    } else if (argv[i][0] == '-' && argv[i][1] != '\0') {
      fprintf(stderr, "install: unknown option '%s'\n", argv[i]);
      goto usage;
    } else {
      targets[ntargets++] = argv[i];
    }
  }
  if (nest == NULL)
    nest = default_nest();
  if (ntargets == 0)
    goto usage;
  int status = resolve_targets(L, targets, ntargets);
  free(targets);
  if (status != LUA_OK)
    return status;
  size_t len = 0;
  char *script = build_script(L, nest, pkgs, cores, &len);
  if (script == NULL)
    return LUA_ERRRUN;
  if (len > 0 && fwrite(script, 1, len, stdout) != len) {
    fprintf(stderr, "install: write failed\n");
    free(script);
    return LUA_ERRFILE;
  }
  free(script);
  return LUA_OK;
usage:
  usage(stderr, argv[0]);
  free(targets);
  return LUA_ERRERR;
}

/* generate [-o FILE] [-x] [--cores N] <pack[@sys]>... — same script
 * install emits, with somewhere to put it and the option to run it. */
static int do_generate(lua_State *L, int argc, char **argv, const char *pkgs) {
  const char *nest = NULL;
  const char *output = NULL;
  char **targets = malloc(sizeof(char *) * (size_t)argc);
  int ntargets = 0, execute = 0, cores = 1;
  if (targets == NULL)
    return LUA_ERRERR;
  for (int i = 2; i < argc; i++) {
    if (strcmp(argv[i], "--nest") == 0) {
      if (++i >= argc) goto usage;
      nest = argv[i];
    } else if (strcmp(argv[i], "--packages") == 0) {
      if (++i >= argc) goto usage;
    } else if (strcmp(argv[i], "-o") == 0 || strcmp(argv[i], "--output") == 0) {
      if (++i >= argc) goto usage;
      output = argv[i];
    } else if (strcmp(argv[i], "--cores") == 0) {
      if (++i >= argc) goto usage;
      char *end = NULL;
      long v = strtol(argv[i], &end, 10);
      if (end == argv[i] || *end != '\0' || v < 1 || v > 1024) {
        fprintf(stderr, "generate: --cores wants a number from 1 to 1024\n");
        goto usage;
      }
      cores = (int)v;
    } else if (strcmp(argv[i], "-x") == 0 || strcmp(argv[i], "--execute") == 0) {
      execute = 1;
    } else if (argv[i][0] == '-' && argv[i][1] != '\0') {
      fprintf(stderr, "generate: unknown option '%s'\n", argv[i]);
      goto usage;
    } else {
      targets[ntargets++] = argv[i];
    }
  }
  if (nest == NULL)
    nest = default_nest();
  if (ntargets == 0)
    goto usage;
  int status = resolve_targets(L, targets, ntargets);
  free(targets);
  if (status != LUA_OK)
    return status;
  size_t len = 0;
  char *script = build_script(L, nest, pkgs, cores, &len);
  if (script == NULL)
    return LUA_ERRRUN;

  const char *where = output != NULL ? output : "-";
  if (output == NULL && !execute) {
    if (len > 0 && fwrite(script, 1, len, stdout) != len) {
      fprintf(stderr, "generate: write to stdout failed\n");
      free(script);
      return LUA_ERRFILE;
    }
    free(script);
    return LUA_OK;
  }

  /* With -o the script becomes a real, executable file; without it the
   * script is piped straight into sh, so nothing is left behind. */
  if (output != NULL) {
    FILE *f = fopen(output, "wb");
    if (f == NULL) {
      fprintf(stderr, "generate: cannot write %s\n", output);
      free(script);
      return LUA_ERRFILE;
    }
    if (len > 0 && fwrite(script, 1, len, f) != len) {
      fprintf(stderr, "generate: short write to %s\n", output);
      fclose(f);
      free(script);
      return LUA_ERRFILE;
    }
    if (fclose(f) != 0) {
      fprintf(stderr, "generate: cannot close %s\n", output);
      free(script);
      return LUA_ERRFILE;
    }
    /* chmod rather than fchmodat dance: the file is ours, and 0755 is
     * what makes ./build.sh runnable. */
    if (chmod(output, 0755) != 0)
      fprintf(stderr, "generate: warning: cannot chmod +x %s\n", output);
    fprintf(stderr, "generate: wrote %s\n", where);
  }

  if (execute) {
    char cmd[PATH_MAX];
    if (output != NULL)
      snprintf(cmd, sizeof cmd, "exec sh '%s'", output);
    else
      snprintf(cmd, sizeof cmd, "exec sh");
    int rc;
    if (output != NULL) {
      rc = system(cmd);
    } else {
      FILE *p = popen(cmd, "w");
      if (p == NULL) {
        fprintf(stderr, "generate: cannot run sh\n");
        free(script);
        return LUA_ERRRUN;
      }
      if (len > 0 && fwrite(script, 1, len, p) != len) {
        fprintf(stderr, "generate: cannot pipe script to sh\n");
        pclose(p);
        free(script);
        return LUA_ERRFILE;
      }
      rc = pclose(p);
    }
    free(script);
    if (rc == -1) {
      fprintf(stderr, "generate: cannot run sh\n");
      return LUA_ERRRUN;
    }
    /* Propagate the script's exit status: a failed build must not look
     * like a successful generate, and `generate -x` should be a drop-in
     * for `sh build.sh`, status included. */
    if (WIFEXITED(rc)) {
      if (WEXITSTATUS(rc) == 0)
        return LUA_OK;
      script_exit_status = WEXITSTATUS(rc);
      return LUA_ERRRUN;
    }
    return LUA_ERRRUN;
  }
  free(script);
  return LUA_OK;
usage:
  usage(stderr, argv[0]);
  free(targets);
  return LUA_ERRERR;
}

/* deps [--packages DIR] <pack[@sys]>... — resolve the same queue install
 * would build, and print it instead of emitting a build script. Queue
 * order is dependency order: leaves first, requested packages last. */
static int do_deps(lua_State *L, int argc, char **argv) {
  char **targets = malloc(sizeof(char *) * (size_t)argc);
  int ntargets = 0;
  if (targets == NULL)
    return LUA_ERRERR;
  for (int i = 2; i < argc; i++) {
    if (strcmp(argv[i], "--packages") == 0) {
      if (++i >= argc) goto usage;
    } else if (argv[i][0] == '-' && argv[i][1] != '\0') {
      fprintf(stderr, "deps: unknown option '%s'\n", argv[i]);
      goto usage;
    } else {
      targets[ntargets++] = argv[i];
    }
  }
  if (ntargets == 0)
    goto usage;
  int status = resolve_targets(L, targets, ntargets);
  free(targets);
  if (status != LUA_OK)
    return status;
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
  free(targets);
  return LUA_ERRERR;
}

/* search [--packages DIR] QUERY — list packages and systems in the
 * packages tree whose name contains QUERY (case-insensitive). An empty
 * QUERY lists everything. */
static int do_search(lua_State *L, int argc, char **argv) {
  const char *query = NULL;
  for (int i = 2; i < argc; i++) {
    if (strcmp(argv[i], "--packages") == 0) {
      if (++i >= argc) goto usage;
    } else if (query == NULL) {
      query = argv[i];
    } else {
      goto usage;
    }
  }
  if (query == NULL)
    goto usage;
  lua_getglobal(L, "search_packages");
  if (!lua_isfunction(L, -1)) {
    fprintf(stderr, "search: search_packages not ready\n");
    return LUA_ERRERR;
  }
  lua_pushstring(L, query);
  if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
    fprintf(stderr, "%s\n", lua_tostring(L, -1));
    return LUA_ERRRUN;
  }
  /* Rows are name<TAB>kind<TAB>recipes, preformatted by the loader. */
  lua_Integer n = luaL_len(L, -1);
  for (lua_Integer i = 1; i <= n; i++) {
    lua_geti(L, -1, i);
    const char *row = lua_tostring(L, -1);
    if (row == NULL)
      continue;
    char name[256];
    char kind[32];
    char recipes[512];
    recipes[0] = '\0';
    const char *a = strchr(row, '\t');
    if (a == NULL)
      continue;
    size_t nlen = (size_t)(a - row);
    if (nlen >= sizeof name)
      continue;
    memcpy(name, row, nlen);
    name[nlen] = '\0';
    const char *b = strchr(a + 1, '\t');
    size_t klen = b ? (size_t)(b - a - 1) : strlen(a + 1);
    if (klen >= sizeof kind)
      continue;
    memcpy(kind, a + 1, klen);
    kind[klen] = '\0';
    if (b != NULL)
      snprintf(recipes, sizeof recipes, "%s", b + 1);
    /* Systems have no recipe column; don't leave its padding behind. */
    size_t rlen = strlen(recipes);
    while (rlen > 0 && (recipes[rlen - 1] == ' ' || recipes[rlen - 1] == ','))
      recipes[--rlen] = '\0';
    if (recipes[0] != '\0')
      printf("%-24s %-8s %s\n", name, kind, recipes);
    else
      printf("%-24s %s\n", name, kind);
    lua_pop(L, 1);
  }
  lua_pop(L, 1); /* rows table */
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
    "       %s search [--packages DIR] QUERY\n"
    "       %s generate [-o FILE] [-x] [--nest DIR] <pack[@sys]>...\n"
    "       %s --help\n"
    "\n"
    "Commands:\n"
    "  install   print a POSIX sh script that builds the queued recipes for\n"
    "            <pack[@sys]> targets into per-system prefixes under --nest.\n"
    "            'pack' uses the compile-time default system (DEFAULT_SYSTEM,\n"
    "            %s by default); '@native' is an alias for that same system.\n"
    "            Dependencies resolve automatically and are emitted first.\n"
    "  generate  same script 'install' prints, but with somewhere to put it:\n"
    "            -o FILE writes the script there and makes it executable\n"
    "            (mode 0755); without -o it goes to stdout. -x runs the\n"
    "            script with sh straight after generating it and exits with\n"
    "            the script's own status, so -x alone is a one-step build.\n"
    "  deps      print each <pack[@sys]> target and all of its dependencies\n"
    "            in dependency order (leaves first), then exit. Resolves the\n"
    "            same queue 'install' would build but writes no script and\n"
    "            touches no nest: no downloads, no builds, no stamps.\n"
    "  search    list packages and systems in the packages tree whose name\n"
    "            contains QUERY, case-insensitively, one per line as\n"
    "            'name kind recipes'. An empty QUERY lists everything. Reads\n"
    "            the tree only: no recipes are run, nothing is built.\n"
    "  -e chunk  run a Lua chunk.\n"
    "  script    run a Lua file.\n"
    "\n"
    "Example:\n"
    "  %s deps 'python@aarch64-android24'\n"
    "  %s install 'python@aarch64-android24' > build.sh\n"
    "  %s generate -o build.sh -x 'python@aarch64-android24'\n"
    "\n"
    "  # --nest defaults to $HOME/.cache/retrolunar/nestdir\n"
    "\n"
    "  # for a packages tree of your own:\n"
    "  git clone https://github.com/lunardoesdev/retrolunar-packages\n"
    "  %s deps --packages ./retrolunar-packages 'python@aarch64-android24'\n"
    "  %s search python\n"
    "\n"
    "With no arguments, print this help.\n"
    "\n"
    "Options:\n"
    "  --nest DIR       output root for per-system prefixes (install);\n"
    "                   defaults to $HOME/.cache/retrolunar/nestdir\n"
    "  --packages DIR   packages tree to resolve recipes from;\n"
    "                   defaults to $HOME/.cache/retrolunar/packages, cloned\n"
    "                   from %s on first use and refreshed on later runs\n"
    "  --cores N        job count for recipes that honour $CORES;\n"
    "                   defaults to 1 (install, generate)\n"
    "  -h, --help       show this help and exit\n",
    prog, prog, prog, prog, prog, prog, RETROLUNAR_DEFAULT_SYSTEM, prog,
    prog, prog, prog, prog, PACKAGES_REPO);
}
/* Flag names, listed once. main()'s pre-scan and each subcommand's parser
 * must agree on which flags swallow the next argv entry: when they
 * disagreed, a flag's value was counted as a package name, so the run
 * cloned the packages tree for a command that was about to print usage,
 * or failed resolving a module named "--cores". */
static const char *const VALUE_FLAGS[] = {
  "--packages", "--nest", "-o", "--output", "--cores", NULL
};
static const char *const BOOL_FLAGS[] = {
  "-x", "--execute", "-h", "--help", NULL
};
static int in_list(const char *const *list, const char *s) {
  for (int i = 0; list[i] != NULL; i++)
    if (strcmp(s, list[i]) == 0)
      return 1;
  return 0;
}
static int takes_value(const char *s) { return in_list(VALUE_FLAGS, s); }
static int is_bool_flag(const char *s) { return in_list(BOOL_FLAGS, s); }

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
                    strcmp(argv[1], "deps") == 0 ||
                    strcmp(argv[1], "generate") == 0 ||
                    strcmp(argv[1], "search") == 0)) {
    /* Require at least one target before touching the network: a plain
     * `deps` with no package should not clone the tree just to then fail
     * on the usage message. `search` takes a query in that slot. */
    int targets = 0, bad = 0;
    pkgs_boot = NULL;
    for (int i = 2; i < argc; i++) {
      if (takes_value(argv[i])) {
        if (i + 1 >= argc) { bad = 1; break; }
        if (strcmp(argv[i], "--packages") == 0) pkgs_boot = argv[++i];
        else i++;
      } else if (is_bool_flag(argv[i])) {
        /* no value to skip */
      } else {
        /* An unknown flag is left to the subcommand to name precisely;
         * swallowing it here would replace that message with bare usage. */
        targets++;
      }
    }
    if (bad || (targets == 0 && strcmp(argv[1], "search") != 0)) {
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
  else if (argc >= 2 && strcmp(argv[1], "generate") == 0)
    status = do_generate(L, argc, argv, pkgs_boot);
  else if (argc >= 2 && strcmp(argv[1], "deps") == 0)
    status = do_deps(L, argc, argv);
  else if (argc >= 2 && strcmp(argv[1], "search") == 0)
    status = do_search(L, argc, argv);
  else if (argc == 3 && strcmp(argv[1], "-e") == 0)
    status = run_chunk(L, luaL_loadstring(L, argv[2]));
  else if (argc == 2)
    status = run_chunk(L, luaL_loadfile(L, argv[1]));
  else {
    usage(stderr, argv[0]);
    status = LUA_ERRERR;
  }

  lua_close(L);
  if (status == LUA_OK)
    return 0;
  return script_exit_status != 0 ? script_exit_status : 1;
}
