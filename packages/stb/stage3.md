# stb 20260802 — stage 3 build record

System built for: **`aarch64-android24`**.

Pinned upstream commit: `2c980bb59875b0d32144a71867fbdebb2f77cd20`
(version field is the upstream snapshot date; stb publishes no tags and no
release assets, per the recipe's own comment).

## Command sequence

```sh
cd /home/si/ond/git/retrolunar
export ANDROID_HOME=/home/si/.local/share/mise/installs/android-sdk/23.0
rm -f nest/aarch64-android24/.retrolunar-stb
./builddir/retrolunar install --nest ./nest --packages ./packages \
    'stb@aarch64-android24' > /tmp/build-stb.sh
sh -n /tmp/build-stb.sh          # exit 0 — syntax gate passed
sh /tmp/build-stb.sh
```

## Stale-artifact cleanup

stb had **no** stale artifacts and no stamp:

```
$ ls nest/aarch64-android24/include/stb*.h nest/aarch64-android24/include/stb_vorbis.c 2>/dev/null
(no output)
$ ls -a nest/aarch64-android24/.retrolunar-stb
ls: cannot access '.../.retrolunar-stb': No such file or directory
```

`include/LICENSE` was deliberately **not** blanket-deleted, since `include/`
is shared with every other package in the prefix; it was checked
individually instead and did not exist beforehand
(`no pre-existing include/LICENSE`). The stamp delete and the
`rm -f include/stb*.h include/stb_vorbis.c` were run unconditionally anyway.
Post-delete check: `no stb* left in include/`.

This package was **fetched fresh during this run** — the log contains the full
`curl` transfer of the 1.44M tarball, so `nest/source/stb/` is the tree this
recipe names:

```
100  1.44M 100  1.44M    473.5k  00:03
```

## Outcome: **SUCCESS**

stb ships no build system at all — no `configure`, no `CMakeLists.txt`, no
`Makefile` — and each library is one self-contained header a consumer
instantiates with a `#define`. **There is nothing to compile and therefore no
architecture to check.** The build body is `mkdir -p` plus one `cp`, and it
did 22 file copies (20 headers + `stb_vorbis.c` + `LICENSE`). That is the whole
of the real work, and the preflight ranked this package "nothing to fail".

## Artifact verification (real output)

The one command that proves it — the header count:

```
$ ls nest/aarch64-android24/include/stb*.h | wc -l
20
```

Spot checks, including the three `stage2.md` named:

```
  OK stb_image.h
  OK stb_truetype.h
  OK stb_image_write.h
  OK stb_image_resize2.h
  OK stb_include.h
  OK stb_hexwave.h
```

The rest, each with its proof command:

| expectation | command | real output |
| --- | --- | --- |
| the `.c` companion | `ls -la $PREFIX/include/stb_vorbis.c` | `-rw-r--r-- 1 si si 192790 Oct  1 03:18 nest/aarch64-android24/include/stb_vorbis.c` |
| the licence | `ls -la $PREFIX/include/LICENSE` | `-rw-r--r-- 1 si si 2510 Oct  1 03:18 nest/aarch64-android24/include/LICENSE` |
| **no library file** | `ls $PREFIX/lib/libstb.a` | absent |
| **no `bin/`** | `ls $PREFIX/bin/stb` | absent |
| **no pkg-config file** | `ls $PREFIX/lib/pkgconfig/stb.pc` | absent |
| **no CMake package config** | — | upstream ships none; nothing from this build in `lib/cmake/` |

All 22 files are mtime `Oct 1 03:18`, from this build.

### One correction to the forecast

`stage2.md` predicted **19** `stb*.h` headers and `[ "$(ls include/stb*.h |
wc -l)" -eq 19 ]` as the proof. The real count at the pinned commit is **20**:

```
$ ls nest/source/stb/stb*.h | wc -l
20
```

The installed set matches upstream exactly — 20 in, 20 out, no missing file
and no strays. Upstream's `stb*` glob at this commit is:

```
stb_c_lexer.h  stb_connected_components.h  stb_divide.h  stb_ds.h
stb_dxt.h  stb_easy_font.h  stb_herringbone_wang_tile.h  stb_hexwave.h
stb_image.h  stb_image_resize2.h  stb_image_write.h  stb_include.h
stb_leakcheck.h  stb_perlin.h  stb_rect_pack.h  stb_sprintf.h
stb_textedit.h  stb_tilemap_editor.h  stb_truetype.h  stb_voxel_render.h
```

`stage2.md`'s check would have reported a **false failure** on a correct
build. Recorded as a forecast off-by-one, not a recipe or build defect.
`stb_image_resize_test` is a directory upstream and is correctly not copied —
the recipe names the files explicitly, so nothing unexpected lands.

The `[ "$(ls include/ | wc -l)" -eq 21 ]` check from `stage2.md` is likewise
unusable in a shared prefix: `include/` holds 200+ headers belonging to every
other package in `nest/aarch64-android24` (`absl`, `ares*.h`, `archive.h`,
`bzlib.h`, …). It can only be run against a clean prefix. The equivalent
narrow check that *is* valid here — "no strays from this build" — was run and
came back with only other packages' entries.

## Rerun proves the new stamp is real

```
$ sh /tmp/build-stb.sh
skip stb@source (fresh)
skip stb@aarch64-android24 (fresh)
```

## System-level findings

None. No recipe change was made; `packages/stb/generic.lua` and `source.lua`
are committed unmodified.
