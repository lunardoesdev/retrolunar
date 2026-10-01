# jasper build forecast

- Recipe: `generic.lua` only, source `source.lua`
- Version pinned: 4.2.9 (`version-4.2.9`, the current `releases/latest`)
- Build system: **cmake**. The tag archive ships **no generated `configure`**
  and no autotools files at all — cmake is the only build system present.
- Installs: `lib/libjasper.a` (static); `include/jasper/*.h`;
  `lib/pkgconfig/jasper.pc` (`build/pkgconfig/jasper.pc.in`, `Name: JasPer`;
  `CMakeLists.txt:880-881` installs it under `CMAKE_INSTALL_LIBDIR`, which is
  `lib` here — an earlier version of this line said `share/pkgconfig` and was
  wrong).
  No programs — `JAS_ENABLE_PROGRAMS=OFF`.
- Requires: `libjpeg-turbo` (exists in this prefix, and it is the JPEG backend
  jasper finds via `find_package(JPEG)`, `CMakeLists.txt:756`).
  `jasper@source` otherwise.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | jasper is C99 with its own image codecs (bmp, jp2, jpc, pgx, pnm, mif, ras under `src/libjasper/`) and needs nothing from libc beyond `<stdio.h>`, `<stdlib.h>`, `<string.h>`, `<math.h>`, `<errno.h>` and `<stdint.h>`. The threading path is the one that needed checking and it is fine: `CMakeLists.txt:636-637` sets `THREADS_PREFER_PTHREAD_FLAG TRUE` before `find_package(Threads)`, and every Android system already exports `-DTHREADS_PREFER_PTHREAD_FLAG=ON` in `$CMAKE_FLAGS` (aarch64-android24/generic.lua:123). That makes cmake use a `-pthread` compile/link flag rather than search for a thread library, which is exactly right for Bionic where there is no `-lpthread` at all. The separate `find_library(PTHREAD_LIBRARY pthread)` at `:594` resolves to NOTFOUND and is neutralised at `:595-597`. |
| aarch64-android24 | WILL BUILD | As above; nothing is API-level gated. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | Same sources, no arch-conditional code. |
| x86_64-mingw | UNCERTAIN | jasper 4.2.x is built on Windows but I did not verify which of its seven native codecs is guarded by `#ifdef _WIN32`. The codec set is large enough that some may be POSIX-only (`mkdir`, `unlink` in `src/libjasper/jas_image.c` for the BMP writer is the usual suspect). Flagged, not claimed. |
| clang-native | WILL BUILD | Native glibc; the obvious consumer for a JPEG-2000 codec and the system the Linux candidates list implies. |

## API level notes

**21 is the floor.** No Bionic-absent symbol appears in jasper's own code:
no `nl_langinfo`, no `getsubopt`, no `scandir`/`versionsort`, no
`program_invocation_short_name`, no `get_current_dir_name`, no
`fread_unlocked`, no `argp_parse`, no `mktime_z`, no `posix_spawn`. The
API-level story that matters here is the **JPEG backend**: the libjpeg-turbo
in this prefix is an ordinary C library with no Android gate, and jasper's
JPEG codec is plain libjpeg API. So no level is a variable.

## Risks / what a reviewer should check

- **Two of the four switches are defensive rather than load-bearing, and the
  comment says so.** `JAS_ENABLE_LIBHEIF=OFF`: `CMakeLists.txt:792-804`
  already sets `JAS_INCLUDE_HEIC_CODEC 0` when libheif is not found, so
  leaving it ON would not fail — it would just print a finding. Passing it
  makes the intent explicit and keeps `find_package` from searching.
  `JAS_ENABLE_LATEX=OFF` is the same idea. The two that genuinely matter
  are `JAS_ENABLE_OPENGL=OFF` (OpenGL and GLUT have nothing to find on
  Android, `CMakeLists.txt:717-718`) and `JAS_ENABLE_PROGRAMS=OFF`.
- **`JAS_ENABLE_SHARED=OFF` needs checking against the option's two
  definitions.** `CMakeLists.txt:103` and `:106` define the same option twice
  (once in a non-shared branch, once defaulting ON), which is legal in cmake
  — first definition wins — but means the default is not where it looks.
  Worth a reviewer's eye that the OFF actually sticks.
- **`JAS_STRICT` defaults OFF** (`:130`), so warnings are not fatal — good,
  because a current clang on jasper's older C will produce some.
- **The seven native codecs are the library's value**, so unlike json-c I
  deliberately did not trim them. Only the *external* backends (HEIF via
  libheif, OpenGL for the viewer) are off.

## How to verify once built

- `lib/libjasper.a` — and `lib/libjasper.so*` must be **absent**.
- `include/jasper/jasper.h`, `include/jasper/jas_config.h`
- `lib/pkgconfig/jasper.pc` and `pkg-config --modversion jasper` → `4.2.9`
  (note the module name is `jasper`, from `Name: JasPer` in jasper.pc.in)
- `readelf -h lib/libjasper.a` → `Machine: AArch64` on Android targets
- `$OUT/bin` must be **absent** — `jasper`, `imagetopnm`, `jiv` and friends
  are what `JAS_ENABLE_PROGRAMS=OFF` keeps out
- `grep JAS_HAVE_LIBHEIF $OUT/include/jasper/jas_config.h` → must be absent
  or undefined, proving the HEIF codec really is out
