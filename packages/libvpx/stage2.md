ACCEPT

# libvpx — stage 2 review

## What the recipe gets right

- **The two-file split is correct and is the model for the shard.**
  `generic.lua` and `android.lua` are separate recipes, and `android.lua:2-4`
  says *why* it is one file rather than per-target: every Android system lists
  `android` in `recipe_fallbacks`, which is exactly the arrangement
  AGENTS.md:199-204 requires. I confirmed all 60 `packages/*android*/generic.lua`
  files carry `recipe_fallbacks = {\"android\"}`.
- **Both files correctly state that the autotools guard does not apply.**
  `generic.lua:5-7` explains that libvpx's configure is hand-written
  (FFmpeg-family), so `$AUTOCONF_CONFIGURE_FLAGS` does not apply, `--host` and
  `--build` are rejected, and the machine facts come from `$HOST_ARCH` /
  `$HOST_OS`. That is AGENTS.md:213-217 followed precisely, and — importantly —
  neither file carries a pointless `touch aclocal.m4` line.
- **`--enable-pic` in both recipes is correct and load-bearing.** The prefix
  also holds shared libraries, and a non-PIC archive cannot be linked into a
  consumer's `.so`.
- **The `--sysroot` placement is right.** `android.lua:21-22` passes
  `--sysroot=$SYSROOT` via `--extra-cflags`/`--extra-cxxflags` rather than
  `-isystem`, and the comment above it names the exact trap: as `-isystem` it
  reorders libc++ ahead of its own C headers and breaks `<cstdint>`. This is
  AGENTS.md:239-243, and it is the specific trap a careless editor would
  reintroduce.
- **`make -j1` in both files** — serialised correctly.
- The `case "$HOST_ARCH"` in `android.lua:11-15` has a `*)` arm, which is
  precisely what `packages/openssl/generic.lua:17-22` is missing. It maps
  `aarch64` to libvpx's `arm64` and `i686` to libvpx's `x86`, both of which are
  libvpx's own spellings, and passes everything else through.
- No `sed`, no patch, no `/dev/null`, no `DESTDIR`, no exported search flag.

## What the forecast gets right that a reviewer should not skip

Its risk #2 — that the four `--disable-*` switches are duplicated verbatim
between the two recipes and that this duplication is **correct** — is the right
call and worth repeating. A shared module would have to be `require`d by both,
and the two configure invocations differ enough (tuple, extra-cflags) that
factoring them would obscure more than it saves. The forecast explicitly says
"do not fix it", which is the correct instruction.

## One thing the forecast should add

`x86_64-mingw` and `clang-native` both reach `generic.lua`, which passes **no
target tuple at all** and relies on libvpx detecting the host. The forecast
calls this "the easy case". It is worth a sentence more, because libvpx's
host detection has to land on a Windows target for mingw — and this is the row
most likely to surprise, since a mis-detected tuple produces a library that
configures cleanly and links to nothing. `generic.lua` has no `case` and
therefore no failure mode if detection goes wrong; a reviewer should at least
confirm the forecast checked what libvpx's `configure` does with
`$CC=x86_64-w64-mingw32-gcc`.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libvpx.a` | `ls $PREFIX/lib/libvpx.a` — static, confirming `--enable-static --disable-shared` |
| `$PREFIX/include/vpx/vpx_encoder.h`, `vpx_decoder.h` | `test -f $PREFIX/include/vpx/vpx_encoder.h` |
| `$PREFIX/lib/pkgconfig/libvpx.pc` | `pkg-config --modversion vpx` — note the pkg-config module is `vpx`, not `libvpx` |
| make fragments | `ls $PREFIX/lib/pkgconfig/vpx_*.mk` — non-empty |
| no tools or examples | `test ! -e $PREFIX/bin/vpxdec` and `test ! -e $PREFIX/bin/vpxenc`, proving `--disable-tools --disable-examples` took |
| **PIC really in the archive** | `llvm-readelf -S $PREFIX/lib/libvpx.a \| grep -c '\.rela.text'` → non-zero relocations against code sections prove `-fPIC` objects, which `--enable-pic` is there to deliver |
