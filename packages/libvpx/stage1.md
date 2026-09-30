# libvpx forecast

- Recipe: **`generic.lua` + `android.lua`**, source `source.lua`
- Version pinned: 1.15.0 (git tag archive)
- Build system: **hand-written configure**, not autoconf. This is the
  FFmpeg-family case AGENTS.md:213-217 describes: `--host`/`--build` are
  rejected, and the machine facts come from `$HOST_ARCH`/`$HOST_OS` instead.
  Consequently **no autotools timestamp guard applies** to either recipe, and
  the recipe says so at `generic.lua:6-7`.
- Installs: static `libvpx.a`, the `vpx/` headers, `libvpx.pc`, and
  `vpx_codec_modules.mk` / `vpx_*.mk` make fragments. No tools: examples, docs,
  unit tests and tools are all disabled in **both** recipes.
- Requires: `libvpx@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **This is the `android.lua` path and it is the one that matters.** The Android systems list `android` in `recipe_fallbacks`, so every Android target reaches `android.lua` without a per-target copy — exactly what AGENTS.md:199-204 requires. Two things there are load-bearing: the `case "$HOST_ARCH"` mapping (libvpx spells 64-bit ARM `arm64` and 32-bit x86 `x86`, and gets `$HOST_ARCH` wrong otherwise), and `--extra-cflags="--sysroot=$SYSROOT"`. The latter is the documented libc++ include-order trap: passed as `-isystem` it reorders libc++ ahead of its own C headers and breaks `<cstdint>` (AGENTS.md:239-243). |
| aarch64-android24 | WILL BUILD | As above; the representative Android system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above; the `case` maps `x86_64` through `*)` to `$HOST_ARCH`, which is what libvpx wants. |
| x86_64-mingw | WILL BUILD via `generic.lua` | mingw is not an Android system, so it uses the plain `generic.lua`, which passes **no target tuple at all** — libvpx's configure detects the host. Since `$CC`/`$CXX` are the mingw wrappers, detection should land on a Windows target correctly. The four `--disable-*` and `--enable-static` switches are identical in both recipes. |
| clang-native | WILL BUILD via `generic.lua` | As above; native detection is the easy case and this recipe is the simplest one. |

**API level notes.** None. libvpx is freestanding C with essentially no libc
dependency, and its configure takes no API-level input. The API level is
genuinely irrelevant here, which is a good contrast with less and ninja.
`armv7a-android*` matches `aarch64-android*`; `i686-android*` matches
`x86_64-android*` in every respect that matters (libvpx's `x86` target for
32-bit is what the `case` produces).

**Risks / what a reviewer should check.**

1. **This is the best example in the shard of a system-specific recipe that is
   GOOD design, and it should be read as the model.** `android.lua:2-4`
   comments *why* the file is single rather than per-target, and
   `generic.lua:6-7` states explicitly that the hand-written configure means
   no `$AUTOCONF_CONFIGURE_FLAGS` and no timestamp guard. Both facts are
   non-obvious and both are recorded in the recipe, which is precisely the
   AGENTS.md:25-29 standard.
2. **The two recipes duplicate four switches verbatim** (the `--disable-*` set
   and `--enable-static --disable-shared`). That is duplication, but it is the
   right duplication: a shared module would have to be required by both, and
   the two configure invocations differ enough (tuple, extra-cflags) that
   factoring them would obscure more than it saves. Do not "fix" it.
3. **`--enable-static --disable-shared` are both passed, which is redundant**
   but harmless and explicit.
4. **`--enable-pic` at `android.lua:20` matters**: the archive goes into a
   prefix that also holds shared libraries, and a non-PIC object cannot be
   linked into a consumer's `.so`. Correct, and matched in `generic.lua:13`.
5. **`topackage.md` has no entry for libvpx**, yet nothing else in the tree
   currently requires it. So it is a standalone library with no recorded build
   and no known consumer. That is worth flagging: it is the kind of package
   that should be built once to confirm, or dropped if nothing needs it.
6. `make -j1` is present in both recipes (`:21` and `:16`) — correct.

**How to verify once built.**

- `lib/libvpx.a` exists; `include/vpx/vpx_decoder.h` and
  `include/vpx/vp8dx.h` exist.
- `pkg-config --modversion vpx` reports 1.15.0.
- `$OBJDUMP -f lib/libvpx.a` prints `elf64-littleaarch64` on Android,
  `pei-x86-64` on mingw.
- **The configure log is the real check on `android.lua`.** It should show the
  target line as `arm64-android-gcc` on aarch64 and `x86-android-gcc` on
  x86_64. If it shows `aarch64-android`, the `case` mapping is broken and the
  build may still succeed while producing the wrong code paths.
- `llvm-nm --defined-only lib/libvpx.a | grep -cw vpx_codec_vp8_dx_decode`
  non-zero — the canonical libvpx entry point.
- `ls $OUT/bin/` must be empty: no `vpxdec`, no `ivfdec`, no examples.
  `--disable-tools` and `--disable-examples` are both doing work.
- `find $OUT -name 'vpx_*.mk'` should find the make fragments; their presence
  is how a non-cmake consumer finds the codec list.
