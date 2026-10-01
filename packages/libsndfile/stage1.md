# libsndfile build forecast

- **Package:** libsndfile
- **Version:** 1.2.2 (release 2023-08-13, newest on libsndfile/libsndfile)
- **Upstream URL:** `https://github.com/libsndfile/libsndfile/releases/download/1.2.2/libsndfile-1.2.2.tar.xz`
  (HTTP 200, 730 760 bytes, top directory `libsndfile-1.2.2/`)
  Note the `.tar.xz`, hence `tar -xJf` in the recipe.
- **Build system: autotools**, with a **generated `configure` present**
  (`libsndfile-1.2.2/configure`, `aclocal.m4`, `Makefile.in`)
- **Config template: `src/config.h.in`** — *not* a top-level `config.h.in`.
  `configure.ac:31` reads `AC_CONFIG_HEADERS([src/config.h])`, and `tar tJf`
  confirms `libsndfile-1.2.2/src/config.h.in`. The recipe names that path.
- **Dependencies required:** `libogg`, `libvorbis`, `flac`, `opus` — **all four
  exist** in `packages/`.
- **Installs:** `lib/libsndfile.a`, `include/sndfile.h` **and
  `include/sndfile.hh`** (`Makefile.am:65` installs both), and
  `lib/pkgconfig/sndfile.pc`. **No `bin/` entry**, because the recipe passes
  `--disable-full-suite` and the ten `bin_PROGRAMS` are gone — see risk 1.
  **No man pages**, for the same reason (`dist_man_MANS` is inside
  `if FULL_SUITE`).

### Which external codecs it actually finds, and why that is all-or-nothing

This is the part the assignment asked me to pin down, so here is the whole
chain from `configure.ac`. libsndfile probes **five** things, not four:

| pkg-config module | version floor | needed by |
| --- | --- | --- |
| `flac` | `>= 1.3.1` (`configure.ac:297`) | FLAC |
| `ogg` | `>= 1.3.0` (`configure.ac:302`) | container |
| `vorbis` | `>= 1.2.3` (`configure.ac:314`) | Vorbis decode |
| `vorbisenc` | `>= 1.2.3` (`configure.ac:315`) | Vorbis **encode** |
| `opus` | `>= 1.1` (`configure.ac:317`) | Opus |

`configure.ac:321` sets `HAVE_EXTERNAL_XIPH_LIBS=1` **only if the
concatenation of all five answers is `yesyesyesyesyes`**; otherwise
`configure.ac:343` sets `enable_external_libs=no` and prints a warning naming
libflac, libogg, libvorbis and libopus. Upstream says so itself:
"the external libs are an all or nothing affair."

**All five resolve in this prefix**, which I checked rather than assumed:
- `packages/libogg` installs `ogg.pc` and `vorbis.pc` (`pkgconfig_DATA` in
  libogg's Makefile.am);
- `packages/libvorbis` installs `vorbis.pc`, **`vorbisenc.pc`** and
  `vorbisfile.pc` — `libvorbis-1.3.7/Makefile.am:17` has
  `pkgconfig_DATA = vorbis.pc vorbisenc.pc vorbisfile.pc`, **unconditionally**,
  so the recipe's `--disable-examples` and `--disable-docs` cannot remove it;
- `packages/flac` installs `flac.pc` (version 1.5.0, clears `>= 1.3.1`);
- `packages/opus` installs `opus.pc` (1.5.2, clears `>= 1.1`).

So the recipe turns **nothing** off in the external-libs group: there is no
`--enable-external-libs` to pass, and passing `--disable-external-libs` would
be the one flag that actually changes the library's capabilities. What I do
turn off is the set of things that are *not* in the prefix.

| system | verdict | reason |
| --- | --- | --- |
| `aarch64-android21` | **WILL BUILD** | All five codec probes succeed, so FLAC/Ogg/Vorbis/Opus are compiled in. `configure.ac:153` sets `enable_alsa=auto`; the recipe passes `--disable-alsa` because ALSA is a Linux desktop API and `alsa/asoundlib.h` is not in the NDK. sqlite (`configure.ac:150`) and the Octave module (`configure.ac:162`) are off. libsndfile's own libc surface is `fopen`/`fopen64`/`mmap`/`pread`/`snprintf`/`strtod` — all present at API 21. **No `mktime_z`, no `nl_langinfo`, no `iconv`**: libsndfile does its own character-set conversion through its own `src/charset.c` tables, not libc's iconv, which is why `--disable-alsa`-style flags about iconv do not appear. |
| `aarch64-android24` | **WILL BUILD** | As above. |
| `aarch64-android35` | **WILL BUILD** | As above. |
| `x86_64-android35` | **WILL BUILD** | As above; no arch-specific code. |
| `x86_64-mingw` | **WILL NOT BUILD** | `src/file_io.c:499` reads `if (S_ISFIFO (statbuf.st_mode) \|\| S_ISSOCK (statbuf.st_mode))`, and **`S_ISSOCK` is not defined anywhere in this package**: not in `config.h.in`, and not in `src/sf_unistd.h`, which back-fills `S_ISFIFO` and `S_ISREG` (`sf_unistd.h:98-103`) but **not** `S_ISSOCK`. `grep -rn S_ISSOCK .` over the whole tree returns exactly one hit — the call site itself. It is a glibc/BSD macro; **mingw-w64's `sys/stat.h` does not define it**, and GCC 16 makes an implicit function declaration a hard error, so `x86_64-w64-mingw32-gcc -O2 -c` on a two-line reproduction fails with `error: implicit declaration of function 'S_ISSOCK'`. I confirmed that probe myself against the mingw wrapper (fails) and against the native and aarch64 API-21/API-35 wrappers (all succeed) before accepting this row. The library cannot be dodged: `Makefile.am:81` puts `src/file_io.c` in `src_libcommon_la_SOURCES` **unconditionally**, so `libsndfile.a` itself does not compile. Older GCC only warned and the archive would have linked with a PLT call that is never reached, so this regressed with GCC 14+. **This is a system-level blocker, not a recipe defect**: AGENTS.md forbids patching an upstream source, there is no `configure` switch that removes `file_io.c`, and `--disable-full-suite` (which the recipe now passes) does not help because it only gates the ten `bin_PROGRAMS`. The builder should record it in `stage3.md` per AGENTS.md:549 rather than working around it with a `-D` in the recipe. |
| `clang-native` | **WILL BUILD** | Native; ALSA disabled by our flag even though it would be found, which keeps the codec set identical across all six systems rather than varying with the host. |

**API level notes.** **No new wall.** I checked the three API-26/28/35
traps specifically, because libsndfile is a plausible candidate for each:
- **`nl_langinfo` (API 26)** — not called. libsndfile formats its own
  timestamps via `src/GSM.c`'s hand-written ISO-8601 conversion, not libc.
- **`iconv.h` (API 28)** — not used; see the charset.c note above. **Bionic has
  no separate `-liconv`**, and this recipe never asks for one.
- **`mktime_z` (API 35)** — not called; `mktime` only, in the header-writer.
The API level is therefore **inert**: 21, 24 and 35 take an identical path.

**Risks / what a reviewer should check.**
1. **The ten `bin_PROGRAMS` need `--disable-full-suite`, and my first draft of
   this file got that wrong.** `Makefile.am:87` does declare some programs
   `check_PROGRAMS`, but that is not the whole story: `Makefile.am:489-492`
   declares **ten** more as `bin_PROGRAMS` — `sndfile-info`, `sndfile-play`,
   `sndfile-convert`, `sndfile-cmp`, `sndfile-metadata-set`,
   `sndfile-metadata-get`, `sndfile-interleave`, `sndfile-deinterleave`,
   `sndfile-concat`, `sndfile-salvage` — inside `if FULL_SUITE`
   (`Makefile.am:432`). That conditional is
   `AM_CONDITIONAL([FULL_SUITE], [test "x$enable_full_suite" != "xno"])`
   (`configure.ac:167`), so with the flag **absent** the variable is unset,
   `test "x" != "xno"` is **true**, and the ten are built *and installed* by
   plain `make` — despite the `[[default=no]]` in the `--disable-full-suite`
   help text at `configure.ac:166`. This is the same absent-flag-means-on trap
   as `--disable-external-libs`, and I checked the wrong half of it first time.
   The recipe now passes `--disable-full-suite`, which drops the ten binaries
   and the `dist_man_MANS` block from every system.
2. **`--disable-external-libs` is deliberately NOT passed**, and a reviewer
   should confirm they agree. Passing it would be the "safer-looking" flag and
   it would silently drop FLAC, Ogg, Vorbis and Opus from the library. The
   comment in the recipe says why the codecs stay on.
3. **All five probes must succeed or none do.** If a future change removes
   `vorbisenc.pc` from the prefix (e.g. a libvorbis recipe that adds
   `--disable-examples` in a way that also drops `pkgconfig_DATA`), libsndfile
   loses **every** codec with only a configure-time warning. That is the single
   most fragile coupling in this recipe, and the fix would be in libvorbis, not
   here.
4. **`--disable-sqlite` is correct but low-stakes.** sqlite is off by default
   only if not found; naming it makes the intent explicit. There is no sqlite
   package in this prefix.
5. **The config template is in `src/`** — see the risk note in
   `packages/libssh2/stage1.md` about why a wrong guard name is worse than no
   guard. This package has the same shape.

**How to verify once built.**
- `lib/libsndfile.a`, `include/sndfile.h`, `lib/pkgconfig/sndfile.pc`
- `pkg-config --modversion sndfile` → `1.2.2`
- `llvm-objdump -f lib/libsndfile.a | head` → `elf64-littleaarch64` on aarch64
- `llvm-nm -u lib/libsndfile.a | grep -cE 'FLAC_|vorbis_|opus_|ogg_'` → **0**,
  and `grep -m1 'Requires' lib/pkgconfig/sndfile.pc` must list all five codec
  modules. **This is the check for risk 3** — if the `Requires` line is short,
  an all-or-nothing downgrade happened and configure printed a warning.
- `llvm-nm -u lib/libsndfile.a | grep -cE 'nl_langinfo|iconv|mktime_z'` → 0,
  confirming the API-26/28/35 paths are not touched
- `ls lib/libsndfile.so*` → must be absent (`--disable-shared`)