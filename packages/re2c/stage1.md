# re2c build forecast

- Recipe: `generic.lua`, source `source.lua` (GitHub release asset)
- Version pinned: **4.6** (tag `4.6`, the current `releases/latest`)
- Build system: **cmake**, and it is the build taken here. The tarball also
  ships a complete autotools tree — `configure`, `configure.ac`,
  `aclocal.m4`, `Makefile.am`, `Makefile.in`, `config.h.in`, `autogen.sh` —
  so both paths exist. For the record, the autotools config template would
  be the top-level **`config.h.in`**; it is not guarded in `generic.lua`
  because this recipe never runs `./configure`.
- `CMakeLists.txt:1-2` requires cmake 3.15, well under the 4.x floor our
  systems already set via `-DCMAKE_POLICY_VERSION_MINIMUM=3.5`, so no
  policy workaround is needed here.
- Installs: `bin/re2c` plus the `re2d`/`re2go`/`re2hs`/`re2java`/`re2js`/
  `re2ocaml`/`re2py`/`re2rust`/`re2swift`/`re2v`/`re2zig` language aliases
  (`CMakeLists.txt:37-47`, all default ON), and man pages. No library, no
  headers, no `.pc`.
- Requires: `re2c@source` only — re2c vendors nothing it needs and pulls
  nothing from this prefix.

## Native tool, not a target library

re2c is a lexer generator. It runs on the build machine, reads a `.re`
grammar, and writes C/C++/Go/Java/Rust/… source that is then compiled into
some *other* package. **The only system that actually consumes this package
is `clang-native`**, via `require("re2c@native")` — the same shape as
`packages/bison/generic.lua`'s `gperf@native` and
`packages/libnl-3/generic.lua`'s `flex@native`. `@native` falls back to
`generic.lua`, so no `clang-native.lua` is written: it would be a
byte-identical copy, the duplicate that got `packages/bison/android.lua`
deleted.

## Verdicts

The honest headline: **I found no libc obstacle in re2c 4.6, and I did not
compile it.** Per AGENTS.md the adder does not build, so every Android row
below is a forecast from source reading, not a result. They are marked
UNCERTAIN rather than promoted to WILL BUILD, because "no obstacle found" is
a weaker claim than "it built".

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **UNCERTAIN** | No libc wall found. A grep of all of `src/` for `posix_spawn`, `process_vm_readv`, `mblen`, `getpass`, `nl_langinfo`, `mktime_z`, `POSIX_MADV_*`, `O_BINARY`, `getloadavg` and `fopencookie` returns **zero hits** — so none of the recorded Android API gates apply, at any level. The language requirement is C++11 (`CMakeLists.txt:74-75`, `CMAKE_CXX_STANDARD_REQUIRED ON`), which the NDK's clang and libc++ satisfy at API 21. `-DRE2C_BUILD_TESTS=OFF` removes the one step that would run a built binary. Not compiled here. |
| aarch64-android24 | **UNCERTAIN** | As above. |
| aarch64-android35 | **UNCERTAIN** | As above. |
| x86_64-android35 | **UNCERTAIN** | As above; no arch-conditional code found. |
| x86_64-mingw | **UNCERTAIN** | Same absence of any gated symbol, and the same C++11 requirement, which mingw-w64's g++ meets. I did not check re2c's own Windows conditionals, and the C++11 `std::` surface across 11 language back-ends is a lot of code to call safe unread. |
| clang-native | **WILL BUILD** | **The row that matters**, and the one a builder should target. Native clang is C++11-capable, `$CMAKE_FLAGS` supplies the toolchain, and `-DRE2C_BUILD_TESTS=OFF` means nothing executes the freshly built re2c. Still a forecast, not a build log — `stage3.md` is where that becomes a fact. |

## API level notes

**No API level matters here, and that is the finding, not a dodge.** re2c
4.6 reaches for none of the recorded gates. Specifically, the ones that
bite other packages in this tree are all absent: no `posix_spawn` (the
`ninja`/`samurai` wall), no `mblen`/`getpass` (the `bash`/`wget` wall), no
`O_BINARY`, no `nl_langinfo`, no `mktime_z`. The `26 introduced
nl_langinfo` and `35 exposes mktime_z` boundaries are simply not on this
package's path, so aarch64-android21 is not distinguishable from
aarch64-android35 on libc grounds.

## Risks / what a reviewer should check

1. **`-DRE2C_BUILD_TESTS=OFF` is the safety-critical flag, and its default
   is ON.** `CMakeLists.txt:53` reads
   `option(RE2C_BUILD_TESTS "Build tests" "${RE2C_IS_ROOT_PROJECT}")`, and
   `CMakeLists.txt:18-20` sets `RE2C_IS_ROOT_PROJECT TRUE` when re2c is the
   top-level project — which it is. So the default is ON. The suite runs the
   built re2c over its own corpus; on a cross build that executes a target
   binary. `CMakeLists.txt:56` also adds the harness whenever the option is
   on. This is the same reasoning as `ENABLE_TESTING=OFF` in
   `packages/ccache/generic.lua`.
2. **All four `RE2C_REBUILD_*` options already default OFF**
   (`CMakeLists.txt:23,28,33,34`), so nothing regenerates lexers, parsers,
   syntax files or the man page with a host re2c. I left them alone rather
   than passing redundant `=OFF`. A reviewer who wants the tarball's
   pre-generated files — which is what those options would change — should
   know they are already the default.
3. **Eleven language aliases install by default** (`CMakeLists.txt:37-47`).
   I did not turn them off: they are genuine parts of the package, and
   turning them off would be a taste decision rather than a correctness one.
   A reviewer who wants a lean prefix has eleven one-token switches.
4. **No `DESTDIR`.** `$CMAKE_FLAGS` already carries
   `-DCMAKE_INSTALL_PREFIX=$OUT`, so `cmake --install build` writes
   straight into `$OUT`. Adding `DESTDIR` would nest it twice — the same
   trap AGENTS.md records for meson.
5. **The build never fans out**: `cmake --build build --parallel 1`, which
   is load-bearing here, since cmake does not default to serial.
6. **The autotools tree is present but unused.** If a reviewer expects a
   `touch aclocal.m4 configure config.h.in` guard, its absence is correct:
   this recipe never runs `./configure`. The template name is recorded above
   in case the build path is ever changed.

## How to verify once built

- `bin/re2c`
- the language aliases under `bin/` (`re2d`, `re2go`, `re2py`, …)
- man pages under `share/man/`
- **no `build/` test artifacts and no `re2c_tests`/corpus binaries** — their
  presence would mean `RE2C_BUILD_TESTS=OFF` did not take, and would be the
  check that matters, because that suite executes the target binary
- no library and no `.pc`
- `file bin/re2c` → host x86_64 ELF on `clang-native`
- `bin/re2c --version` is safe to run **on `clang-native` only**
