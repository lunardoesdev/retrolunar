ACCEPT

# opus — stage 2 review

## What the recipe gets right

- **`make -j1` at line 10** — serialised correctly.
- The guard at line 8 is the standard form; `opus` ships a top-level
  `config.h.in`.
- `--disable-doc --disable-extra-programs` are real switches and keep the
  documentation and the example/extra programs out. Opus's `opusenc`,
  `opusdec` and `opusinfo` are `noinst_PROGRAMS`, which **`make all` builds
  anyway** — so `--disable-extra-programs` matters more here than it looks.
- `--disable-shared --enable-static` matches the prefix convention (order
  differs from its neighbours but is equivalent).
- No `sed`, no patch, no `/dev/null`, no `DESTDIR`, no exported search flag.

## What the forecast should add

Confirm in the forecast that opus's `noinst_PROGRAMS` are target binaries
built by `make -j1` even with `--disable-extra-programs`. They are not
installed, so this is allowed, but it means the build compiles three programs
this prefix does not ship — worth stating so nobody reads their presence as a
recipe defect.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libopus.a` | `ls $PREFIX/lib/libopus.*` — static |
| `$PREFIX/include/opus/opus.h` | `test -f $PREFIX/include/opus/opus.h` |
| `$PREFIX/lib/pkgconfig/opus.pc` | `pkg-config --modversion opus` |
| no tools installed | `find $PREFIX/bin -name "opusenc"` → empty, proving they were built but not installed |
