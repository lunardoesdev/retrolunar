# SpeexDSP build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.2.1
- Build system: autotools. **The source choice is the whole story — see
  below.**
- Installs: static `libspeexdsp.a`, the `speex/` headers, and `speexdsp.pc`.
  No tools, no test programs.
- Requires: `SpeexDSP@source` only. **No real dependencies at all** — SpeexDSP
  is standalone C and does not need libspeex.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Nothing host-side is built, but only because `--disable-examples` is passed. `libspeexdsp/Makefile.am:33-34` builds five programs — testdenoise, testecho, testjitter, testresample, testresample2 — under `if BUILD_EXAMPLES`, and `configure.ac:175-180` makes that condition TRUE by default. (An earlier version of this forecast credited `regressions/` being absent from `SUBDIRS`; that was wrong — `Makefile.am:14` and `:16` are byte-identical and `regressions/` is not in the tarball at all.) The library itself is portable C with no platform backends. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. `win32/` is listed in `SUBDIRS` but contains only VS project files and a `Makefile.am`; the autotools `win32/Makefile.am` has no programs. |
| clang-native | WILL BUILD | As above. |

**The source is not the GitHub tag archive, and that is load-bearing.** I
checked: `github.com/xiph/speexdsp/archive/refs/tags/SpeexDSP-1.2.1.tar.gz`
returns 200 but ships **no generated `configure`** — only `configure.ac`,
`Makefile.am` and `autogen.sh`, which runs `autoreconf -if`. That would mean
running autoconf/automake as host tools inside a cross build. Xiph no longer
hosts a standalone SpeexDSP dist tarball either: every
`downloads.xiph.org/releases/speexdsp/speexdsp-1.2.*.tar.gz` is a 404, and
`releases/tags/SpeexDSP-1.2.1` has no GitHub release assets.

Debian's pool carries `speexdsp_1.2.1.orig.tar.gz`, the **unmodified**
upstream tarball, and it ships all three of the generated files. That is the
same situation and the same remedy `packages/intltool` uses for exactly this
reason, and it is recorded in `source.lua`.

**API level notes.** None. The codec is portable C.

**Risks / what a reviewer should check.**

1. **The timestamp guard names `config.h.in` because
   `configure.ac:338` is `AC_CONFIG_HEADERS([config.h])`** — checked in the
   unpacked tree, not assumed. This is the exact trap AGENTS.md:273-292 warns
   about, and the naming is right.
2. **The five example programs are `noinst_PROGRAMS`**, so they are not
   installed — but they are still compiled and linked on every system without
   the flag, which is the part that cannot work here.
3. **`ti/` is in `SUBDIRS`** (`Makefile.am:14`) and is TI DSP C. It is not
   `configure`d on a POSIX build, so it contributes nothing, but it is worth an
   eye on the build log rather than assumed.
4. **The `doc/` subdir is in `SUBDIRS` too.** SpeexDSP's docs are prebuilt
   HTML in the tarball, and this is a fork of the older docs arrangement. If
   anything tries to regenerate them with a host tool that is absent, that
   would be a host-program problem — **worth watching in the log on the first
   build.**
5. **A Debian-sourced tarball is a standing assumption to re-check on
   update.** If upstream ever re-hosts a dist tarball, prefer it; and
   `speexdsp_1.2.1.orig.tar.gz` is the *orig* (unmodified) tarball, so it is
   not Debian-patched — unlike `soundtouch_2.4.1+ds.orig.tar.xz`, which is a
   `+ds` repack and would not be acceptable.

**How to verify once built.**

- `lib/libspeexdsp.a` exists; `include/speex/speexdsp.h` exists.
- `pkg-config --modversion speexdsp` reports 1.2.1.
- `llvm-objdump -f lib/libspeexdsp.a | head -3` prints
  `elf64-littleaarch64` on Android.
- `llvm-nm --defined-only lib/libspeexdsp.a | grep -cw speex_encode` non-zero.
- **The build log must not contain `testdenoise`, `testecho`, `testjitter`,
  `testresample` or `testresample2`** — that is the check that
  `--disable-examples` took. The correct programs to look for are those five,
  not anything named `regressions/`.
- Check the build log for any attempt to run a host tool under `doc/`.
- The freshness stamp should appear: rerunning prints `skip SpeexDSP (fresh)`.
