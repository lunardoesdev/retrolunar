REJECT

# libpipeline — stage 2 review

## Required changes

1. **`packages/libpipeline/generic.lua:9` — bare `make`, violating the
   serial-build rule** (`AGENTS.md:226-229`). Change to `make -j1`.

## What the forecast gets right

The timestamp guard is **correct**: `configure.ac` is
`AC_CONFIG_HEADERS([config.h])` and `libpipeline/config.h.in` is on disk, so
`touch aclocal.m4 configure config.h.in` at line 8 names the right file.

The recipe is otherwise conventional — flags from `$AUTOCONF_CONFIGURE_FLAGS`,
`make install` into `$OUT`, no `sed`, no patch, no `/dev/null`, no exported
search flag. It does not pass the prefix's usual
`--enable-static --disable-shared --with-pic`, which is worth a note in the
forecast: libpipeline then builds both static and shared by libtool default.
If that is deliberate, a comment saying so is needed per `AGENTS.md:29`; if
not, the three flags should be added for consistency with every other autotools
package in this shard.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libpipeline.a` (and/or `.so`) | `ls $PREFIX/lib/libpipeline.*` |
| `$PREFIX/include/pipeline.h` | `test -f $PREFIX/include/pipeline.h` |
| `$PREFIX/lib/pkgconfig/libpipeline.pc` | `pkg-config --modversion libpipeline` |
| static-vs-shared is explicit | `ls $PREFIX/lib/libpipeline.*` — if both appear, the recipe does not pin the mode and that should be a deliberate, commented choice |