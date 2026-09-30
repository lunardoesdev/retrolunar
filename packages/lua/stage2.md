ACCEPT

# lua — stage 2 review

## What the recipe gets right

- **`make -j1` is not applicable here** and its absence is not a violation:
  the recipe never invokes `make`. It compiles a fixed object list with a
  `for` loop, which is serial by construction — arguably the most literal
  reading of `AGENTS.md:226-229`.
- **The `lua.c`/`luac.c` exclusion is correct and necessary.** Both define
  `main()`, so compiling them into the library would collide at link time. The
  `case "$_s" in */lua.c|*/luac.c) continue;; esac` guard is the right shape,
  and it means no interpreter is built — which is what a library-only package
  wants.
- **Toolchain comes from the system**: `$CC`, `$CFLAGS`, `$AR`, `$RANLIB`.
  Nothing is hardcoded and nothing is `export`ed.
- **No `sed`, no patch, no `/dev/null`, no `DESTDIR`.**
- The `.pc` is written with a `cat` heredoc, which `AGENTS.md:225` explicitly
  permits ("only `cp`, `./configure`, `cmake`, `make`, `make install`,
  `touch`, `find`, `mkdir`, `cat`-heredocs").
- `-DLUA_COMPAT_5_3` is a real, deliberate compatibility choice and it is
  recorded in the recipe.

## What the forecast should add

1. **The `.pc` `Version: 5.4.8` at `generic.lua` is hardcoded** and will go
   stale silently when lua is bumped, because nothing ties it to
   `source.lua`'s version. `lua.pc` in the heredoc already takes
   `prefix`/`exec_prefix`/`libdir`/`includedir` from the environment; the
   `Version:` line should come from the same source of truth. The forecast
   should at least record the coupling, because a version bump that misses
   this line produces a `.pc` that lies about the library.

2. **`Libs: -L${libdir} -llua -lm`** hardcodes `-lm`. That is fine on glibc
   (where `pow`/`log` are in libc) and *also* fine on Android, because the
   Android systems put `-lm` in `LDFLAGS` unconditionally and every consumer
   gets it (`packages/aarch64-android24/generic.lua:75-79`). Worth stating so
   nobody "fixes" it.

3. **`$AR rcs` + `$RANLIB` is correct for a hand-rolled archive**, and it is
   the right call given no libtool here.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/liblua.a` | `llvm-nm --defined-only $PREFIX/lib/liblua.a \| grep -c ' T lua_'` → a large count |
| no `main` in the archive | `llvm-nm $PREFIX/lib/liblua.a \| grep -c ' T main'` → **0**, proving the `lua.c`/`luac.c` guard worked |
| `$PREFIX/include/lua.h`, `luaconf.h`, `lualib.h`, `lauxlib.h` | `test -f $PREFIX/include/lua.h` and `test -f $PREFIX/include/luaconf.h` |
| `$PREFIX/lib/pkgconfig/lua.pc` | `pkg-config --modversion lua` → must print the version `source.lua` pins; a mismatch here is the hardcoded `Version:` line |
| C++ header present | `test -f $PREFIX/include/lua.hpp` |