ACCEPT

# stb (commit 2c980bb, 2026-08-02) — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the extracted
commit archive. I did not build anything.

## What the recipe does right

- `source.lua` is the correct pattern for a project with no releases.
  `nothings/stb` publishes **no tags and no release assets** — I re-queried
  `repos/nothings/stb/tags` and got an empty array, matching `stage1.md`. The
  recipe therefore pins the exact commit sha in the URL
  (`2c980bb59875b0d32144a71867fbdebb2f77cd20`, dated 2026-08-02) and uses its
  date as the `version` string, with a comment saying so. That is honest
  labelling, not a fake version.
  URL 200, 1 516 086 B, top dir `stb-2c980bb59875b0d32144a71867fbdebb2f77cd20/`,
  handled by `--strip-components=1`. Guarded download, `curl -C -` resume,
  `rm -rf src`, `mkdir -p $OUT/stb`.
- `generic.lua` requires only `stb@source`. Nothing missing, no `@native` need.
- **Nothing in the recipe is a target fact.** I checked the whole file: no
  `$CC`, no `$CXX`, no `$CFLAGS`, no `$CMAKE_FLAGS`, no `-I`, no `-L`, no
  architecture, no triplet, no API level, no `export`. The build body is
  `mkdir -p $OUT/include` and one `cp`. That is the correct answer for a
  header-only library with no build system, and the recipe comment says so.
- No `sed`, no patch, no `/dev/null`, no multi-job build, no configure.
- I verified the copy list against the extracted tree, because a `cp` of a
  non-existent file is the one way this recipe can fail:
  `stb*.h` matches 19 headers (`stb_c_lexer.h`, `stb_connected_components.h`,
  `stb_divide.h`, `stb_ds.h`, `stb_dxt.h`, `stb_easy_font.h`,
  `stb_herringbone_wang_tile.h`, `stb_hexwave.h`, `stb_image.h`,
  `stb_image_resize2.h`, `stb_image_write.h`, `stb_include.h`,
  `stb_leakcheck.h`, `stb_perlin.h`, `stb_rect_pack.h`, `stb_sprintf.h`,
  `stb_textedit.h`, `stb_tilemap_editor.h`, `stb_truetype.h`,
  `stb_voxel_render.h`); `stb_vorbis.c` is present (192 790 B); `LICENSE` is
  present (2 510 B). All three sources exist, so `cp` will not fail.
- `stage1.md` is honest and, notably, corrects the brief's own framing rather
  than papering over it. It also flags the one thing a reader would otherwise
  get wrong: upstream's README lists 21 libraries under the old
  `stb_image_resize` name, while the tree now carries `stb_image_resize2.h` —
  so a reviewer checking the install list against the README will be misled.
  Correct, and useful.

## Non-blocking observations

1. `stb*.h` also copies `stb_leakcheck.h` (a `main()` demo),
   `stb_include.h` (an include-order workaround) and `stb_ds.h` (a container
   library with a different idiom). Installing all of them is the deliberate
   choice `stage1.md` item 1 argues for, and it is the right one: a curated
   subset means a recipe edit the first time somebody wants `stb_dxt.h`. No
   change wanted.
2. `stb_vorbis.c` lands in `include/` with a `.c` extension. Intentional, and
   correct in practice — the file is a header body. `stage1.md` item 2 already
   says a one-line change would drop it. Leave it.
3. `stb_image_resize_test/`, `tools/`, `tests/`, `docs/` and `data/` in the
   source tree are host material and are correctly *not* installed.

## Carried to the build

Expected under `$NESTDIR/<sys>/`, byte-identical on every system:

| Artifact | The one check that proves it |
| --- | --- |
| `include/stb_image.h` | `[ -f include/stb_image.h ]` |
| `include/stb_truetype.h`, `include/stb_image_write.h`, `include/stb_image_resize2.h` | `[ -f include/stb_truetype.h ] && [ -f include/stb_image_write.h ] && [ -f include/stb_image_resize2.h ]` — the third name is the one the stale upstream README gets wrong |
| the other 17 `stb*.h` headers | `[ "$(ls include/stb*.h \| wc -l)" -eq 20 ]` — 20, not 19: upstream ships 20 `stb*.h` at commit 2c980bb, and `stage1.md` already says so. `-eq 19` fails against a correct build |
| `include/stb_vorbis.c` | `[ -f include/stb_vorbis.c ]` |
| `include/LICENSE` | `[ -f include/LICENSE ]` |
| header count / no strays | `[ "$(ls include/ \| wc -l)" -eq 22 ]` — 20 headers + `stb_vorbis.c` + `LICENSE`, nothing else. Only meaningful on a clean prefix: in a shared one `include/` also holds every other package's headers |

**There is no library file, no `bin/`, no pkg-config file and no CMake package
config — all four are correct.** stb is consumed by `#define
STB_IMAGE_IMPLEMENTATION` in one translation unit; a missing `libstb.a` and a
missing `pkg-config --modversion stb` are the expected result.

**There is no architecture check to run**, and the builder should record that
rather than treat its absence as a gap: nothing is compiled, so
`llvm-objdump -f` has nothing to point at. If someone later wants an ABI or
codegen check, the honest place is a consumer recipe, not this one.

Rerun should print `skip ... (fresh)`.
