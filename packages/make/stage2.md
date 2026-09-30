REJECT

# make — stage 2 review

## Required changes

1. **`packages/make/generic.lua:7` — the timestamp guard touches a
   `config.h.in` that does not exist.** In the unpacked tree, make's
   `configure.ac` is `AC_CONFIG_HEADERS([src/config.h])`, so the template is
   **`src/config.h.in`** (verified present). There is no top-level
   `config.h.in`, so line 7 creates a bogus empty file and leaves the real
   template stale.

   Replace line 7 with:

   ```sh
           touch aclocal.m4 configure src/config.h.in
   ```

   with a comment: `# src/config.h.in: make's configure.ac is
   AC_CONFIG_HEADERS([src/config.h]).`

   This is the same shape as oniguruma, which a previous reviewer flagged and
   fixed; make was missed.

2. **`packages/make/generic.lua:9` — bare `make`, violating the
   serial-build rule** (`AGENTS.md:226-229`). Change to `make -j1`.

   Note this one is slightly awkward to read — building GNU make with a bare
   `make` inside a package also called `make` is exactly the kind of thing that
   invites an accidental fan-out. `-j1` removes the ambiguity.

## What the forecast gets right

The recipe is otherwise conventional: flags from `$AUTOCONF_CONFIGURE_FLAGS`,
`make install` into `$OUT`, no `sed`/`patch`/`/dev/null`, no exported search
flag. Note that `packages/make` is a **host tool** in practice — every other
package's build runs `make -j1` from the build machine's PATH, not from
`$PREFIX/bin/make` — which is why the Android systems deliberately do not
prepend `$PREFIX/bin` to `PATH` (`AGENTS.md:321-325`). Worth a line in
`stage1.md` so nobody adds `require("make")` expecting it to supply the host
make.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/bin/make` | `test -x $PREFIX/bin/make` |
| `$PREFIX/share/man/man1/make.1` | `test -s $PREFIX/share/man/man1/make.1` |
| target binary, never executed here | `file $PREFIX/bin/make` shows the target arch — do not run it |
| **the guard fix** | the build log must contain no `autoheader` invocation |