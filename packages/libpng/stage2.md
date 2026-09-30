ACCEPT

# libpng — stage 2 review

## What the recipe gets right

- **The name-mismatch workaround at `generic.lua:7-10` is correct and matches
  the precedent in `AGENTS.md:263-265` exactly.** It is the documented case:
  mingw zlib installs as `libzlib` while libpng's `configure` hardcodes `-lz`,
  and the recipe symlinks `libz.*` → `libzlib.*` in `$PREFIX` first, guarded
  by `[ -f "$_f" ] || continue` and `[ -f "$PREFIX/lib/libz$_ext" ] ||` so it is
  idempotent and additive. It is a `ln` in a loop, not a `sed`, and not a patch
  of upstream sources.
- `require("zlib")` puts zlib in the queue first, so the symlink target exists
  by the time it is made.
- `--with-zlib-prefix="$PREFIX"` takes the search path from the system's
  `$PREFIX` rather than hardcoding one.
- **The timestamp guard is correct**: `touch aclocal.m4 configure config.h.in`
  at line 13 is the standard form and libpng really does ship a top-level
  `config.h.in`.
- **`make -j1`** at line 15 — serialised correctly.
- No `sed`, no patch application, no `/dev/null`, no exported search flag.

## What the forecast should add

The one thing worth recording is that this recipe is **mingw-specific in
effect but lives in `generic.lua`**. The `libz` → `libzlib` symlink loop is a
no-op on systems where zlib installs under its normal name, so it is harmless
there, but a reader should know why it exists. `AGENTS.md:263-265` already
documents the case; the recipe's comment says "Name-mismatch trap: mingw zlib
installs as libzlib, but libpng configure hardcodes -lz" — accurate, and it
belongs in `stage1.md` too so the forecast carries it forward.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libpng16.a` (or `.so`) | `ls $PREFIX/lib/libpng*.a` — the version suffix is upstream's, do not hardcode it |
| `$PREFIX/include/png.h`, `pngconf.h` | `test -f $PREFIX/include/png.h` |
| `$PREFIX/lib/pkgconfig/libpng.pc` | `pkg-config --modversion libpng` |
| zlib actually linked | `llvm-nm --undefined-only $PREFIX/lib/libpng*.a \| grep -c ' T inflate'` → non-zero, proving `-lz` resolved |
| **the symlink is idempotent** | `ls -l $PREFIX/lib/libz.*` → each symlink points at `libzlib.*`, and re-running the build does not duplicate or fail |