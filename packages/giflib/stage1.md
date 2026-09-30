# giflib build forecast

- Recipe: `generic.lua`, source `source.lua` (SourceForge "download" redirect)
- Version pinned: 5.2.2
- Build system: **plain make** — upstream ships a hand-written `Makefile`, no configure
- Installs: `lib/libgif.a` (static); `include/gif_lib.h`; **no pkg-config file**; no tools
- Requires: `zlib` (exists, 1.3.1), `giflib@source`

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `gif_lib.c` is portable C using only `<stdio.h>`, `<stdlib.h>`, `<string.h>`, `<ctype.h>` and `<errno.h>`, plus `EGifFileName`/`EGifOpenFileName` which wrap `fopen`. The recipe hands make the toolchain directly (`generic.lua:9`: `CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" PREFIX="$OUT"`) because there is no configure to read them — the correct shape for a plain Makefile, and the recipe comment says exactly that. Nothing needs an API above 21. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | Endian-neutral; GIF's LZW decoder is byte-oriented. |
| x86_64-mingw | WILL BUILD (moderate confidence) | giflib's Makefile has no `mingw*` branch. `fopen` in text mode would corrupt binary GIFs on Windows, but that is a runtime correctness wart, not a build failure. Moderate because I did not check whether the Makefile's `install-include` target assumes `/usr/include` layout. |
| clang-native | WILL BUILD | Native; topackage.md:143 records giflib 5.2.2 as `[x]` with `elf64-littleaarch64` archive members and no `.pc`. |

## API level notes

**21 is the floor and giflib clears it with nothing to say.** No Bionic
gap, no API guard, no platform file. This is one of the two packages in
the shard (with `giflib`'s neighbour `bzip2`) where the platform genuinely
does not enter.

## Risks / what a reviewer should check

- **`make install-lib install-include` at `generic.lua:10` is a narrow,
  deliberate install** and the recipe comment explains it: `IGRAPHICS` and
  the man pages stay off by default and only the archive and the header
  are wanted. The man pages are dropped as a side effect. Correct, and the
  comment is clear about it.
- **No pkg-config file**, so a consumer links `-lgif` and includes
  `gif_lib.h` directly. Recorded in topackage.md:143. Fine for a
  five-symbol library, but a `giflib.pc` would be friendlier; not a
  forecast item, just a note.
- **`zlib` is required but `giflib` does not use it.** `generic.lua:1`
  requires zlib and the recipe never references it. The real user is
  `packages/libpng`, which takes both. **If the require line is
  load-bearing for queue ordering (zlib must be in the prefix before
  libpng), then it should say so in a comment** — as written it reads like
  a dependency that does not exist, which is the kind of thing a reviewer
  "cleans up" and thereby breaks the build graph. This is worth a
  reviewer's attention.
- **The SourceForge "download" URL** (`source.lua:5`) is a redirect
  endpoint, not a stable path. It works, but it is more fragile than the
  release-asset URLs elsewhere in this shard, and a SourceForge URL change
  would break the fetch silently differently from a 404. Worth noting.
- **No timestamp guard**, correctly — there is no `configure`.

## How to verify once built

- `lib/libgif.a`
- `include/gif_lib.h`
- `readelf -h lib/libgif.a` → `Machine: AArch64` on Android targets
- `llvm-nm lib/libgif.a | grep EGifOpenFileName` → defined
- No `bin/`, no man pages, no `.pc` — `ls $OUT` should show only `lib/`
  and `include/`
