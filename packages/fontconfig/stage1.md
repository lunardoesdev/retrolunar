# fontconfig build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 2.18.3
- Build system: **meson** (`meson.build:1-5`, `meson_version: '>= 1.6.0'`; the
  release also ships a generated `configure` — `configure.ac:42` is
  `AC_CONFIG_HEADERS(config.h)` and `config.h.in` is present — but meson is the
  right choice here and is what the recipe uses)
- Requires: `freetype` (exists), `expat` (exists), `gperf@native` (exists),
  `python@native` (exists), `fontconfig@source`
- Installs: `lib/libfontconfig.a`, `include/fontconfig/*.h`,
  `lib/pkgconfig/fontconfig.pc`, plus config data
  (`meson.build:550-585`, `620-637`)

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Both libraries resolve from this prefix: `freetype2 >= 21.0.15` (`meson.build:24`, freetype here is 2.13.3 = 25.13.3) and `expat` (`meson.build:78`). The two host tools are `@native`, so `gperf` and `python3` are the native prefix's, never the target's. `meson.build:376-382` gives Android a `localstatedir/cache/fontconfig` cache dir — plain data, no API gate. Nothing in `src/` needs an API above 21; the two Windows-isms are properly guarded rather than assumed: `O_BINARY` is `#define`d to 0 when absent at `src/fccache.c:55-56`, `src/fccompat.c:59-62` and `fc-cache/fc-cache.c:66-67`, and `iconv_open` at `src/fcfreetype.c:815` sits behind `#if USE_ICONV`, which `-Dnls=disabled` + the `iconv` default (`meson.options:19`) leave off. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above; endian-neutral. |
| x86_64-mingw | UNCERTAIN | The library and both `pkg-config` dependencies resolve the same way, and `meson.build:644-647` correctly skips the cache-dir `install_emptydir` on Windows. What I could **not** verify is the mingw port proper: `meson.build:185-189` sets `EXEEXT` and `meson.build:377-378` selects `LOCAL_APPDATA_FONTCONFIG_CACHE`, but with `-Dtools=disabled` none of the `.exe` consumers are built, and I did not read `src/fcunix.c` against a mingw sysroot. UNCERTAIN rather than WILL BUILD because that file has no `#ifdef _WIN32` in the sections I read. |
| clang-native | WILL BUILD | Not a cross build, so two switches that are inert elsewhere become load-bearing and both are present: `-Dcache-build=disabled` stops `fc-cache/meson.build:12-15` from registering an install script that *runs* the freshly built `fc-cache`, and `-Dtests-external-fonts=disabled` overrides a default of **enabled** (`meson.options:13-14`) whose `fetch-testfonts.py` target (`test/meson.build:1-14`) downloads fonts over the network. |

## API level notes

**21 is the floor.** The only statvfs-family call is `fstatvfs` at
`src/fcstat.c:356`, and every one of those headers is behind an `#ifdef
HAVE_SYS_*` that meson computes (`src/fcstat.c:33-45`, `meson.build:106-106`
check_headers), so a missing header is a silent feature loss, not a build
break. No `nl_langinfo`, no `iconv`, no `posix_spawn`, no `mktime_z`.

## Risks / what a reviewer should check

1. **The version choice is load-bearing and non-obvious.** Pango 1.58.2
   requires `fontconfig >= 2.17.0` (`pango/meson.build:219`), but
   freedesktop.org's release directory **stops at 2.16.0** — 2.17.x and 2.18.x
   exist only as GitLab generic packages. Pinning the "obvious" 2.16.0 would
   have built fine here and then made pango unbuildable. The recipe's URL
   comment records this; a reviewer should confirm the tarball is the real dist
   tarball (it ships `configure`, `Makefile.in`, `config.h.in`) and **not** a
   git archive, which would lack the generated autotools files.
2. **`-Dxml-backend=expat` is a correctness switch, not a preference.** On
   `auto`, `meson.build:88-91` *requires* `libxml-2.0` when expat is not found.
   That is a hard configure error, and libxml2 is present on this build host —
   so an unpinned recipe could bind a host library into a target prefix.
3. **Both `@native` requires are mandatory, not conveniences.**
   `meson.build:461` uses `required: false`, but the fallback at
   `meson.build:485` is a bare `find_program('gperf')` — a missing gperf is a
   hard error, not a degraded build. `meson.build:103`'s
   `import('python').find_installation()` is likewise unconditional, and
   `meson.build:517-532` runs `src/makealias.py` to generate `fcalias.h` and
   `fcftalias.h`. Precedent for the `@native` shape is `packages/bison`
   (`gperf@native`) and `packages/glad` (`python@native`).
4. **json-c is probed but unused here.** `meson.build:71` looks for `json-c`,
   and its only consumer is `test/meson.build:129-136` — behind
   `-Dtests=disabled`. This prefix does have a `json-c`, so it would be found
   and linked into nothing.

## How to verify once built

- `lib/libfontconfig.a` — a `.a`, confirming `-Ddefault_library=static`
- `include/fontconfig/fontconfig.h` and `fcfreetype.h`
- `lib/pkgconfig/fontconfig.pc`; `pkg-config --modversion fontconfig` → `2.18.3`
- `grep -c '^fontconfig.pc' ...` scoping — this .pc is fontconfig's alone
- The meson summary block (`meson.build:652-662`) must show
  `XML backend: expat`, `NLS: false`, `Tools: false`, `Tests: false`
- `$OUT/bin` must not exist — `fc-cache` there means `-Dtools=disabled`
  regressed. Scope the check to fontconfig's own outputs, not the prefix.
- `grep -r 'cpu-features' $OUT` → no hits: this package needs no AOSP header,
  unlike pixman.