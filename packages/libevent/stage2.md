ACCEPT

# libevent — stage 2 review

## What the recipe gets right

- **`make -j1` at line 11** — serialised correctly.
- The guard at line 9 is the standard form; `libevent` ships a top-level
  `config.h.in`.
- `--disable-samples --disable-libevent-regress --disable-benchmark` keep the
  sample programs, the regression suite and the benchmark out. This is the
  **same defect class libseccomp has** — libevent's `test/` and
  `sample/` subdirectories are real and would otherwise be descended into by
  `make -j1` — and here the flags handle it correctly. Worth noting as the
  positive counterpart to the libseccomp finding.
- `require("openssl")` puts openssl in the queue first, so `--enable-openssl`
  finds it in `$PREFIX`.
- `--enable-static --disable-shared --with-pic` matches the prefix convention.
- No `sed`, no patch, no `/dev/null`, no `DESTDIR`, no exported search flag.

## A dependency worth watching

`require("openssl")` means libevent cannot build until **openssl** is fixed.
Openssl's recipe currently has the `case $HOST_ARCH` defect that makes it
target an `android-*` target with no NDK on mingw and native. So libevent's
Android verdict is gated on openssl's. The forecast should say so rather than
claiming an independent verdict.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libevent.a`, `libevent_core.a`, `libevent_extra.a` | `ls $PREFIX/lib/libevent*.a` — three static archives |
| `$PREFIX/include/event2/event.h` | `test -f $PREFIX/include/event2/event.h` |
| `$PREFIX/lib/pkgconfig/libevent.pc`, `libevent_core.pc`, `libevent_extra.pc` | `pkg-config --modversion libevent` |
| openssl really linked | `llvm-nm --undefined-only $PREFIX/lib/libevent_extra.a \| grep -c SSL_` → non-zero, proving `--enable-openssl` took |
