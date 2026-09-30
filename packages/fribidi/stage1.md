# fribidi build forecast

- Recipe: `generic.lua`, source `source.lua` (release asset with a `meson.build`)
- Version pinned: 1.0.16
- Build system: **meson**
- Installs: `lib/libfribidi.a` (static); `include/fribidi/`; `lib/pkgconfig/fribidi.pc`
- Requires: `fribidi@source` only

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | libfribidi is C89/C99 with a Unicode data table and no platform dependency beyond `<stdio.h>`, `<stdlib.h>`, `<string.h>` and, for the debug helpers, `<unistd.h>`. The recipe turns all three of fribidi 1.0.16's meson options off — `-Dtests=false -Ddocs=false -Dbin=false` (`generic.lua:12`) — which is correct and is exactly what the recipe comment claims: those are the only three options and all three are host-side. Nothing needs an API above 21. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | Endian-neutral; fribidi's table lookups are byte-indexed, not word-aligned. |
| x86_64-mingw | WILL BUILD | fribidi has no platform gate in its meson build, and `default_library=static` avoids any DLL question. |
| clang-native | WILL BUILD | Native; topackage.md:195 records FriBidi 1.0.16 as `[x]` with `pkg-config --modversion fribidi` = 1.0.16 and `elf64-littleaarch64` archive members. |

## API level notes

**21 is the floor and fribidi clears it.** fribidi is pure computation
over a compiled-in Unicode table; it is arguably the most
platform-independent C library in the shard. It is also a dependency of
`packages/harfbuzz`, so its reliability is load-bearing.

## Risks / what a reviewer should check

- **This recipe is the reference example of the meson rules, and that is
  worth preserving.** `-Ddefault_library=static` because meson defaults to
  shared (`generic.lua:12`); no `DESTDIR` on the install because
  `$MESON_FLAGS` already carries `--prefix=$OUT` and adding it would
  produce `$OUT$OUT`. Both are spelled out in the recipe comment
  (`generic.lua:9-11`) with the reason, which is what AGENTS.md asks for.
  **`packages/freetype` is the counter-example in the same shard** — it
  omits `default_library` — and the contrast is the useful part.
- **`-Dbuildtype=release` is passed** (`generic.lua:12`) with no reason
  given in a comment. It is not a target fact, so it is fine to hardcode,
  but it is a build-quality choice that deserves a word: the other meson
  recipe in the shard (`freetype`) does not pass it, so the two produce
  differently-optimised archives. Minor inconsistency.
- **`-Dbin=false` removes `fribidi` and `fribidi/main`**, which are the
  command-line character/shaping tools. Some of harfbuzz's own testing
  wants them, but nothing in this repo does. Correct call.
- **The `ninja -C build install` at `generic.lua:14`** writes straight to
  `$OUT` via meson's `--prefix`. Worth a reviewer's one-time confirmation
  that fribidi's meson honours `--prefix` for its `pkgconfig`
  installation, since that is the single most common meson packaging
  mistake and its symptom is a `.pc` pointing at the wrong prefix.

## How to verify once built

- `lib/libfribidi.a` — **a `.a`, not a `.so`**, which is the direct check
  that `-Ddefault_library=static` took effect
- `include/fribidi/fribidi.h`
- `lib/pkgconfig/fribidi.pc` and `pkg-config --modversion fribidi` → `1.0.16`
- `readelf -h lib/libfribidi.a` → `Machine: AArch64` on Android targets
- `$OUT/bin` absent — confirms `-Dbin=false`
- Grep `lib/pkgconfig/fribidi.pc` for the staging path: it must contain
  `$PREFIX`, not a `mktemp` path
