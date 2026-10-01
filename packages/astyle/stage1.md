# astyle build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 3.6.12
- Build system: **CMake only.** No `configure`, no `configure.ac`, no
  autotools of any kind. `cmake_minimum_required(VERSION 3.10)` at
  `CMakeLists.txt:1`, `project(astyle CXX)` at `:7`.
- Installs: `bin/astyle`, `share/doc/astyle/html/*`, `share/man/man1/astyle.1`
  (the non-Windows arm, `CMakeLists.txt:157-167`).
- Requires: `astyle@source` only. **No dependencies.**

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Sources are a bare `file(GLOB SRCS src/*.cpp)` (`CMakeLists.txt:28`) with no `find_package` anywhere in the file. C++17 is set outright at `CMakeLists.txt:19`, so nothing depends on the compiler's default dialect. Installs through `${CMAKE_INSTALL_PREFIX}/bin` at `:162`, which is `$OUT/bin` because the system always passes `-DCMAKE_INSTALL_PREFIX`. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | **WILL NOT BUILD** | Upstream installs through its `elseif(WIN32)` arm at `CMakeLists.txt:143-150`, to `"${prog_files}/AStyle"`, where `prog_files` is `$ENV{PROGRAMFILES(x86)}` falling back to `$ENV{PROGRAMFILES}` (`:144-147`). That `DESTINATION` is an absolute path that does **not** begin with `CMAKE_INSTALL_PREFIX`, so `cmake --install build --prefix $OUT` cannot redirect it. See the long note below. |
| clang-native | WILL BUILD | As above. |

**THE MINGW BLOCKER, precisely.**

`CMakeLists.txt:143`:

```cmake
elseif(WIN32)
    set(pf86 "PROGRAMFILES(x86)")
    set(prog_files $ENV{${pf86}})
    if(NOT ${prog_files})
        set(prog_files $ENV{PROGRAMFILES})
    endif()
    install(TARGETS astyle DESTINATION "${prog_files}/AStyle")
```

Three compounding facts:

1. CMake sets `WIN32` for MinGW toolchains, so this arm is taken on
   `x86_64-mingw` and the `GNUInstallDirs`-respecting arm at `:157-167` is
   unreachable. The `elseif(MINGW)` at `:67-68` is dead code for this purpose,
   because the chain tests `elseif(NOT WIN32)` at `:58` first.
2. This prefix builds Windows binaries **from Linux**. Neither `PROGRAMFILES`
   nor `PROGRAMFILES(x86)` exists in that environment, so both are empty and
   `prog_files` collapses to the empty string.
3. The resulting `DESTINATION "/AStyle"` is absolute and outside
   `CMAKE_INSTALL_PREFIX`, and `cmake --install --prefix` only rewrites
   destinations that start with the given prefix. So the install step writes to
   `/AStyle` at the filesystem root of the build machine — either failing on
   permissions, or (running as root) succeeding while `$OUT` stays empty and
   the loader publishes nothing.

This is recorded as a blocker rather than worked around. Two routes exist and
neither was taken, deliberately:

- **`DESTDIR`** would capture it, but it is also how this tree's AGENTS.md
  warns against double-prefixing: with `--prefix` set, `DESTDIR` yields
  `$OUT/usr/share/doc/...` on Linux versus `$OUT/bin/...` today, i.e. two
  different install layouts for one package.
- **A per-system recipe exporting `PROGRAMFILES(x86)`** would depend on cmake
  parsing `$ENV{${pf86}}` where the resolved name contains parentheses. That is
  not something to write a recipe around without building it, and this role
  does not build.

If a builder wants this package on mingw, that is a separate reviewed change,
not something to smuggle into `generic.lua`.

**API level notes.** None. astyle is a source formatter: it reads and writes
text and touches none of the named Android walls (`O_BINARY`, `posix_spawn`,
`POSIX_MADV_*`, `stderr`-as-symbol, `process_vm_readv`, `mblen`, `getpass`).
Nothing is executed at build time. `armv7a-android*` and `i686-android*`
match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **`-DBUILD_SHARED_LIBS=OFF` is load-bearing, not cosmetic.**
   `CMakeLists.txt:47-51` picks `add_executable(astyle ...)` when all three of
   `BUILD_SHARED_LIBS` / `BUILD_STATIC_LIBS` / `BUILD_JAVA_LIBS` are off, and
   `add_library` otherwise. It is OFF by default (`:11`), but passing it
   explicitly makes the intent auditable and stops a future default change from
   silently turning this package from a CLI tool into a library.
2. **The `/usr` install-prefix override at `CMakeLists.txt:159-161` does not
   fire, and that is worth confirming.** The file does
   `if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT) set(CMAKE_INSTALL_PREFIX
   "/usr")`. Our systems always pass `-DCMAKE_INSTALL_PREFIX=$OUT`, so the
   variable is *not* initialised to default and `$OUT` survives. If a builder
   ever configures without `$CMAKE_FLAGS`, the install would go to `/usr`
   instead of `$OUT`, outside the staging dir. Check that the install step
   writes under `$OUT`, not `/usr`.
3. **`INSTALL_DOC` defaults ON** (`CMakeLists.txt:130`) and installs HTML docs
   and the man page. Both are text under `$OUT`, so this is harmless — but it
   is why `share/doc/astyle` and `share/man/man1` appear in the output.
4. **`cmake_policy(SET CMP0112 OLD)` at `CMakeLists.txt:3-5`** runs on any cmake
   newer than 3.19. This suppresses a policy error about non-standard target
   name properties in `project()`. It is upstream's own line, not ours, and it
   is harmless; do not "fix" it.
5. **Source URL was not verifiable from the build environment.**
   SourceForge returned HTTP 522 and connection timeouts for every astyle URL
   tried (`sourceforge.net`, `downloads.sourceforge.net`,
   `master.dl.sourceforge.net`, `astyle.sourceforge.net`). The recipe therefore
   lists the canonical SourceForge path first and falls back, on the same line,
   to the Debian pool orig tarball
   `https://deb.debian.org/debian/pool/main/a/astyle/astyle_3.6.12.orig.tar.bz2`,
   which **is** the upstream tarball verbatim and was the one actually
   downloaded and read. Note the extension changed upstream: astyle ≤ 3.1
   shipped `.tar.gz`, 3.6.12 ships `.tar.bz2`, so the recipe extracts with
   `tar -xjf`.
6. `topackage.md:349` lists astyle unchecked; nothing else in the tree
   `require()`s it. Standalone.

**How to verify once built.**

- `bin/astyle` exists and `[ -x bin/astyle ]` is true.
- `bin/astyle --version` — **do not run on a cross system.** Read the version
  out of the binary (`strings`) and confirm it reports 3.6.x, which also proves
  `CMakeLists.txt:28`'s glob picked up the whole of `src/`.
- `share/man/man1/astyle.1` exists — this is the check that distinguishes the
  non-Windows arm (`:165`) from the `WIN32` arm (`:143-150`), and it is the
  single most informative check in this package.
- `$OBJDUMP -f bin/astyle` prints the expected machine.
- On `x86_64-mingw` this package is expected NOT to build; see above. If a
  build there ever appears to succeed, check whether anything actually landed
  in `$OUT`, because the failure mode is a silent empty prefix.