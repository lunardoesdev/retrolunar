# flac build forecast

- Recipe: `generic.lua`, source `source.lua` (release tarball with a generated `configure`)
- Version pinned: 1.5.0
- Build system: autotools
- Installs: `lib/libFLAC.a`, `lib/libFLAC++.a` (static); `include/FLAC/*.h`, `include/FLAC++/*.h`; `lib/pkgconfig/flac.pc` (only — `ogg.pc` belongs to `packages/libogg`); **`bin/flac` and `bin/metaflac` ARE installed** — they are `bin_PROGRAMS` (`src/flac/Makefile.am:27`, `src/metaflac/Makefile.am:27`), not host programs
- Requires: `libogg` (exists), `flac@source`

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | libFLAC is plain C89 with its own integer-width detection (`FLAC__STDC_`/`configure`) and no platform dependency beyond `<stdio.h>`, `<stdlib.h>`, `<string.h>`, `<math.h>`, `<errno.h>`. libFLAC++ is a thin C++ wrapper over it using only the standard library. `--disable-version-from-git` (`generic.lua:14`) is the one recipe flag; it stops configure shelling out to `git describe` (configure.ac:514). FLAC's own test program is not built. Nothing needs an API above 21. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | Endian-neutral; FLAC's bitstream code is explicitly big-endian on the wire and handles both hosts. |
| x86_64-mingw | WILL BUILD | FLAC's own portability layer covers MSVC/mingw; `BUILD_SHARED_LIBS` is not used (autotools `--disable-shared`), so no export machinery. |
| clang-native | WILL BUILD | Native; topackage.md:214 records FLAC 1.5.0 as `[x]` with `pkg-config --modversion flac` = 1.5.0 and `elf64-littleaarch64` archive members. |

## API level notes

**21 is the floor and FLAC clears it comfortably.** FLAC is one of the
few packages here whose own `configure` actively probes for the integer
types and endianness it needs rather than assuming, so there is no
API-level coupling to reason about. `libogg` (the dependency) is
likewise plain C with no API floor.

## Risks / what a reviewer should check

- **The recipe used to claim the command line tools "stay off". They do
  not.** `flac` and `metaflac` are `bin_PROGRAMS` (`src/flac/Makefile.am:27`,
  `src/metaflac/Makefile.am:27`) and are built and installed; there is no
  switch that drops them short of `--disable-programs`, which the recipe
  does not pass. They are target programs and nothing runs them here. The
  recipe comment has been corrected to say so, and the `Installs` line with
  it. An earlier version of this file repeated the mistake and also claimed
  they were `noinst_PROGRAMS`; they are not.
- **`libogg` is required but its `.pc` is not installed by *this* recipe.**
  `libogg/generic.lua` owns `ogg.pc`; flac's `--with-ogg-prefix` is not
  passed, so configure finds libogg through the prefix's pkg-config path
  (the systems set `PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"`,
  aarch64-android21/generic.lua:82). That works, but it is implicit. The
  explicit `--with-ogg-prefix="$PREFIX"` would be more robust; the omission
  is not a bug.
- **`--disable-oggtest` is a real option in flac 1.5.0, and I was wrong to say
  otherwise.** `m4/ogg.m4:15` declares `AC_ARG_ENABLE(oggtest, ...)`,
  `configure:1581` lists `--disable-oggtest` in `--help`, and `configure:20022`
  implements it. An earlier version of this file claimed the flag "is not a
  flac 1.5.0 option at all" and the recipe removed it on that basis; the claim
  was wrong and it came from the review that ordered the change, so it
  propagated into the recipe and then into this file. What the flag actually
  does is skip a libogg `AC_RUN_IFELSE` probe (`m4/ogg.m4:50-74`), whose
  action-if-cross is an "assumed OK" echo (`m4/ogg.m4:71`) — so under
  cross-compiling it changes nothing and omitting it is harmless, which is why
  the recipe is fine without it. The claim that it does not exist was the
  error.
- **`--disable-version-from-git` is the flag that actually earns its place.**
  The new flag is load-bearing: without it configure shells out to
  `git describe` (configure.ac:514), and AGENTS.md keeps git out of the build
  path. FLAC's own round-trip checker is not built by this recipe either way,
  so "FLAC builds" carries no evidence that FLAC *works*.
- **`libFLAC++` needs the NDK's `libc++`**, which every Android target has.
  No extra dependency.

## How to verify once built

- `lib/libFLAC.a`, `lib/libFLAC++.a`
- `include/FLAC/decoder.h`, `include/FLAC++/decoder.h`
- `lib/pkgconfig/flac.pc` and `pkg-config --modversion flac` → `1.5.0`
- `readelf -h lib/libFLAC.a` → `Machine: AArch64` on Android targets
- `bin/flac` and `bin/metaflac` **must be present**. They are `bin_PROGRAMS`
  (`src/flac/Makefile.am:27`, `src/metaflac/Makefile.am:27`) under a
  conditional that defaults true, and nothing in the recipe suppresses them,
  so a build that omits them has *dropped* the tools, not honoured a flag. An
  earlier version of this line said they should be absent; that would have
  failed a perfectly good build. **Never run them** — target binaries.
