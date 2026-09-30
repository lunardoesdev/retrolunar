ACCEPT

# pcre2 — stage 2 review

## What the recipe gets right

- **`make -j1` at line 10** — serialised correctly.
- The guard at line 8 is the standard form; `pcre2` ships a top-level
  `config.h.in`.
- `--enable-pcre2-8 --enable-pcre2-16 --enable-pcre2-32` all three bit widths is
  the right choice for a general-purpose prefix, and `--disable-cpp` avoids the
  C++ wrapper that would otherwise need `$CXX`.
- `--enable-static --disable-shared --with-pic` matches the prefix convention.
- No `sed`, no patch, no `/dev/null`, no `DESTDIR`, no exported search flag.

## What the forecast should add

With all three widths enabled there are three `.pc` files with colliding
`Libs:` entries — a consumer that does `pkg-config --libs libpcre2-8` gets
`-lpcre2-8`, fine, but a consumer asking for all three gets three `-l` flags.
Worth a line in the forecast so nobody has to rediscover it.

Also: pcre2's `Makefile.am` builds `pcre2grep` and `pcre2test`. Confirm in
the forecast whether those are `noinst_PROGRAMS` (built, not installed) or
`bin_PROGRAMS` (installed). If installed, a `--disable-pcre2grep` is warranted.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libpcre2-8.a`, `-16`, `-32` | `ls $PREFIX/lib/libpcre2-*.a` — three static archives |
| `$PREFIX/include/pcre2.h` | `test -f $PREFIX/include/pcre2.h` |
| `$PREFIX/lib/pkgconfig/libpcre2-8.pc` (+ -16, -32) | `pkg-config --modversion libpcre2-8` |
| JNI off | `test ! -e $PREFIX/lib/libpcre2-jni.so` — the recipe does not pass `--enable-jni`, so confirm upstream defaults it off |
