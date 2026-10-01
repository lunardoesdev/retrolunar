# cppcheck build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 2.22.0
- Build system: **CMake.** `cmake_minimum_required(VERSION 3.22)` and
  `project(Cppcheck VERSION 2.22.0 LANGUAGES CXX)` at `CMakeLists.txt:1-2`.
  Note upstream has moved the repository to the `cppcheck-opensource`
  organisation; the release page now publishes only a Windows MSI, so the
  source is the tagged source archive rather than a release asset.
- Installs: `bin/cppcheck`, `bin/cppcheck-htmlreport`, plus `cfg/`,
  `platforms/` and `addons/` under `share/cppcheck/` (`cli/CMakeLists.txt`
  install rules, `FILESDIR_INSTALL` from `cmake/options.cmake`).
- Requires: `cppcheck@source` only.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | C++11, no platform-specific code path is mandatory. `BUILD_GUI` is OFF (`cmake/options.cmake`), so there is no Qt; `HAVE_RULES` is OFF, so there is no PCRE. `lib/smallvector.h:26` guards its boost include behind `#ifdef HAVE_BOOST` and `cmake/compilerDefinitions.cmake` only defines it `if(Boost_FOUND)`, and Boost is not in this prefix. `find_package(Threads REQUIRED)` resolves to nothing on Bionic because the system passes `-DTHREADS_PREFER_PTHREAD_FLAG=ON`. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. `NO_WINDOWS_SEH` (`cmake/options.cmake`) is off, but the SEH path is only compiled under MSVC in practice; `cli/CMakeLists.txt` adds `shlwapi` for MINGW and `Shlwapi.lib` otherwise, both present. |
| clang-native | WILL BUILD | As above, and the only system on which the optional test suite would be runnable — which we do not do. |

**API level notes.** None of the named walls apply. cppcheck does not call
`posix_spawn`, `process_vm_readv`, `POSIX_MADV_*`, `mblen`, `getpass` or
`O_BINARY`, and nothing opens a file during the build. The one platform probe
that could differ is `check_include_file_cxx(execinfo.h)`
(`cmake/includechecks.cmake`), which has an explicit fallback: if the header is
absent it sets `HAVE_EXECINFO_H 0` rather than failing, and
`cmake/compilerDefinitions.cmake` passes that through as
`-DHAVE_EXECINFO_H=<0|1>`. `armv7a-android*` and `i686-android*` match
`aarch64-android*`.

**THE DECISIVE FACT — `-DDISABLE_DMAKE=ON` is mandatory, not an optimisation.**

`cli/CMakeLists.txt:38-40`:

```
if(NOT DISABLE_DMAKE)
    add_dependencies(cppcheck run-dmake)
endif()
```

and `tools/dmake/CMakeLists.txt:14`:

```
add_custom_target(run-dmake $<TARGET_FILE:dmake>
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        DEPENDS dmake)
```

`$<TARGET_FILE:dmake>` in a custom target's command is **an execution of that
binary**. So the default build compiles `dmake` and then *runs it*. On every
cross system in this tree that is an Android or PE executable; running it
would require an emulator, which this project never does, and on `clang-native`
it would silently succeed and hide the problem from every other system.

This is safe to disable, and that was verified rather than assumed:

- `dmake` writes upstream's own top-level `Makefile`
  (`tools/dmake/dmake.cpp:609`, `static constexpr char makefile[] =
  "Makefile"`), and that file already ships in the release (83966 bytes).
- **No `CMakeLists.txt` in the tree references a generated `.d` file or that
  Makefile.** The cmake build compiles straight from the recursive globs at
  `lib/CMakeLists.txt:1-2`. So nothing the build needs is lost.

**PCRE: cppcheck bundles none, and does not need any.**

- There is no `pcre/` directory in the tree. `externals/` holds exactly
  `picojson`, `simplecpp`, `tinyxml2` and a stray `pcre.patch`.
- `option(HAVE_RULES "Usage of rules (needs PCRE library and headers)" OFF)`
  in `cmake/options.cmake` — **OFF by default**.
- `cmake/findDependencies.cmake:32-38` only probes `pcre.h` /
  `find_library(NAMES pcre pcred)` when `HAVE_RULES` is on, and turns a miss
  into a `FATAL_ERROR`. With it off, `:38-40` just sets `PCRE_LIBRARY` empty.

So the bundled-PCRE question resolves as: **it builds none, and needs none by
default.** Note that even `-DHAVE_RULES=ON` would not work in this prefix —
`packages/pcre2` provides PCRE2, whose header is `pcre2.h`, and
`findDependencies.cmake:32` looks specifically for `pcre.h` (PCRE1).

**Are the externals submodules?** No, and this was checked because a GitHub
source archive does not carry submodule content. `externals/tinyxml2`,
`externals/simplecpp` and `externals/picojson` are each populated with real
files (`tinyxml2.cpp`, `simplecpp.cpp`, `picojson.h`, …), and there is **no
`.gitmodules` file anywhere in the tree**. They are vendored copies, so the
tag archive is complete.

**Risks / what a reviewer should check.**

1. **`matchcompiler` is a host script and is safe, but it is off by default.**
   `cmake/options.cmake:37-52` sets `USE_MATCHCOMPILER` to Auto, which enables
   it for any non-Debug build type; `options.cmake` defaults
   `CMAKE_BUILD_TYPE` to `Debug`, so it lands Off. When on, it runs
   `${Python_EXECUTABLE} tools/matchcompiler.py` over the C++ sources
   (`lib/CMakeLists.txt:18-28`) — a host python reading host text, not a
   target binary. Safe either way, but if a future change sets
   `CMAKE_BUILD_TYPE=Release`, confirm matchcompiler still only runs python.
2. **`BUILD_TESTING` defaults OFF** (`cmake/options.cmake` sets it OFF when
   undefined), so `add_subdirectory(test)` at `CMakeLists.txt:114` adds
   nothing by default. `BUILD_GUI` is also OFF, which is what keeps Qt out of
   this entirely — worth stating because Qt is exactly the dependency
   heaptrack cannot avoid.
3. **`BUILD_SHARED_LIBS=OFF` is stated explicitly** because it changes the
   target type, not just its output: `lib/CMakeLists.txt:43-48` builds
   `cppcheck-core` as a plain `add_library` when it is on and as an
   `OBJECT` library when it is off (the comment there explains auto-
   registration does not work for static libraries). It is cmake's default
   value anyway; stating it matches the rest of this prefix.
4. `USE_BUNDLED_TINYXML2` is ON by default and the bundled sources are used
   (`CMakeLists.txt:105-108`), so nothing is looked up in `$PREFIX`.
5. `topackage.md:351` lists cppcheck unchecked; nothing else in the tree
   `require()`s it. Standalone.

**How to verify once built.**

- `bin/cppcheck` exists and `[ -x bin/cppcheck ]` is true.
- `bin/cppcheck-htmlreport` exists (installed by `cli/CMakeLists.txt`).
- `share/cppcheck/cfg/cppcheck-cfg.rng` exists — proves the `cfg` install
  landed under the right prefix root.
- **The log must not contain a line showing `dmake` being executed.** If the
  build log shows the dmake binary running, `-DDISABLE_DMAKE=ON` did not take
  effect, and that is a real defect regardless of the build's exit status.
- `$OBJDUMP -f bin/cppcheck` prints the expected machine.
- Do **not** run `bin/cppcheck` from a target prefix.