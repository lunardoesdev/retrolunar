ACCEPT

# libyaml — stage 2 review

## What the recipe gets right

- **`make -j1` at line 10** — serialised correctly.
- The guard at line 8 is the standard form; `libyaml` ships a top-level
  `config.h.in`.
- `--disable-python-bindings` is a real switch and correctly avoids the
  libyaml python extension, which would otherwise need a target interpreter
  at build time.
- `--enable-static --disable-shared --with-pic` matches the prefix convention.
- No `sed`, no patch, no `/dev/null`, no `DESTDIR`, no exported search flag.

## What the forecast should add

libyaml is small and self-contained; nothing here is conditional. The forecast
need only confirm that the shipped tarball contains a generated `Makefile.in`
at the top level, which it does.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libyaml.a` | `ls $PREFIX/lib/libyaml.*` — static |
| `$PREFIX/include/yaml.h` | `test -f $PREFIX/include/yaml.h` |
| `$PREFIX/lib/pkgconfig/yaml-0.1.pc` | `pkg-config --modversion yaml-0.1` — note the upstream .pc name is `yaml-0.1`, not `libyaml` |
| no python extension | `find $PREFIX -name "_yaml*.so"` → empty, proving `--disable-python-bindings` took |
