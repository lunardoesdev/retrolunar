# freetype build forecast

- Recipe: `generic.lua`, source `source.lua` (savannah tarball with a `meson.build`, falling back to the GitHub tag archive)
- Version pinned: 2.13.3
- Build system: **meson**
- Installs: `lib/libfreetype.a` (static); `include/freetype2/`; `lib/pkgconfig/freetype2.pc`; **no `bin/freetype-config`** — that is an autotools-only artifact and meson.build never mentions it
- Requires: `zlib` (exists), `libpng` (exists), `freetype@source`

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | FreeType's own code is C99 with a POSIX base; its `builds/unix` config uses `<unistd.h>`, `<fcntl.h>`, `<sys/mman.h>`, `<sys/stat.h>` and `mmap`, all in Bionic at API 21. `-Dtests=disabled` (`generic.lua:11`) removes `ftdump`/`ftbench` and the test programs, which are the only executables. `-Dbrotli=disabled -Dbzip2=disabled -Dharfbuzz=disabled` (`generic.lua:11`) leave zlib and png as the only backends, both from this prefix. Nothing needs an API above 21. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | FreeType's rasterizer has explicit endian handling per `FT_*_BYTE_*`; no arch assumption. |
| x86_64-mingw | **UNCERTAIN** | `-Dzlib=system` and `-Dpng=enabled` require this prefix's zlib and libpng to be mingw builds. `libpng/generic.lua` does build for mingw (topackage.md does not record it as blocked), so the pairing is plausible. What I could not settle: FreeType's meson build for a PE target selects `builds/windows` semantics in some versions and the `ftsystem.c` `FT_CONFIG_OPTION_SYSTEM_ZLIB` path may need a mangled name. Flagged, not claimed. |
| clang-native | WILL BUILD | Native. **Note: freetype does not appear as `[x]` in topackage.md at all** — it is not on the LFS list, and the only mention is topackage.md:196, which records *harfbuzz* consuming "the FreeType and FriBidi integrations from this prefix". So freetype is present as a dependency of harfbuzz, not as a tracked item. Its build status is therefore only implied. |

## API level notes

**21 is the floor and FreeType clears it.** FreeType is careful: its
`ftsystem.c` wraps every platform call behind `FT_CONFIG_OPTION_*` macros
and it ships an ANSI-only fallback. Nothing in the built library needs an
API above 21, and `-Dtests=disabled` removes the parts that might.

## Risks / what a reviewer should check

- **This is the one meson recipe in the a–g shard, and it omits
  `-Ddefault_library=static`.** AGENTS.md says meson recipes must pass it:
  "meson builds shared by default, and a target prefix has no loader path
  for a versioned object". `packages/fribidi/generic.lua:11` does pass it,
  and its comment explains why. **freetype's recipe does not.** So this
  build will produce a *shared* `libfreetype.so` (meson's FreeType
  `meson.build` defaults `default_library` to `shared`), which is
  inconsistent with every other package in the prefix and needs an rpath or
  `LD_LIBRARY_PATH` at consumer link time. **This is the most substantive
  finding in this file and it is a real recipe defect, not a forecast
  caveat.** I am not changing the recipe, per scope.
- **The ninja install line has no `install` guard and no `DESTDIR`**
  (`generic.lua:13`), which is correct per AGENTS.md — `$MESON_FLAGS`
  already carries `--prefix=$OUT`, and adding `DESTDIR` would produce
  `$OUT$OUT`. Worth a reviewer's confirmation that freetype's meson
  honours that, since it is the second-most-likely place for the prefix to
  go wrong.
- **The source URL has a fallback** (`source.lua:5`):
  `savannah.gnu.org || github.com tag archive`. The GitHub fallback ships
  no generated `meson.build`? It does — freetype's repo has
  `meson.build` at the top level — so the fallback is viable. Good
  practice.
- **`-Dharfbuzz=disabled` and `-Dbrotli=disabled`/`-Dbzip2=disabled`** are
  deliberate feature reductions. `packages/harfbuzz` (adder C's shard)
  enables FreeType's HarfBuzz integration itself, so this recipe's
  `libfreetype.a` will not contain `ft_hb` symbols. **A consumer wanting
  HarfBuzz shaping through FreeType must link harfbuzz directly** — worth
  stating in the readme, because the two are easy to confuse.
- **`libpng` is a real dependency and it works**: `libpng/generic.lua`
  exists and topackage.md does not mark it blocked. The `-Dpng=enabled`
  pairing is what makes FreeType able to read PNG-suffixed embedded
  bitmaps.

## How to verify once built

- `lib/libfreetype.a`, and `lib/libfreetype.so*` **must be absent** — that
  is the direct check that `-Ddefault_library=static` took
- `include/freetype2/ft2build.h`, `include/freetype2/freetype/freetype.h`
- `lib/pkgconfig/freetype2.pc` and `pkg-config --modversion freetype2` → `2.13.3`
- `readelf -h lib/libfreetype.*` → `Machine: AArch64` on Android targets
- `bin/freetype-config` **must be absent** (autotools-only), as must `bin/ftdump` and `bin/ftbench`
