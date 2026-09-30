ACCEPT

# lame — stage 2 review

## What the recipe gets right

- **`make -j1` is used throughout**, including the targeted
  `make -j1 -C libmp3lame` and `make -C include install`. Note: the second
  `make` at `generic.lua:14` (`make -C include install`) has **no `-j1`** —
  it is an install-only target in a header directory with nothing to compile,
  so it cannot fan out, but for consistency it should be `make -j1 -C include
  install`.
- `--disable-frontend` correctly suppresses the `lame` and `lamefront` GUI/CLI
  programs; `--disable-gtktest` drops the gtk test; `--disable-nasm` avoids a
  host assembler dependency.
- The targeted subdirectory install (`libmp3lame` + `include`) is the right
  shape — it installs the library and headers without building the frontend.
- No `sed`, no patch, no `/dev/null`, no `DESTDIR`, no exported search flag.

## What the forecast should add

`make -C libmp3lame install` without `-j1` on the preceding line is a
consistency miss, not a correctness one. Note it so the next reader does not
copy the pattern.

Also record: lame's `Makefile.am` builds `mpg123` and `twolame` as
`noinst_PROGRAMS` unless disabled. Those are target binaries built by
`make -j1` even though only `libmp3lame` is installed. Allowed, but worth
stating.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libmp3lame.a` | `ls $PREFIX/lib/libmp3lame.*` — static, confirming `--disable-shared --enable-static` |
| `$PREFIX/include/lame/lame.h` | `test -f $PREFIX/include/lame/lame.h` |
| `$PREFIX/lib/pkgconfig/mp3lame.pc` | `pkg-config --modversion mp3lame` — note the `.pc` name is `mp3lame`, not `lame` |
| no frontend | `test ! -e $PREFIX/bin/lame`, proving `--disable-frontend` took |
