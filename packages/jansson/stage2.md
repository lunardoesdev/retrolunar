ACCEPT

# jansson — stage 2 review

## What the recipe gets right

- **`make -j1` at `generic.lua:10`** — serialised correctly, which is the rule
  most often missed in this shard.
- The timestamp guard at line 8 is the standard form and `jansson` ships a
  top-level `config.h.in`, so it names the right file (verified in the
  unpacked tree).
- `--enable-static --disable-shared --with-pic` is this prefix's usual
  static trio, and `--with-pic` is a real libtool option (the shipped
  `configure` handles `pic_mode`).
- Flags come from `$AUTOCONF_CONFIGURE_FLAGS`; nothing hardcoded, no search
  flag exported. No `sed`, no patch, no `/dev/null`, no `DESTDIR`.

## What the forecast should add

Nothing blocking. One observation worth recording: jansson builds docs and a
test suite, and the recipe passes no `--disable-*` for either. If the build
pulls in a host doc tool this tree lacks, that is where it fails first — so the
forecast should state which subdirectories `make -j1` actually builds.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libjansson.a` | `ls $PREFIX/lib/libjansson.*` — static, confirming the flags took |
| `$PREFIX/include/jansson.h` | `test -f $PREFIX/include/jansson.h` |
| `$PREFIX/lib/pkgconfig/jansson.pc` | `pkg-config --modversion jansson` |
| no CLI tools | `find $PREFIX/bin -name "json-*"` → empty |
