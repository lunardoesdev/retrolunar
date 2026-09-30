# ffmpeg build forecast

- Recipe: `generic.lua` **and** `android.lua`, source `source.lua`
- Version pinned: 7.1.2
- Build system: **hand-written configure** (the libav style, not autoconf — this is why no timestamp guard appears in either recipe)
- Installs: `lib/libavcodec.a`, `lib/libavformat.a`, `lib/libavutil.a`, `lib/libavfilter.a`, `lib/libswscale.a`, `lib/libswresample.a` (static); `include/libav*/*.h`; five `lib/pkgconfig/libav*.pc`; **no programs at all** — `--disable-programs` is passed, so `bin/` should not exist
- Requires: `zlib`, `bzip2`, `xz`, `opus`, `libvpx`, `lame` (all exist), `ffmpeg@source`

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `android.lua:18-24` is the designed solution to ffmpeg's hand-written configure: `--enable-cross-compile --arch="$ffmpeg_arch" --target-os="$HOST_OS"` from the system's `$HOST_ARCH`/`$HOST_OS`, with the `armv7a`→`arm` and `i686`→`x86` renames ffmpeg needs (android.lua:19-22). `--extra-cflags="$CFLAGS"` carries `-DANDROID`, which the recipe comment names as required because ffmpeg ignores `$CFLAGS` on its own. `--disable-iconv` removes the only Bionic-relevant gap (no separate `-liconv`, and `iconv.h` is guarded before API 28). `--disable-network`, `--disable-programs` and `--disable-doc` keep every host program out. |
| aarch64-android24 | WILL BUILD | As above; nothing in ffmpeg needs an API above 21 given `--disable-iconv`. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | `--arch=x86_64` comes straight from `$HOST_ARCH`; no rename needed (`android.lua:22` falls through to `ffmpeg_arch="$HOST_ARCH"`). |
| x86_64-mingw | **UNCERTAIN** | `generic.lua` is used, and it passes **no `--target-os` and no `--arch`** at all (`generic.lua:15`). ffmpeg would then assume the build machine, i.e. produce Linux x86_64 objects for a Windows target. It would also try `--disable-iconv` (correct) but has no `--disable-x86asm`, and ffmpeg's hand-written asm would be built for the wrong platform. **My expectation is that this does not produce a usable `x86_64-w64-mingw32` prefix**, but the recipe has no mingw-specific file and I could not confirm the failure mode without running configure. Flagged as UNCERTAIN rather than WILL NOT BUILD, because the honest answer is "not shaped for this target and probably wrong". |
| clang-native | WILL BUILD | Native; `generic.lua:16` supplies the toolchain explicitly and `--extra-cflags="$CPPFLAGS"` for a hand-written configure that ignores `$CFLAGS`. |

## API level notes

**21 is the floor and ffmpeg clears it — but only because `--disable-iconv`
is in the recipe** (`android.lua:23`, `generic.lua:16`). ffmpeg's
`libavutil/tx.h` and `libavutil/parseutils.c` use `iconv.h`, which Bionic
exposes only from API 28 (I confirmed `usr/include/iconv.h` exists in the
NDK r28b sysroot, and it is behind an availability guard), and there is no
separate `-liconv` on Bionic at any level. So `--disable-iconv` is not
optional polish; without it this would be a WILL NOT BUILD at 21, 24 and
35 alike.

Everything else in the six libraries is plain POSIX + the three
codec backends this prefix supplies.

## Risks / what a reviewer should check

- **`android.lua` and `generic.lua` are not interchangeable**, and that is
  correct here: the Android one adds `--enable-cross-compile --arch
  --target-os -DANDROID`. The asymmetry is real and intentional. A
  reviewer should note that the *mingw* target is the one with no
  corresponding file, which is why that row is UNCERTAIN.
- **The `case "$HOST_ARCH"` at `android.lua:19-22` is the only place in
  this recipe that knows anything about a specific target**, and it does it
  correctly: it reads the system's fact and translates ffmpeg's spelling
  rather than hardcoding. This is exactly what AGENTS.md asks for.
- **The six backends are all static and all from this prefix.**
  `--pkg-config-flags="--static"` (android.lua:24) is essential: without it
  ffmpeg would ask pkg-config for shared-link flags and fail to find the
  static archives. Easy to break, easy to miss.
- **`--disable-libxcb` is in both recipes** and is not explained. It is
  almost certainly there because X11 is absent and ffmpeg's configure would
  otherwise probe for it. Correct, but undocumented; a comment would help.
- **ffmpeg is the slowest serial build in the shard** after coreutils, at
  `make -j1` with six libraries and three external codecs.
- **The recipe comment at `generic.lua:12-14` says cross targets "read
  `$TARGET_ARCH`/`$TARGET_OS`"**, but the actual variables used are
  `$HOST_ARCH`/`$HOST_OS` (android.lua:20-21). AGENTS.md:296 is explicit
  that in a cross build the host is the target, so the code is right and
  **the comment is wrong**. Worth correcting — it is exactly the kind of
  stale wording that leads a future agent to introduce a bug.

## How to verify once built

- `lib/libavcodec.a`, `lib/libavformat.a`, `lib/libavutil.a`,
  `lib/libavfilter.a`, `lib/libswscale.a`, `lib/libswresample.a`
- `include/libavcodec/avcodec.h`, `include/libavutil/avutil.h`
- `lib/pkgconfig/libavcodec.pc` and `pkg-config --modversion libavcodec` → `7.1.2`
- `readelf -h lib/libavcodec.a` → `Machine: AArch64` on Android targets
- `$OUT/bin` should be **empty or absent** — `--disable-programs` means no
  `ffmpeg`/`ffplay` binary
