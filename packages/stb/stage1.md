# stb (commit 2c980bb, 2026-08-02) — stage 1 build forecast

**Package:** stb
**Version:** 20260802 (upstream's master commit date; see Source)
**Upstream:** https://github.com/nothings/stb
**Build system:** none. There is no `configure`, no `CMakeLists.txt`, no
`Makefile`, no build system of any kind.

This is a forecast from reading upstream source, not a measurement. Nothing
here has been compiled.

## What it installs

- `include/stb*.h` — all 20 headers: `stb_c_lexer.h`, `stb_connected_components.h`,
  `stb_divide.h`, `stb_ds.h`, `stb_dxt.h`, `stb_easy_font.h`,
  `stb_herringbone_wang_tile.h`, `stb_hexwave.h`, `stb_image.h`,
  `stb_image_resize2.h`, `stb_image_write.h`, `stb_include.h`,
  `stb_leakcheck.h`, `stb_perlin.h`, `stb_rect_pack.h`, `stb_sprintf.h`,
  `stb_textedit.h`, `stb_tilemap_editor.h`, `stb_truetype.h`,
  `stb_voxel_render.h`.
- `include/stb_vorbis.c` — a source-named library, but the file is a header
  body in practice; copying it alongside the headers is what consumers expect.
- `include/LICENSE` — public domain / MIT dual licence, worth shipping.
- **No library file, no pkg-config file, no CMake package config.** Upstream
  ships none of the three. A consumer adds `-I$PREFIX/include`, writes
  `#define STB_IMAGE_IMPLEMENTATION` in exactly one translation unit before
  `#include <stb_image.h>`, and links nothing.

## Dependencies

None. No `require()` of any other package. Each stb library is a single
self-contained header; `stb_image.h` includes only `<stdlib.h>`, `<stdio.h>`
and friends, and `stb_truetype.h` is likewise standalone.

## Source, and why it is a commit pin

stb has **no tags and no releases**. I checked both: the GitHub API returns an
empty array for `repos/nothings/stb/tags` and for `repos/nothings/stb/releases`.
It is a rolling trunk that upstream bumps by hand, so there is no version to
name and no release asset to fetch. The recipe therefore pins the exact commit:

- `https://github.com/nothings/stb/archive/2c980bb59875b0d32144a71867fbdebb2f77cd20.tar.gz`
  — confirmed HTTP 200. Extracted top directory is
  `stb-2c980bb59875b0d32144a71867fbdebb2f77cd20`, stripped by the recipe.
- The commit is `2c980bb59875b0d32144a71867fbdebb2f77cd20`, dated
  `2026-08-02T06:42:09Z`, "Merge pull request #1984 from ruby-R53/patch-1".
  That date is the `version` string, matching the convention other rolling
  packages in this tree already use.

The commit sha is in the URL, so the pin is exact and the `version` field is
only a label.

## Nothing is compiled

There is no build system, so the recipe cannot invoke one. The whole build body
is a `mkdir` and two `cp` invocations. Consequences:

- The installed tree is byte-identical on every system.
- There is no architecture check to make and no way for a target fact to leak
  in. `$CC`, `$CXX`, `$CXXFLAGS`, `$CMAKE_FLAGS` and `$SYSROOT` are all
  untouched, and correctly so.
- Every stb library is compiled *by the consumer*, into the consumer's own
  object files. That means the C++ dialect and the warning flags are the
  consumer's choice, not this prefix's.

## Per-system verdict

| Family | Verdict | Reason |
| --- | --- | --- |
| `aarch64-android21` | WILL BUILD | Two `cp` calls. Nothing reads the sysroot, so Bionic's API-level walls (`stderr` as a symbol, `posix_spawn`, `mblen`/`getpass`, listed in AGENTS.md:368) cannot apply to the install. |
| `aarch64-android24` | WILL BUILD | As above. |
| `aarch64-android35` | WILL BUILD | As above. |
| `x86_64-android35` | WILL BUILD | As above. |
| `x86_64-mingw` | WILL BUILD | As above. |
| `clang-native` | WILL BUILD | As above. |

`armv7a-android*` and `i686-android*` match `aarch64-android*` for every row.
For this package the API level is not even nominally a variable: the recipe has
no step that could observe it.

## What a reviewer should scrutinise

1. **Which headers to install.** The recipe copies `stb*.h` — all 20 —
   rather than a curated subset. That is a deliberate choice: stb's headers are
   self-contained and cost a few megabytes, and picking a subset means the next
   consumer to want `stb_dxt.h` needs a recipe edit. A reviewer who prefers a
   curated set should say so, but the current form is the one that never
   surprises a consumer.
2. **`stb_vorbis.c` is copied as if it were a header.** That is intentional
   and matches how every project uses it, but the `.c` extension in
   `include/` will look odd. It is a one-line recipe change to drop it.
3. **The upstream README is stale.** It lists 21 libraries and describes
   `stb_vorbis.c` as version 1.22, and lists `stb_image_resize` under its old
   name; the tree now carries `stb_image_resize2.h`. Not a recipe problem, but
   a reviewer reading the README to check the install list will be misled.
4. **No version to speak of.** `pkg-config --modversion stb` is impossible and
   the freshness stamp in `$NESTDIR/<sys>/.retrolunar-stb` tracks the recipe
   file, not upstream. A future bump is a new commit sha in the URL and a new
   date in `version`.
