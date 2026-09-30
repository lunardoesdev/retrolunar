REJECT

# ncurses — stage 2 review

## Required changes

1. **`packages/ncurses/generic.lua:14` — the timestamp guard touches a
   `config.h.in` that does not exist.** I verified in the unpacked tree:
   ncurses ships **no** `config.h.in`. Its config template is
   `include/ncurses_cfg.hin`, from `configure.in:44`:

   ```
   AC_CONFIG_HEADERS([include/ncurses_cfg.h:include/ncurses_cfg.hin])
   ```

   (`ncurses` has no `configure.ac`; it is a `configure.in` project, which is
   why the usual `configure.ac` lookup finds nothing.) So line 14 creates a
   bogus empty `config.h.in` and leaves the real template stale — meaning make
   can still re-run the header regeneration the guard exists to suppress.

   Replace line 14 with:

   ```sh
           touch aclocal.m4 configure include/ncurses_cfg.hin
   ```

   with a comment: `# include/ncurses_cfg.hin: configure.in:44 is
   AC_CONFIG_HEADERS([include/ncurses_cfg.h:include/ncurses_cfg.hin]).`

2. **`packages/ncurses/generic.lua:16` — bare `make`, violating the
   serial-build rule** (`AGENTS.md:226-229`). Change to `make -j1`.

3. **The recipe builds a shared library, which is a departure from this
   prefix's static convention and should be justified in a comment.**
   `generic.lua:7` passes `--with-shared` and there is no `--disable-static`
   equivalent, so ncurses installs `.so` objects into `$PREFIX/lib`. That is
   defensible — ncurses' `tic`/`infocmp` and the wide-character ABI are
   awkward to build static-only, and it is a deliberate choice — but
   `AGENTS.md:29` asks for non-obvious choices to be explained, and there is
   no comment. Add one above line 7 saying why shared is required here.

4. **`generic.lua:18-27` — the nine `ln -sf` lines need a comment.** These are
   the name-alias workarounds (`libcurses.so` → `libncursesw.so`, etc.). They
   are exactly the kind of recipe-local workaround `AGENTS.md` requires to be
   explained, and they are currently unexplained. Add, above line 18:

   ```sh
           # Consumers in this tree link the un-suffixed names (curses,
           # form, menu, panel); ncurses builds only the wide-char ones, so
           # alias them here. Same shape as the libpng libzlib -> libz alias
           # in packages/libpng/generic.lua.
   ```

## What the forecast should also record

ncurses is a **leaf dependency of `less`** (`packages/less/generic.lua:2`),
so it gates more than it looks like it does. Whatever verdict this package
gets propagates to `less` and to anything else needing terminfo. Worth a line
in `stage1.md`.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libncursesw.so` | `ls $PREFIX/lib/libncursesw.so` |
| `$PREFIX/bin/tic`, `$PREFIX/bin/infocmp` | `test -x $PREFIX/bin/tic` |
| `$PREFIX/share/terminfo` populated | `find $PREFIX/share/terminfo -name 'xterm*' \| head -1` non-empty |
| the aliases | `test -L $PREFIX/lib/libcurses.so` and `readlink $PREFIX/lib/libcurses.so` → `libncursesw.so` |
| `.pc` aliases | `test -L $PREFIX/lib/pkgconfig/ncurses.pc` |
| **the guard fix** | the build log must contain no header-regeneration step for `include/ncurses_cfg.hin` |