# swig build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 4.5.1
- Build system: **CMake** (`cmake_minimum_required (VERSION 3.13)`,
  `CMakeLists.txt:1`). This release ships **no generated `configure`** —
  verified by listing, not assumed.
- Installs: `bin/swig` (`CMakeLists.txt:149`) and the interface library
  `Lib/*.swg` under `share/swig/4.5.1` on non-Windows
  (`SWIG_LIB`, `CMakeLists.txt:17-21`, installed at `:120-121`).
- Requires: `pcre2` (exists in this prefix, 10.45) and `swig@source`.

## Is swig native or target? — the classification, and why

**swig is a build-host tool.** It is a code generator: it reads C/C++
headers and emits a `.cxx` wrapper that the *consumer's* build then compiles
and links into the target. Nothing this package installs is consumed by the
target at build time — the two artifacts are the `swig` **executable**
(`CMakeLists.txt:149`) and `Lib/*.swg`, which are pure architecture
independent interface files (`CMakeLists.txt:120`). The generated wrapper is
source code handed to another compiler.

So a consumer in this tree must write `require("swig@native")`, never
`require("swig")`. That is the same reasoning the `meson` stage1 records:
host tools come from `$NATIVE_PREFIX`, and the emitter deliberately prepends
`$NATIVE_PREFIX/bin` to `PATH` for exactly this purpose, while never
prepending the cross toolchain. Note the direction of the dependency: this
recipe does **not** `require()` anything from `swig`, and no other recipe in
the tree should `require("swig")` expecting a host tool.

The recipe is nonetheless written system-neutral and will cross-compile a
working target-side `swig` binary on every system below. That binary is of
niche value, but it is not a defect: nothing in the classification requires
the recipe to be host-only, and keeping it neutral is what lets the builder
produce the `clang-native` copy that actually gets used.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Pure C and C++ executable (`CMakeLists.txt:134-145`), no POSIX dependency the API level gates. The configure-time probes at `:53-67` (`check_include_file`, `check_type_size`, `check_library_exists`) all degrade to a cached 0 rather than failing, and `CMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY` in `$CMAKE_FLAGS` turns them into compile-only tests. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. `SWIG_LIB` becomes `bin/Lib` (`CMakeLists.txt:18`) and both install rules are prefix-relative, so the Windows layout differs deliberately rather than accidentally. |
| clang-native | WILL BUILD | As above, and **this is the system whose copy is actually usable** by other recipes. |

**API level notes.** None of the named walls apply. swig does not call
`posix_spawn`, `process_vm_readv`, `POSIX_MADV_*`, `mblen`, `getpass`,
`O_BINARY`, or `nl_langinfo`, and does not use `mktime_z`.
`armv7a-android*` and `i686-android*` match `aarch64-android*`.

## Build-time runtime requirements — what it actually needs

- **PCRE2 is mandatory, not optional.** `option(WITH_PCRE "Enable PCRE" ON)`
  at `CMakeLists.txt:73`, immediately followed by
  `find_package (PCRE2 REQUIRED COMPONENTS 8BIT)` at `:76`. That is why this
  recipe `require()`s `pcre2`. The comment at `:75` notes swig only uses the
  PCRE2 API available since 10.00, comfortably below the 10.45 this prefix
  pins. Passing `-DWITH_PCRE=ON` explicitly (the default) documents that the
  feature is wanted rather than tolerated.
- **bison ≥ 3.5 is a HOST tool**, `find_package (BISON 3.5 REQUIRED)` at
  `CMakeLists.txt:87`, feeding `BISON_TARGET (swig_parser ...)` at `:108-111`
  which generates `Source/CParse/parser.c` on the build machine for later
  compilation into the target. Correct on cross, and it works here because our
  cross systems keep `PATH` on the host toolchain — the host has bison 3.8.2.
- **python3 is NOT needed.** Nothing in `CMakeLists.txt` looks for Python; the
  version is parsed straight out of `configure.ac` with
  `file (STRINGS configure.ac line ...)` at `CMakeLists.txt:7-13`.

**Risks / what a reviewer should check.**

1. **The autotools path is not usable from this tarball, and the reason is
   specific.** `configure.ac:10` declares
   `AC_CONFIG_HEADERS([Source/Include/swigconfig.h.in])`, but that template
   **does not ship** — a whole-tree search for `swigconfig*` returns only
   `Tools/cmake/swigconfig.h.in` and `CCache/ccache_swig_config.h.in`. The
   cmake build is the only one whose template is present: it generates the
   header from `Tools/cmake/swigconfig.h.in` at `CMakeLists.txt:84-85`. So
   there is **no config-header template to guard and no autotools timestamp
   guard to write here.** A reviewer expecting
   `touch aclocal.m4 configure Source/Include/swigconfig.h.in` should find
   that this package ships no `configure` at all.
2. **`Top-level layout is flat.** The tarball root holds both files and
   directories (`CMakeLists.txt`, `configure.ac`, `INSTALL`, `README`,
   `autogen.sh`, … alongside `Source/`, `Lib/`, `Tools/`, `Examples/`, …),
   so `--strip-components=1` is what flattens it. `cp -r src/*` does not copy
   dotfiles; no dotfile is needed for the build, and this matches the
   convention used by `meson` and `lua`.
3. **The registered ctest tests DO execute the swig binary**
   (`CMakeLists.txt:159-164`, `add_test (NAME cmd_version COMMAND swig
   -version)` and three more). We never run `ctest`, so this is inert — but it
   is the one place in this build where a target binary would be executed, and
   it is worth knowing it is test-only. No `-DBUILD_TESTING` style flag is
   needed; these are unconditional `add_test` calls and are simply not run.
4. **`check_include_file_cxx ("boost/shared_ptr.hpp" HAVE_BOOST)` at
   `CMakeLists.txt:65`** is a bare capability probe with no
   `find_package(Boost)`, so it never requires Boost and never fails when it is
   absent. Boost is not in this prefix and nothing breaks.
5. **Source URL was not verifiable from the build environment.** SourceForge
   was unreachable (HTTP 522 and connection timeouts on every SWIG URL tried),
   and the GitHub release for 4.5.1 publishes only the auto-generated source
   archive, not a `swig-4.5.1.tar.gz` release asset. The recipe lists the
   canonical SourceForge path first and falls back, on the same line, to the
   Debian pool orig tarball, which is the upstream tarball verbatim and is the
   one that was actually downloaded and read for this forecast.
6. `topackage.md:352` lists SWIG unchecked. Note the backlog capitalises it
   "SWIG" while upstream, the tarball, `AC_INIT`, and the installed binary are
   all lowercase `swig`. The directory is named **`swig`** to match the
   lowercase spelling upstream uses everywhere.

**How to verify once built.**

- `bin/swig` exists and `[ -x bin/swig ]` is true.
- `bin/swig -version` must **not** be run on a cross system. Read the version
  from the binary (`strings`) and confirm `4.5.1`.
- `share/swig/4.5.1/swig.swg` exists — this is the load-bearing artifact for a
  consumer and proves the `SWIG_LIB` install at `CMakeLists.txt:120` landed.
  **Scope the check to that path**; `ls share/swig` alone is fine here
  because this package owns the whole directory, but do not count `share/man`
  or `share/doc`, which every package in the prefix shares.
- On `x86_64-mingw` the interface files land in `bin/Lib` instead of
  `share/swig/<version>` (`CMakeLists.txt:18`). That difference is expected;
  check `bin/Lib/swig.swg` there.
- `$OBJDUMP -f bin/swig` prints the expected machine.
- `$READELF -d bin/swig | grep NEEDED` should list the PCRE2 library alongside
  libc — that is the check that `-DWITH_PCRE=ON` really took effect rather than
  silently degrading.