ACCEPT

# nghttp2 — stage 2 review

## What the recipe gets right

- **`make -j1` at line 11** — serialised correctly.
- The guard at line 9 is the standard form; `nghttp2` ships a top-level
  `config.h.in`.
- **The `--disable-*` set is thorough and each name is real**:
  `-Ddisable-app` (the `app/` HTTP/2 client and server), `--disable-examples`,
  `--disable-tests`, `--disable-python-bindings`, `--disable-rust-bindings`.
  The last two matter: both would need an interpreter at build time.
- The `--without-*` set (`--without-libxml2 --without-libevent-openssl
  --without-jansson --without-c-ares --without-libev --without-zlib`) keeps
  every optional external dependency off, which is right for a prefix that has
  none of them. nghttp2's lib only needs libev optionally, so this is safe.
- `--enable-static --disable-shared --with-pic` matches the prefix convention.
- No `sed`, no patch, no `/dev/null`, no `DESTDIR`, no exported search flag.

## What the forecast should add

nghttp2's `--disable-app` removes the `nghttp`/`nghttpd` programs, which are
this package's main visible output. The forecast should say plainly that
this recipe ships the **library only** with no CLI, so a consumer expecting
`nghttp` does not find it — and note that `--disable-app` is upstream's
spelling with an `=` but no `=`, which is easy to mistype as
`--disable-app=yes`.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libnghttp2.a` | `ls $PREFIX/lib/libnghttp2.*` — static |
| `$PREFIX/include/nghttp2/nghttp2.h` | `test -f $PREFIX/include/nghttp2/nghttp2.h` |
| `$PREFIX/lib/pkgconfig/libnghttp2.pc` | `pkg-config --modversion libnghttp2` |
| no CLI | `test ! -e $PREFIX/bin/nghttp`, proving `--disable-app` took |
