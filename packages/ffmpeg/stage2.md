ACCEPT

# ffmpeg — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the recipes.
I did not build.

ffmpeg has no line in `topackage.md` (it is not an LFS package), so nothing
here has been recorded as built and the defects below are live.

## What the recipe gets right, and it is a lot

This is the most rule-correct recipe in the shard:

- `--arch="$ffmpeg_arch"` and `--target-os="$HOST_OS"` in `android.lua`, driven
  by the system's `$HOST_ARCH`/`$HOST_OS` rather than a hardcoded triplet —
  exactly what AGENTS.md prescribes for the FFmpeg family ("they read the
  machine facts (`$HOST_ARCH`, `HOST_OS`) and spell them their own way"). The
  `case` for `armv7a`→`arm` and `i686`→`x86` is the right translation and is
  commented.
- `--extra-cflags` / `--extra-ldflags` in **both** files, because ffmpeg's
  hand-written configure ignores the environment. AGENTS.md blesses this exact
  pattern for the ffmpeg family.
- `--enable-static --disable-shared`, `--disable-doc`, `--disable-programs`,
  `--disable-network`, `--disable-iconv` — a library-only build with no CLI
  tools, which is the right shape for a target prefix.
- `make -j1` is serial on both lines. `make install` is an install target, not
  a compile, so it is not a serial-build violation.
- The `android.lua` / `generic.lua` split is the right one-file-per-family
  pattern with no per-target copies.

## Required changes

### 1. `packages/ffmpeg/generic.lua:17` — `--extra-cflags="$CPPFLAGS"` drops the system's optimisation and PIC flags

`android.lua:24` passes `--extra-cflags="$CFLAGS"`, which on Android is
`-O2 -fPIC -I$PREFIX/include -DANDROID -isystem $SYSROOT/usr/include`.
`generic.lua:17` passes `--extra-cflags="$CPPFLAGS"`, which on `clang-native`
is only `-I$PREFIX/include` — so the native build gets **no `-O2` and no
`-fPIC`** from the system, while every other package in the prefix does.

`--enable-pic` is passed separately and covers PIC for ffmpeg's own objects, so
this is not a hard failure, but the two files are inconsistent and AGENTS.md's
ffmpeg note describes `--extra-cflags`, which points at `$CFLAGS` being the
intended value in both.

**Change line 17's `--extra-cflags="$CPPFLAGS"` to `--extra-cflags="$CFLAGS"`.**

### 2. `packages/ffmpeg/generic.lua:16` — the comment names variables that do not exist

The comment says android.lua "reads `$TARGET_ARCH`/`$TARGET_OS` from the
system". The systems export **`$HOST_ARCH` and `$HOST_OS`**
(`packages/aarch64-android24/generic.lua:99-100`), and `android.lua:16` and
`:24` correctly use those names. There is no `$TARGET_ARCH` or `$TARGET_OS`
anywhere in the tree, so the comment points a future editor at a variable that
does not exist. Fix it to `$HOST_ARCH`/`$HOST_OS`.

### 3. `packages/ffmpeg/stage1.md` — check the artifact list against `--disable-programs`

`--disable-programs` means ffmpeg, ffprobe, ffplay and every other CLI is off,
so `bin/` should be empty. If `stage1.md` lists any `bin/ff*` binary, that is a
forecast error of the same class as expat's `xmlwf` — a target program the
recipe never asked for. Given the recipe disables programs explicitly here,
`stage1.md` is the more likely place for the mistake.

Also record that `--disable-network` removes the network protocols, so
`libavformat`'s URL handlers are gone. That is a deliberate choice but it
belongs in `readme.md` for a consumer.

### 4. Nothing else is required

No `require()` names a missing package. `android.lua`'s `require` list
(`zlib`, `bzip2`, `xz`, `opus`, `libvpx`, `lame`) is exactly the set of
`--enable-*` flags on the configure line, and every one of those packages
exists.

## Carried to the build

- `lib/libavcodec.a`, `lib/libavutil.a`, `lib/libavformat.a`, `lib/libswscale.a`, `lib/libswresample.a` — `llvm-objdump -f lib/libavcodec.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw).
- `include/libavcodec/avcodec.h` and the rest of `include/libav*` — `[ -f include/libavcodec/avcodec.h ]`.
- `lib/pkgconfig/libavcodec.pc`, `libavutil.pc`, `libavformat.pc`, `libswscale.pc`, `libswresample.pc` — `pkg-config --modversion libavcodec` → the pinned version. Five `.pc` files, one per installed library, all inside the loader's rewrite set.
- The libraries must be **static**; a `libavcodec.so*` means `--enable-static` did not take.
- `bin/` must be **absent** — `--disable-programs` did its job. An `ffmpeg` binary here is the check that the switch took.
- **Never run anything ffmpeg installs.**

## Rework verification

**Verdict: ACCEPT.** First line changed from `REJECT` to `ACCEPT`.

### What was correctly fixed

**1. Change 1 landed.** `generic.lua:17` now reads `--extra-cflags="$CFLAGS"`,
not `$CPPFLAGS`. Verified this matters and that `$CFLAGS` is the right value:
`packages/clang-native/generic.lua:24-26` builds `CPPFLAGS="-I$PREFIX/include"`
and folds it into `CFLAGS="$CFLAGS $CPPFLAGS"`, so `$CFLAGS` is `-O2 -fPIC
-I$PREFIX/include` — the `-O2`/`-fPIC` the old line was dropping. Both files
now pass `$CFLAGS`, which is what AGENTS.md's ffmpeg note describes.

**2. Change 2 landed.** `generic.lua:16` now says ffmpeg "read
`$HOST_ARCH`/`$HOST_OS` from the system". Those are the real names:
`packages/aarch64-android24/generic.lua:99-100` sets `HOST_ARCH="aarch64"` /
`HOST_OS="android"`, and `packages/clang-native/generic.lua:47-48` sets
`x86_64`/`linux`. There is no `$TARGET_ARCH`/`$TARGET_OS` in the tree. The
stale pointer to a non-existent variable is gone.

**3. Change 3 is satisfied.** `stage1.md:6` already reads "**no programs at
all** — `--disable-programs` is passed, so `bin/` should not exist", and the
verification section repeats it. The forecast and the recipe agree.

### `$HOST_ARCH`/`$HOST_OS` verified against ffmpeg's own configure

The brief asked me to confirm this rather than accept it. ffmpeg's configure
is hand-written (libav style): `--host`/`--build` are **not** options. The
`--host*` entries in its help are `--host-cc`, `--host-cflags`,
`--host-os` etc. (host-*tools*), and anything else hits
`echo "Unknown option \"$1\"."` at `configure:4299`. So reading the system's
machine facts is the only mechanism available, and it is what
`android.lua:16-20` does.

Confirmed against the real script: defaults come from the *build* machine —
`target_os_default=$(tolower $(uname -s))` (`configure:4109`) and
`arch_default=$(uname -m)` (`configure:4120`) — which is exactly why an
unguarded cross build would silently produce host objects. `--arch` is a real
option (`configure:368`), `--target-os` is a real `set_default`
(`configure:4674`), and `android` is a recognised `target_os` value
(`configure:4675`, `:5728`). The `case` translation is right for both
renames: ffmpeg's arch spellings at `configure:4625` take `arm` and `x86`
families, not `armv7a`/`i686`.

### Which file actually gets used, and is the split justified?

**`android.lua` wins on every Android target, and `generic.lua` on
`clang-native` and `x86_64-mingw` — nothing in between.** The mechanism is
`recipe_fallbacks` (`src/loader.lua:190-198`): a system whose own
`generic.lua` declares `recipe_fallbacks = {"android"}` resolves
`ffmpeg@<sys>` to `packages/ffmpeg/android.lua` before falling through to
`packages/ffmpeg/generic.lua`. I counted: **56 of the 57** system dirs
declare `{"android"}`; the only two that do not are `x86_64-mingw` and
`clang-native`. So the android file is reached by fallback, not by a
per-target copy — the AGENTS.md one-file-per-family pattern, correctly done,
with no duplicated per-API-level recipes.

**On the split itself:** there is **no package-local module**. I checked —
`packages/ffmpeg/` contains only `generic.lua`, `android.lua`, `source.lua`
and the two `.md` files, and neither `.lua` requires anything but the six
dependency packages and `ffmpeg@source`. The brief's premise of a delegating
module does not match the tree; both files carry their own full copy of the
configure line.

That is the real drift hazard, and it is worth naming rather than waving
through. The two configure lines are ~700 characters each and differ in
exactly one flag:

```
$ grep -o '\--[a-z-]*' generic.lua | sort > g; grep -o '\--[a-z-]*' android.lua | sort > a; diff g a
0a1,4   (the --arch/--target-os values, unquoted so they split)
11a16
> --enable-cross-compile
```

So the drift risk is real but currently **zero** — every dependency flag,
`--enable-static`, `--disable-*` and the `--extra-*` pair is byte-identical,
and only `--enable-cross-compile --arch --target-os` is added. I diffed them
to confirm rather than assume. Two copies of a 700-char line is a latent
hazard, but it is the AGENTS.md-sanctioned shape for a per-family
configure, and the alternative (a shared module) would have to re-derive
`$CC`/`$AR`/`$STRIP` per system for no gain. **Justified**, with the caveat
that any future flag change must be made in both files.

### The mingw row

`generic.lua` passes **no** `--arch` and **no** `--target-os`, so on
`x86_64-mingw` ffmpeg falls back to `uname -m`/`uname -s` → Linux x86_64
objects for a Windows target. `stage1.md:15` already records this honestly as
**UNCERTAIN** with the right reasoning, and no change to it was required. Not
a rework defect — it is a known, documented gap in the only family that has
no file of its own. If ffmpeg is ever wanted on mingw it needs a
`mingw.lua`; that is future work, and `stage1.md` is right to say so.

### Damage check

- No `export` of search flags in either recipe; `$AR`/`$RANLIB`/`$STRIP`/
  `$CC`/`$CXX` are consumed from the system, which exports them
  (`aarch64-android24/generic.lua:44-49`, `clang-native:10-14`,
  `x86_64-mingw:11-14`).
- No `sed`, no `patch`, no `/dev/null`.
- `make -j1` on both build lines (`generic.lua:18`, `android.lua:25`);
  `make install` is an install target, not a compile.
- Every `require()` names a package that exists under `packages/`: `zlib`,
  `bzip2`, `xz`, `opus`, `libvpx`, `lame`, `ffmpeg@source`. Confirmed.
- No hardcoded target facts. `--arch` is derived from `$HOST_ARCH` through a
  translation table, never a literal.
- `--disable-iconv` present in both files, which `stage1.md:20-27` identifies
  as the load-bearing API-21 flag. Correct.
- Nothing broken by the adder.
