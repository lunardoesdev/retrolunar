REJECT

# libffi — stage 2 review

## Required changes

1. **`packages/libffi/generic.lua:7` — the timestamp guard touches a
   `config.h.in` that does not exist, and misses the real template.** In the
   unpacked tree, `configure.ac` is `AC_CONFIG_HEADERS([fficonfig.h])` — note
   the doubled `f`, an upstream quirk — and there is **no `config.h.in` at any
   depth**. So `touch config.h.in` creates a bogus empty file and leaves
   `fficonfig.h.in` with its tarball mtime, older than the just-touched
   `aclocal.m4`. Make can therefore still re-run the header regeneration the
   guard exists to prevent, which needs `autoheader` — not shipped in this
   prefix.

   Replace line 7 with:

   ```sh
           touch aclocal.m4 configure fficonfig.h.in
   ```

   with a comment, since the doubled `f` looks like a typo and will be
   "corrected" by the next reader:

   ```sh
           # fficonfig.h.in with two f's: configure.ac is
           # AC_CONFIG_HEADERS([fficonfig.h]). Do not "fix" the spelling.
   ```

2. **`packages/libffi/generic.lua:9` — bare `make`, violating the
   serial-build rule** (`AGENTS.md:226-229`). Change to `make -j1`.

## What the forecast gets right

The recipe is otherwise conventional and correct in shape: flags come from
`$AUTOCONF_CONFIGURE_FLAGS`, `make install` goes straight to `$OUT`, there is
no `sed`, no patch, no `/dev/null`, no exported search flag, and the static
flags are the prefix's usual `--enable-static --disable-shared --with-pic`.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libffi.a` (static) | `ls $PREFIX/lib/libffi.*` |
| `$PREFIX/include/ffi.h`, `ffitarget.h` | `test -f $PREFIX/include/ffi.h` |
| `$PREFIX/lib/pkgconfig/libffi.pc` | `pkg-config --modversion libffi` |
| **the guard fix** | the build log must contain no `autoheader` invocation — with required change 1 absent, that is the expected failure |