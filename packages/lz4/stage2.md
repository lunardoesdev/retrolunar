ACCEPT

# lz4 — stage 2 review

## What the recipe gets right

- **No bare `make` fans out.** `generic.lua:8-11` uses
  `make -C lib PREFIX="$OUT" BUILD_SHARED=no BUILD_STATIC=yes` and the same for
  `programs`, each followed by its own `install`. lz4's Makefiles are small
  and single-purpose, so `-C lib` / `-C programs` is reasonable granularity —
  but **none of the four carries `-j1`**, so read strictly against
  AGENTS.md:226-229 these are deviations. They cannot do much damage (the trees
  are a handful of files) but should be `make -j1 -C lib ...` for consistency.
- `BUILD_SHARED=no BUILD_STATIC=yes` matches the prefix's static convention;
  lz4 does not use autotools, so these are upstream's own variable names,
  correctly spelled.
- `PREFIX="$OUT"` installs straight into the staging dir, per AGENTS.md:237-238.
- No `sed`, no patch, no `/dev/null`, no `DESTDIR`.

## What the forecast should add

`make -C programs` builds the `lz4` and `lz4c` CLI tools and installs them into
`$PREFIX/bin`. They are target binaries nothing here can run — allowed, since
they are not host programs, but the forecast should say so explicitly so a
reviewer does not flag them. If the prefix wants the library only, drop the
`programs` build and its install.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/liblz4.a` | `ls $PREFIX/lib/liblz4.*` — static, confirming `BUILD_SHARED=no` |
| `$PREFIX/include/lz4.h` | `test -f $PREFIX/include/lz4.h` |
| `$PREFIX/lib/pkgconfig/liblz4.pc` | `pkg-config --modversion liblz4` — the .pc is `liblz4`, not `lz4` |
| CLI tools present | `test -x $PREFIX/bin/lz4` — target binaries, never executed here |
| no `.so` | `test ! -e $PREFIX/lib/liblz4.so` |
