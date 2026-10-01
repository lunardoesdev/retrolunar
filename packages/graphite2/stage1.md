# graphite2 build forecast

- Recipe: `generic.lua` only. Source: `source.lua`.
- Version pinned: **1.3.15**.
- Build system: **cmake**, and only cmake — there is **no `meson_options.txt`
  and no `meson.build`** in this release (`ls meson*` returns nothing). Option
  names below were read from `CMakeLists.txt`, not assumed.
- Config template: not applicable (no autotools). It does ship
  `graphite2.pc.in`, configured by `configure_file` at `CMakeLists.txt:98`.
- Installs: `lib/libgraphite2.a`, `include/graphite2/*.h`,
  `lib/pkgconfig/graphite2.pc`, `bin/gr2fonttest`, `share/cmake/gr_2/*.cmake`.
- Requires: `graphite2@source` only. **No FreeType, and no other dependency** —
  see below.

## Two findings that change the briefed assumptions

**1. graphite2 does NOT need freetype.** `grep -rn 'freetype\|FreeType\|FT_'`
across the whole tree returns exactly two hits, both in
`tests/examples/CMakeLists.txt:28` (`find_package(Freetype)`) and `:49`
(`test_freetype(...)`), and `test_freetype` is itself guarded by
`if (${FREETYPE_FOUND})` at `:35`. That directory is reached only through
`tests/`, which `CMakeLists.txt:86-88` adds **only when `BUILD_TESTING`** —
and `BUILD_TESTING` is ON by default (`CMakeLists.txt:13`). So `-DBUILD_TESTING=OFF`,
which the recipe passes for its own reasons (see below), is also what removes
the package's entire FreeType dependency. `packages/freetype` exists and is
deliberately **not** required.

**2. `include(GetPrerequisites)` refers to a file this tarball does not ship.**
`Graphite.cmake:3` is `include(GetPrerequisites)`, and `src/CMakeLists.txt:111`
does `include(Graphite)` inside the Linux branch. `find . -iname '*prereq*'`
returns nothing and `Graphite.cmake` is the only `.cmake` file in the tree —
so the include looks like it should be fatal. It is not: CMake ships its own
`GetPrerequisites.cmake` in `$CMAKE_ROOT/Modules/`, and `include()` falls back
to the builtin module directory even with `CMAKE_MODULE_PATH` set
(`CMakeLists.txt:7`). Probed with cmake 4.4.3: `include(GetPrerequisites)`
completes and configuration succeeds, while `include(TotallyBogusModuleXYZ)`
on the same project fails. **A reviewer will spot this line and should know it
is harmless.** It is recorded here precisely so nobody spends time on it.

## Verdict

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL BUILD** | Pure C++ (no libc dependency beyond the C runtime and the standard library), no `AC_RUN_IFELSE`-style probe, no host program. `CMakeLists.txt:15` enables CXX+C, `:16` pins C++11. `CMAKE_CXX_TRY_COMPILE_TARGET_TYPE` is handled by the systems' `-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY`. The one branch that could misfire is `if (${CMAKE_SYSTEM_NAME} STREQUAL "Linux")` at `src/CMakeLists.txt:87` — our toolchain files deliberately set `CMAKE_SYSTEM_NAME` to `Linux`, so it *does* fire on Android. That is harmless here: it only sets `LINKER_LANGUAGE C` and `LINK_FLAGS "-nodefaultlibs"` (`:88-91`) on a target that is a **static archive** under `-DBUILD_SHARED_LIBS=OFF`, and a static archive has no link step. Its one real side effect, `add_definitions(-mfpmath=sse -msse2)` at `:97`, is gated on `CMAKE_SYSTEM_PROCESSOR MATCHES "x86\|i.86"`, so it does not apply to aarch64. |
| aarch64-android24 | **WILL BUILD** | As above. Nothing in graphite2 is API-gated: no `iconv_open`, no `nl_langinfo`, no `mktime_z`, no `posix_spawn` anywhere in `src/`. |
| aarch64-android35 | **WILL BUILD** | As above. |
| x86_64-android35 | **WILL BUILD** | As above, and here `src/CMakeLists.txt:97` *does* add `-mfpmath=sse -msse2` (the processor string matches `x86`). That is benign on x86_64, where SSE2 is part of the base ISA. |
| x86_64-mingw | **WILL BUILD** | No Android gate applies. `src/CMakeLists.txt:122` matches `.*mingw.*` on `CMAKE_CXX_COMPILER` and links `kernel32 msvcr90 mingw32 gcc user32`; the `:112` Windows branch adds the `_CRT_SECURE_NO_WARNINGS`/`UNICODE` defines. `GRAPHITE2_VM_TYPE` stays `auto`, which resolves to `direct` for a Release build (`CMakeLists.txt:57-58`); `direct` requires GCC or Clang (`CMakeLists.txt:63`) and mingw here is GCC. |
| clang-native | **WILL BUILD** | `CMAKE_SYSTEM_NAME` is `Linux` natively, so `src/CMakeLists.txt:87` fires as upstream intends. `GRAPHITE2_VM_TYPE` resolves to `direct` and `CMakeLists.txt:63` accepts Clang explicitly. |

armv7a and i686 behave exactly like their aarch64/x86_64 counterparts.

## API-level notes

**None.** graphite2 reads and shapes fonts itself and never calls into an
external text or font library, so none of the API-21 walls (`stderr` as a real
symbol, `POSIX_MADV_*`, `process_vm_readv`, `posix_spawn`, `mblen`/`getpass`,
`O_BINARY`) and none of the later gates (`nl_langinfo` at 26, `iconv.h` and
`posix_spawn` at 28, `mktime_z` at 35) appear anywhere in `src/`.

## Risks / what a reviewer should check

1. **`-DBUILD_TESTING=OFF` is doing two jobs**, and both should be understood.
   Primarily it keeps a host toolchain out of a cross build:
   `CMakeLists.txt:69-70` runs `find_package(Python3 3.6 REQUIRED COMPONENTS
   Interpreter)` at *configure* time and `:72-74` then **executes** that host
   interpreter. Secondarily it is what removes FreeType (see finding 1).
   Turning it off skips `add_subdirectory(tests)` entirely
   (`CMakeLists.txt:86-88`).
2. **`-DBUILD_SHARED_LIBS=OFF` matches the tree's static convention** — same
   rationale as the meson recipes' `-Ddefault_library=static`: a target prefix
   has no loader path for a versioned shared object. It also selects
   `-DGRAPHITE2_STATIC` (`src/CMakeLists.txt:32-34`), which the installed
   headers need so consumers get correct dllimport visibility on Windows.
3. **`bin/gr2fonttest` is still installed** (`gr2fonttest/CMakeLists.txt:24`).
   It is a *target* executable that is compiled but **never executed during the
   build**, so it does not violate the no-emulation rule. If a reviewer would
   rather not ship a tool, `-DGRAPHITE2_NFILEFACE=ON` removes it — but that
   also compiles out the `gr_make_file_face*` API, which is a real library
   feature loss, so the recipe does not do it.
4. **`doc/` builds nothing here.** `doc/CMakeLists.txt:6-9` uses `find_program`
   for asciidoc/doxygen/latex and only populates `DOC_DEPENDS` if they are
   found; the resulting `docs` target (`:59`) is not in `ALL`, so it is never
   built by `cmake --build`.
5. **`pkg-config --modversion graphite2` reports `3.3.1`, not `1.3.15`.** That
   is upstream's own doing: `src/CMakeLists.txt:9` computes
   `GRAPHITE_VERSION` from the ABI triple, and `CMakeLists.txt:94` feeds it to
   `configure_file` for `graphite2.pc` (whose template uses `${version}`).
   Do not "fix" this — it is what upstream ships, and 1.3.15's own ChangeLog
   records *"Fix incorrectly generated graphite2.pc pkgconf file"* as the change
   that made this correct.
6. **Source URL is a mirror, and that is deliberate.** Upstream's GitHub
   release assets for this project are unreachable — every path under
   `github.com/silnrsi/graphite2` (releases, archive, raw) returns 404 from
   this host, while `github.com/google/googletest` returns 200, so it is the
   project and not the network. The `gitlab.freedesktop.org` mirror requires
   sign-in for archives. The recipe therefore fetches Debian's `.orig.tar.gz`,
   which is upstream's release tarball and was verified byte-complete
   (13,698,237 bytes on disk against a 13,698,237-byte `Content-Length`, and
   `tar -tzf` succeeds). Its top-level directory is `graphite-1.3.15`, hence
   `--strip-components=1`. **If upstream's canonical URL comes back, changing
   the URL is the whole edit.**
7. **The autotools rules do not apply here** — no `touch aclocal.m4` guard,
   no `Makefile.in` sweep. cmake does not re-run autoheader. A reviewer
   expecting that guard here is applying the wrong build system.

## How to verify once built

- `lib/libgraphite2.a` exists; `include/graphite2/Font.h` exists.
- `pkg-config --modversion graphite2` reports **`3.3.1`**, not 1.3.15 — see
  risk 5 before treating that as a failure.
- `grep -c '$OUT' lib/pkgconfig/graphite2.pc` is `0`, proving the loader's
  `$OUT`→`$PREFIX` rewrite ran.
- `$OBJDUMP -f lib/libgraphite2.a` members must be the target machine
  (aarch64 for the Android rows, x86-64 for the others).
- `llvm-nm -u lib/libgraphite2.a | grep -cw freetype` must be **0** — that is
  the direct check that `-DBUILD_TESTING=OFF` really removed the FreeType
  dependency rather than leaving an undefined reference for a consumer to hit.
- The configure log must **not** contain `Could not find a package
  configuration file provided by "Python3"` — that would mean `BUILD_TESTING`
  was not actually off and a host interpreter got pulled into a cross build.
- `ls bin/` shows `gr2fonttest`; its presence is expected, not a defect
  (risk 3).