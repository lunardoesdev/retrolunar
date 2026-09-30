ACCEPT

# hello — stage 2 review

## What the recipe gets right

- **No upstream exists** — `packages/hello/source.lua` copies a 7-line
  `main.c` out of `$RECIPEDIR`, and there is no download, no version pin and
  nothing to go stale. The forecast correctly says so rather than inventing a
  version.
- `$CC $CFLAGS main.c -o $OUT/bin/hello` at `generic.lua:7` takes the compiler
  and the flags from the **system**. No hardcoded target fact.
- **No `make` at all**, so the serial-build rule is satisfied by construction —
  a single `cc` invocation cannot fan out.
- No `sed`, no patch, no `/dev/null`, no `export`, no `DESTDIR`.

## One thing to note, not a defect

`generic.lua:7` passes `$CFLAGS` but **not** `$CPPFLAGS` and **not**
`$LDFLAGS`. For a single-file `printf` program that is sufficient today, but
if `main.c` ever grows an `#include <something>` from `$PREFIX/include`, or
needs a library from `$PREFIX/lib`, it will fail with a confusing error. The
forecast should note that this recipe is intentionally minimal and that
adding an include would mean adding `$CPPFLAGS`/`$LDFLAGS` here.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/bin/hello` | `test -x $PREFIX/bin/hello` |
| target arch, never executed here | `llvm-objdump -f $PREFIX/bin/hello \| grep machine` shows the target arch — do not run it |
| nothing else installed | `ls $PREFIX/lib` must not gain a `libhello.*` from this package |
